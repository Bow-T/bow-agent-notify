#!/usr/bin/env python3
"""Tổng hợp ba âm báo của Bow Notify (không dùng mẫu thu sẵn, không thư viện ngoài).

Cùng một "chất giọng" — chuông FM trong, vào tiếng sáng rồi dịu dần, có vọng nhẹ — để nghe là biết của bow,
nhưng mỗi âm một dáng giai điệu để KHÔNG CẦN NHÌN máy cũng biết chuyện gì:
  bow_ask   đi LÊN, bỏ lửng   → agent đang chờ bạn (thẻ duyệt, câu hỏi)
  bow_done  hợp âm trưởng rải lên rồi đậu lại → lượt chạy đã xong
  bow_fail  đi XUỐNG, trầm    → lượt chạy lỗi

Chạy:  python3 tool/make_sounds.py   (ghi vào android/app/src/main/res/raw/ và ios/Runner/)
Đổi âm của một kênh thông báo Android đã tạo thì phải đổi cả ID kênh (MainActivity.kt) — Android khoá âm theo kênh.
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
ROOT = Path(__file__).resolve().parent.parent
OUT_DIRS = [ROOT / "android/app/src/main/res/raw", ROOT / "ios/Runner"]

# (bắt đầu lúc [s], tần số [Hz], độ to, thời gian tắt dần [s], độ sáng lúc vào tiếng)
SOUNDS = {
    "bow_ask": (1.15, [(0.00, 783.99, 0.85, 0.30, 1.5), (0.13, 1174.66, 1.0, 0.36, 1.7), (0.27, 1567.98, 0.42, 0.42, 1.2)]),
    "bow_done": (1.45, [(0.00, 659.25, 0.8, 0.30, 1.4), (0.10, 830.61, 0.8, 0.30, 1.4), (0.20, 987.77, 0.85, 0.34, 1.5), (0.33, 1318.51, 1.0, 0.50, 1.6)]),
    "bow_fail": (1.20, [(0.00, 659.25, 0.9, 0.34, 0.9), (0.19, 523.25, 1.0, 0.44, 0.8), (0.19, 261.63, 0.5, 0.50, 0.5)]),
}


def bell(freq: float, t: float, decay: float, bright: float) -> float:
    """Một nốt chuông FM: sóng mang + sóng điều chế gấp đôi tần số; chỉ số điều chế tắt nhanh nên tiếng vào sáng rồi tròn lại."""
    env = (1.0 - math.exp(-t / 0.005)) * math.exp(-t / decay)
    index = bright * math.exp(-t / 0.11)
    phase = 2 * math.pi * freq * t
    tone = math.sin(phase + index * math.sin(2 * phase))
    tone += 0.22 * math.sin(phase * 1.004)  # lệch tông rất nhẹ → tiếng dày hơn
    tone += 0.10 * math.sin(3 * phase) * math.exp(-t / 0.07)
    return env * tone


def render(length: float, notes) -> list[float]:
    total = int(length * RATE)
    dry = [0.0] * total
    for start, freq, gain, decay, bright in notes:
        first = int(start * RATE)
        for n in range(first, total):
            dry[n] += gain * bell(freq, (n - first) / RATE, decay, bright)
    # Vọng ngắn (hai lần dội) cho có không gian, rồi tắt dần 80 ms cuối để không bị "tách" khi hết file.
    wet = dry[:]
    for delay, mix in ((0.095, 0.26), (0.19, 0.12)):
        shift = int(delay * RATE)
        for n in range(shift, total):
            wet[n] += mix * dry[n - shift]
    fade = int(0.08 * RATE)
    for n in range(total - fade, total):
        wet[n] *= (total - n) / fade
    peak = max(abs(v) for v in wet) or 1.0
    return [0.82 * v / peak for v in wet]


def main() -> None:
    for name, (length, notes) in SOUNDS.items():
        frames = b"".join(struct.pack("<h", int(v * 32767)) for v in render(length, notes))
        for out in OUT_DIRS:
            out.mkdir(parents=True, exist_ok=True)
            with wave.open(str(out / f"{name}.wav"), "wb") as f:
                f.setnchannels(1)
                f.setsampwidth(2)
                f.setframerate(RATE)
                f.writeframes(frames)
        print(f"{name}.wav  {length:.2f}s  {len(frames) // 1024} KB")


if __name__ == "__main__":
    main()
