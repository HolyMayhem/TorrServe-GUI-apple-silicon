#!/usr/bin/env python3

from __future__ import annotations

import io
import math
import struct
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageOps


ICNS_CHUNKS = (
    ("icp4", 16),
    ("ic11", 32),
    ("icp5", 32),
    ("ic12", 64),
    ("ic07", 128),
    ("ic13", 256),
    ("ic08", 256),
    ("ic14", 512),
    ("ic09", 512),
    ("ic10", 1024),
)


def superellipse_mask(size: int, inset: int, exponent: float = 5.0) -> Image.Image:
    scale = 4
    large_size = size * scale
    large_inset = inset * scale
    center = (large_size - 1) / 2
    radius = center - large_inset

    mask = Image.new("L", (large_size, large_size), 0)
    pixels = mask.load()

    for y in range(large_size):
        normalized_y = abs((y - center) / radius) ** exponent
        for x in range(large_size):
            normalized_x = abs((x - center) / radius) ** exponent
            if normalized_x + normalized_y <= 1:
                pixels[x, y] = 255

    return mask.resize((size, size), Image.Resampling.LANCZOS)


def write_icns(master: Image.Image, output_path: Path) -> None:
    chunks: list[bytes] = []

    for type_code, dimension in ICNS_CHUNKS:
        icon = master.resize(
            (dimension, dimension),
            Image.Resampling.LANCZOS,
        )
        png_buffer = io.BytesIO()
        icon.save(png_buffer, format="PNG", optimize=True, dpi=(72, 72))
        png_data = png_buffer.getvalue()
        chunks.append(
            type_code.encode("ascii")
            + struct.pack(">I", len(png_data) + 8)
            + png_data
        )

    body = b"".join(chunks)
    output_path.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit(
            "usage: build_icon.py SOURCE.png OUTPUT.png OUTPUT.icns"
        )

    source_path = Path(sys.argv[1])
    output_png = Path(sys.argv[2])
    output_icns = Path(sys.argv[3])

    source = Image.open(source_path).convert("RGBA")
    master = ImageOps.fit(
        source,
        (1024, 1024),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )

    shape = superellipse_mask(size=1024, inset=38)
    alpha = ImageChops.multiply(master.getchannel("A"), shape)
    master.putalpha(alpha)

    output_png.parent.mkdir(parents=True, exist_ok=True)
    master.save(output_png, format="PNG", optimize=True, dpi=(72, 72))
    write_icns(master, output_icns)


if __name__ == "__main__":
    main()
