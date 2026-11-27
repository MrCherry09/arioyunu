#!/usr/bin/env python3
"""Green Valley tileset'inden renk sürümleri üretir (Pillow gerekir: pip install pillow).

  heaven: cennet/bulut bölümü - koyu toprak -> beyaz-lavanta bulut, yeşil çim -> altın
  snow:   dağ bölümü yedeği  - koyu toprak -> lacivert taş, yeşil çim -> kar

Green Valley CC0 olduğu için üretilen dosyalar da serbestçe repoya konabilir.
Kullanım (oyun/ klasöründen):
  python3 tools/recolor_green_valley.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/tilesets/green_valley/green_valley.png"
OUT = ROOT / "assets/tilesets/generated"

# Green Valley'nin 24 rengi -> yeni renk. Listede olmayan renk aynen kalır.
HEAVEN = {
    # İç ve koyu kısımlar: orijinalde en koyu olan en açık buluta döner (iç dolgu parlak, kenar gölgeli)
    "181425": "eeeaf8",  # toprak içi -> bulut dolgusu
    "2d1f36": "d6cfeb",
    "3d221d": "cfc7e6",
    "3d3028": "c3bbe0",  # toprak kenarı -> bulut gölgesi
    "5c3622": "b5acd8",
    "5c4c37": "a99fcf",
    "875937": "9b90c4",
    "7a6a52": "8f84bd",
    "857471": "8f84bd",
    # Yeşil çim -> altın (koyudan açığa)
    "1f3b32": "9c6a2e",
    "2b472b": "b07c35",
    "316644": "c99245",
    "3c5152": "c99245",
    "557d42": "ddb055",
    "4a8f59": "e6c068",
    "537877": "e9c977",
    "87ab54": "f2d67e",
    "779e8f": "f6e2a0",
    "b4c76f": "fff0b5",
    # Vurgular: kırmızı mantar -> pembe
    "bf4343": "f29bbd",
    "8f3842": "d9789f",
}

SNOW = {
    # Toprak -> lacivert taş (Winter Tileset paletine yakın)
    "181425": "1e2434",
    "2d1f36": "272f44",
    "3d221d": "232a3c",
    "3d3028": "333d58",
    "5c3622": "4b5982",
    "5c4c37": "576797",
    "875937": "687ab4",
    "7a6a52": "7f95db",
    "857471": "7e84ae",
    # Yeşil çim -> kar (koyudan açığa)
    "1f3b32": "7184c3",
    "2b472b": "98a0d3",
    "316644": "a9b2ea",
    "3c5152": "a9b2ea",
    "557d42": "b1baf5",
    "4a8f59": "c9d3ff",
    "537877": "c9d3ff",
    "87ab54": "dfe5ff",
    "779e8f": "eef1ff",
    "b4c76f": "ffffff",
}


def recolor(mapping: dict, out_name: str) -> None:
    im = Image.open(SRC).convert("RGBA")
    table = {tuple(int(k[i:i + 2], 16) for i in (0, 2, 4)): tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))
             for k, v in mapping.items()}
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in table:
                px[x, y] = (*table[(r, g, b)], a)
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / out_name)
    print("yazıldı:", OUT / out_name)


if __name__ == "__main__":
    recolor(HEAVEN, "heaven.png")
    recolor(SNOW, "snow.png")
