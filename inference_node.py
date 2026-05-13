#!/usr/bin/env python3
"""
Inference node: 使用 YOLO26 TensorRT engine 進行推理，並將偵測結果透過 MQTT 發佈。
來源可為影片檔或攝影機，偵測結果以 JSON 格式傳送至指定的 MQTT topic。
"""

import argparse
import json
import os
import signal
import sys
import time

import cv2
import paho.mqtt.client as mqtt
from paho.mqtt.enums import CallbackAPIVersion
from ultralytics import YOLO

# --- 全域狀態 ---
running = True

# --- 訊號處理 (優雅關閉) ---
def signal_handler(sig, frame):
    """處理 SIGTERM/SIGINT 訊號，確保優雅關閉。"""
    global running
    print(f"\n[inference] 收到訊號 {sig}，正在關閉...")
    running = False

signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

# --- Docker 健康檢查心跳 ---
def write_health():
    """寫入心跳檔案供 Docker HEALTHCHECK 使用。"""
    try:
        with open("/tmp/inference_health", "w") as f:
            f.write(str(time.time()))
    except OSError:
        pass

# --- 主程式 ---
def main():
    parser = argparse.ArgumentParser(description="YOLO26 TensorRT 推理節點")
    parser.add_argument("--model", default="/opt/models/best.engine",
                        help="TensorRT engine 路徑 (於映像檔建置時生成)")
    parser.add_argument("--source", default="/opt/data/test_video.mp4",
                        help="影片檔路徑或攝影機索引")
    parser.add_argument("--imgsz", type=int, default=320,
                        help="輸入影像大小")
    parser.add_argument("--conf", type=float, default=0.25,
                        help="偵測信心閾值")
    parser.add_argument("--mqtt-broker", default=os.getenv("MQTT_BROKER", "localhost"),
                        help="MQTT broker 位址")
    parser.add_argument("--mqtt-port", type=int, default=int(os.getenv("MQTT_PORT", "1883")),
                        help="MQTT broker 連接埠")
    parser.add_argument("--mqtt-topic", default="/sense/vision/detections",
                        help="MQTT topic 名稱")
    args = parser.parse_args()

    # 載入模型
    print(f"[inference] 載入模型: {args.model}")
    model = YOLO(args.model, task="detect")

    # 連線至 MQTT
    client = mqtt.Client(CallbackAPIVersion.VERSION2)
    print(f"[inference] 連線至 MQTT broker: {args.mqtt_broker}:{args.mqtt_port}")
    client.connect(args.mqtt_broker, args.mqtt_port)
    client.loop_start()

    # 開啟影片或攝影機
    cap = cv2.VideoCapture(args.source)
    if not cap.isOpened():
        print(f"[inference] 錯誤: 無法開啟來源: {args.source}")
        sys.exit(1)

    frame_count = 0
    fps_start = time.monotonic()
    print(f"[inference] 開始推理來源: {args.source}...")

    while running:
        ret, frame = cap.read()
        if not ret:
            # 若影片結束，回到開頭循環播放
            cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
            ret, frame = cap.read()
            if not ret:
                break

        # 推理
        results = model.predict(frame, imgsz=args.imgsz, conf=args.conf, verbose=False)

        # 建立偵測結果 payload
        detections = []
        for r in results:
            for box in r.boxes:
                detections.append({
                    "class": r.names[int(box.cls)],
                    "confidence": round(float(box.conf), 3),
                    "bbox": [round(float(x), 1) for x in box.xyxy[0].tolist()],
                })

        payload = {
            "t": round(time.time(), 3),
            "frame": frame_count,
            "detections": detections,
            "count": len(detections),
        }

        # 發佈至 MQTT
        client.publish(args.mqtt_topic, json.dumps(payload), qos=0)
        frame_count += 1

        # 心跳檔案 (每 10 影格)
        if frame_count % 10 == 0:
            write_health()

        # 效能監控 (每 100 影格)
        if frame_count % 100 == 0:
            elapsed = time.monotonic() - fps_start
            fps = frame_count / elapsed if elapsed > 0 else 0
            print(f"[inference] 已處理 {frame_count} 影格, FPS={fps:.1f}, "
                  f"最近影格偵測數={len(detections)}")

    # 清理資源
    cap.release()
    client.loop_stop()
    client.disconnect()
    print(f"[inference] 已關閉，總共處理 {frame_count} 影格。")

if __name__ == "__main__":
    main()
