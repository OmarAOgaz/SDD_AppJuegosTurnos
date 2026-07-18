#!/usr/bin/env python3
"""Reproducible lobby preview tones (mono PCM16 WAV, 44.1 kHz).

Peak-normalizes each clip to -1.5 dBTP. Run from repo root:
  python scripts/generate_lobby_sounds.py
"""

from __future__ import annotations

import hashlib
import math
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path("assets/sounds")


def write_wav(path: Path, samples: list[float]) -> None:
    peak = max(abs(s) for s in samples) or 1.0
    scale = (10 ** (-1.5 / 20)) / peak
    pcm = [max(-1.0, min(1.0, s * scale)) for s in samples]
    data = b"".join(struct.pack("<h", int(round(x * 32767))) for x in pcm)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def env(n: int, a: float = 0.005, r: float = 0.04) -> list[float]:
    ea, er = int(a * SR), int(r * SR)
    out: list[float] = []
    for i in range(n):
        if i < ea:
            g = i / max(1, ea)
        elif i > n - er:
            g = max(0.0, (n - i) / max(1, er))
        else:
            g = 1.0
        out.append(g)
    return out


def tone(freq: float, dur: float, shape: str = "sine", amp: float = 1.0) -> list[float]:
    n = int(dur * SR)
    e = env(n)
    samples: list[float] = []
    for i in range(n):
        t = i / SR
        ph = 2 * math.pi * freq * t
        if shape == "square":
            v = 1.0 if math.sin(ph) >= 0 else -1.0
        else:
            v = math.sin(ph)
        samples.append(amp * v * e[i])
    return samples


def sweep(f0: float, f1: float, dur: float, amp: float = 1.0) -> list[float]:
    n = int(dur * SR)
    e = env(n, 0.01, 0.05)
    samples: list[float] = []
    phase = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / max(1, n - 1))
        phase += 2 * math.pi * f / SR
        samples.append(amp * math.sin(phase) * e[i])
    return samples


def chirp_elastic(dur: float = 0.18) -> list[float]:
    n = int(dur * SR)
    e = env(n, 0.002, 0.08)
    samples: list[float] = []
    phase = 0.0
    for i in range(n):
        f = 900 * math.exp(-4.5 * (i / n)) + 180
        phase += 2 * math.pi * f / SR
        samples.append(math.sin(phase) * e[i])
    return samples


def metallic(dur: float = 0.2) -> list[float]:
    n = int(dur * SR)
    e = env(n, 0.001, 0.12)
    samples: list[float] = []
    for i in range(n):
        t = i / SR
        v = (
            0.55 * math.sin(2 * math.pi * 1200 * t)
            + 0.35 * math.sin(2 * math.pi * 1800 * t)
            + 0.2 * math.sin(2 * math.pi * 2700 * t)
        )
        samples.append(v * e[i] * math.exp(-8 * t))
    return samples


def digital(dur: float = 0.16) -> list[float]:
    n = int(dur * SR)
    e = env(n, 0.001, 0.05)
    samples: list[float] = []
    rng = 12345
    for i in range(n):
        rng = (1103515245 * rng + 12345) & 0x7FFFFFFF
        noise = ((rng / 0x7FFFFFFF) * 2 - 1) * 0.35
        t = i / SR
        beep = math.sin(2 * math.pi * (1600 if i < n // 2 else 1100) * t)
        samples.append((0.7 * beep + noise) * e[i])
    return samples


FILES = {
    "click_1.wav": tone(880, 0.08, "sine"),
    "click_3.wav": tone(220, 0.10, "sine"),
    "rollover_2.wav": sweep(400, 700, 0.14, 0.85),
    "rollover_5.wav": sweep(900, 1600, 0.12, 0.9),
    "switch_1.wav": tone(660, 0.06, "square", 0.55),
    "switch_7.wav": chirp_elastic(),
    "switch_19.wav": metallic(),
    "switch_32.wav": digital(),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    lines: list[str] = []
    for name, samples in FILES.items():
        path = OUT / name
        write_wav(path, samples)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        lines.append(f"{digest}  {name}")
        print(f"{name} {path.stat().st_size} {digest}")
    (OUT / "CHECKSUMS.sha256").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
