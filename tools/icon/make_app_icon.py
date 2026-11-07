"""Genera el ícono de CTEA (1024x1024, sin transparencia).

Uso: python3 tools/icon/make_app_icon.py
Escribe App/CancioneroHKN/Assets.xcassets/AppIcon.appiconset/AppIcon.png
Diseño: fondo azul marino, círculo blanco y aro dorado delgado.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

S = 1024
SS = 4  # supersampling para bordes suaves
N = S * SS
OUT = Path(__file__).resolve().parents[2] / "App/CancioneroHKN/Assets.xcassets/AppIcon.appiconset/AppIcon.png"


def vertical_gradient(top, bottom):
    img = Image.new("RGB", (N, N))
    d = ImageDraw.Draw(img)
    for y in range(N):
        t = y / (N - 1)
        d.line([(0, y), (N, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img


def icon():
    bg = vertical_gradient((33, 70, 112), (22, 52, 88))
    c = N / 2
    r = 0.295 * N

    # sombra suave bajo el círculo
    sh = Image.new("L", (N, N), 0)
    ImageDraw.Draw(sh).ellipse([c - r, c - r + 0.012 * N, c + r, c + r + 0.012 * N], fill=90)
    bg.paste((10, 28, 52), mask=sh.filter(ImageFilter.GaussianBlur(0.02 * N)))

    # aro dorado
    rw = 0.014 * N
    rr = r + rw / 2 - 0.002 * N
    gold = vertical_gradient((236, 205, 128), (190, 146, 62))
    m = Image.new("L", (N, N), 0)
    md = ImageDraw.Draw(m)
    md.ellipse([c - rr - rw / 2, c - rr - rw / 2, c + rr + rw / 2, c + rr + rw / 2], fill=255)
    md.ellipse([c - rr + rw / 2, c - rr + rw / 2, c + rr - rw / 2, c + rr - rw / 2], fill=0)
    bg.paste(gold, mask=m)

    # círculo blanco
    ImageDraw.Draw(bg).ellipse([c - r, c - r, c + r, c + r], fill=(242, 240, 243))
    return bg.resize((S, S), Image.LANCZOS)


if __name__ == "__main__":
    icon().save(OUT)
    print(f"Escrito {OUT}")
