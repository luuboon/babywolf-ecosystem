#!/usr/bin/env python3
"""Genera el ícono de BabyWolf (lobo pixel-art) para los tres proyectos.

Se dibuja por código en vez de arrastrar un PNG suelto: así el ícono es
reproducible y queda claro de dónde salió. Ejecutar desde la raíz del repo:

    python3 tools/gen_icons.py
"""

from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent

# Paleta del blog BabyWolf.
FONDO = (26, 26, 46)       # #1a1a2e
PELAJE = (232, 232, 240)   # gris claro
OJOS = (233, 69, 96)       # #e94560
HOCICO = (22, 33, 62)      # #16213e

COLORES = {"W": PELAJE, "E": OJOS, "N": HOCICO}

# Cabeza de lobo en 16x16. El contenido queda centrado y ocupa ~66% del
# lienzo, que es lo que exige un ícono "maskable" para no recortarse.
LOBO = [
    "................",
    "..W..........W..",
    "..WW........WW..",
    "..WWW......WWW..",
    "..WWWWWWWWWWWW..",
    ".WWWWWWWWWWWWWW.",
    ".WWWWWWWWWWWWWW.",
    ".WWEEWWWWWWEEWW.",
    ".WWEEWWWWWWEEWW.",
    ".WWWWWWWWWWWWWW.",
    "..WWWWWWWWWWWW..",
    "..WWWWWWWWWWWW..",
    "...WWWWWWWWWW...",
    "....WWWNNWWW....",
    ".....WNNNNW.....",
    "......NNNN......",
]


def dibujar(lado: int) -> Image.Image:
    """Ícono cuadrado de `lado` px con el lobo centrado."""
    img = Image.new("RGB", (lado, lado), FONDO)
    pixeles = img.load()

    celda = int(lado * 0.66) // 16          # tamaño de cada píxel del dibujo
    margen = (lado - celda * 16) // 2       # lo centra en el lienzo

    for fila, linea in enumerate(LOBO):
        for col, ch in enumerate(linea):
            color = COLORES.get(ch)
            if color is None:
                continue
            x0 = margen + col * celda
            y0 = margen + fila * celda
            for x in range(x0, x0 + celda):
                for y in range(y0, y0 + celda):
                    pixeles[x, y] = color

    return img


def main() -> None:
    salidas = {
        "tv_pwa/icons/icon-192.png": 192,
        "tv_pwa/icons/icon-512.png": 512,
        # flutter_launcher_icons parte de un master de 1024.
        "phone_app/assets/icon.png": 1024,
        "wearable_app/assets/icon.png": 1024,
    }

    for ruta, lado in salidas.items():
        destino = RAIZ / ruta
        destino.parent.mkdir(parents=True, exist_ok=True)
        dibujar(lado).save(destino)
        print(f"  {ruta}  ({lado}x{lado})")


if __name__ == "__main__":
    main()
