#!/usr/bin/env python3
"""Test tile'larını üretir (Pillow gerekir). Leveller bunlarla kurulur; gerçek tileset'i
sonra editörde bunların üstüne boyayacaksınız.

Atlas (16x16, tek satır), sütun sırası:
  0 orman toprağı   1 orman çim üstü   2 kaya   3 karlı kaya üstü
  4 bulut           5 altın bulut üstü 6 tahta (tek yönlü platform)  7 koyu tahta (yapı)
Kullanım (oyun/ klasöründen): python3 tools/make_test_tiles.py
"""
from pathlib import Path
import random
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets/tilesets/test/test_tiles.png"
T = 16


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def base(img, ox, col, speck, seed):
    rnd = random.Random(seed)
    for y in range(T):
        for x in range(T):
            c = col
            if rnd.random() < 0.12:
                c = speck
            # Test görünümü: sağ ve alt kenarda koyu çizgi (ızgara)
            if x == T - 1 or y == T - 1:
                c = tuple(max(0, v - 40) for v in col[:3]) + (255,)
            img.putpixel((ox + x, y), c)


def top(img, ox, col, hi, h):
    for y in range(h):
        for x in range(T):
            img.putpixel((ox + x, y), hi if y == 0 else col)


def main():
    img = Image.new("RGBA", (T * 8, T), (0, 0, 0, 0))
    base(img, 0, hexc("5c4c37"), hexc("3d3028"), 1)
    base(img, 16, hexc("5c4c37"), hexc("3d3028"), 2)
    top(img, 16, hexc("557d42"), hexc("87ab54"), 5)
    base(img, 32, hexc("576797"), hexc("333d58"), 3)
    base(img, 48, hexc("576797"), hexc("333d58"), 4)
    top(img, 48, hexc("dfe5ff"), hexc("ffffff"), 5)
    base(img, 64, hexc("e6e0f5"), hexc("c3bbe0"), 5)
    base(img, 80, hexc("e6e0f5"), hexc("c3bbe0"), 6)
    top(img, 80, hexc("e6c068"), hexc("fff0b5"), 4)
    # Tahta: sadece üst 5 piksel dolu (tek yönlü platform)
    for y in range(5):
        for x in range(T):
            c = hexc("a8743a") if 0 < y < 4 else hexc("5c3622")
            img.putpixel((96 + x, y), c)
    base(img, 112, hexc("3d3028"), hexc("2d1f36"), 7)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print("yazıldı:", OUT)


if __name__ == "__main__":
    main()
