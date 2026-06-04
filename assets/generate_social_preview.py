from pathlib import Path
from typing import List, Tuple
import struct, zlib

out = Path(__file__).parent.resolve()
out.mkdir(parents=True, exist_ok=True)

W, H = 1280, 640
Color = Tuple[int, int, int]
bg1:    Color = (11,  18,  32)
bg2:    Color = (18,  38,  68)
accent: Color = (64,  163, 255)
accent2:Color = (0,   224, 196)
white:  Color = (245, 248, 255)
muted:  Color = (170, 185, 210)
shadow: Color = (6,   10,  18)

img: List[List[Color]] = [[bg1 for _ in range(W)] for _ in range(H)]

def lerp(a, b, t):
    return int(a + (b - a) * t)

for y in range(H):
    t = y / (H - 1)
    for x in range(W):
        u = x / (W - 1)
        mix = min(1.0, max(0.0, 0.65 * u + 0.35 * t))
        img[y][x] = (
            lerp(bg1[0], bg2[0], mix),
            lerp(bg1[1], bg2[1], mix),
            lerp(bg1[2], bg2[2], mix),
        )

for band in range(-H, W, 180):
    for y in range(H):
        x0 = band + y
        for dx in range(18):
            x = x0 + dx
            if 0 <= x < W:
                r, g, b = img[y][x]
                img[y][x] = (min(255, r + 6), min(255, g + 10), min(255, b + 18))

FONT = {
    'A': ['01110','10001','10001','11111','10001','10001','10001'],
    'C': ['01111','10000','10000','10000','10000','10000','01111'],
    'D': ['11110','10001','10001','10001','10001','10001','11110'],
    'E': ['11111','10000','10000','11110','10000','10000','11111'],
    'F': ['11111','10000','10000','11110','10000','10000','10000'],
    'G': ['01111','10000','10000','10011','10001','10001','01110'],
    'H': ['10001','10001','10001','11111','10001','10001','10001'],
    'I': ['11111','00100','00100','00100','00100','00100','11111'],
    'K': ['10001','10010','10100','11000','10100','10010','10001'],
    'L': ['10000','10000','10000','10000','10000','10000','11111'],
    'M': ['10001','11011','10101','10101','10001','10001','10001'],
    'N': ['10001','11001','10101','10011','10001','10001','10001'],
    'O': ['01110','10001','10001','10001','10001','10001','01110'],
    'P': ['11110','10001','10001','11110','10000','10000','10000'],
    'R': ['11110','10001','10001','11110','10100','10010','10001'],
    'S': ['01111','10000','10000','01110','00001','00001','11110'],
    'T': ['11111','00100','00100','00100','00100','00100','00100'],
    'V': ['10001','10001','10001','10001','10001','01010','00100'],
    'Y': ['10001','10001','01010','00100','00100','00100','00100'],
    ':': ['00000','00100','00100','00000','00100','00100','00000'],
    ' ': ['00000','00000','00000','00000','00000','00000','00000'],
}

def draw_rect(x, y, w, h, color):
    x = max(0, x); y = max(0, y)
    w = min(w, W - x); h = min(h, H - y)
    if w <= 0 or h <= 0: return
    for yy in range(y, y + h):
        row = img[yy]
        for xx in range(x, x + w):
            row[xx] = color

for y in range(86, 108):  draw_rect(92, y, 1096, 1, accent)
for y in range(524, 546): draw_rect(92, y, 1096, 1, accent2)
draw_rect(92, 154, 34, 332, accent)
draw_rect(130, 154, 18, 332, accent2)

def draw_char(ch, x, y, scale, color):
    pattern = FONT[ch]
    for ry, row in enumerate(pattern):
        for rx, bit in enumerate(row):
            if bit == '1':
                draw_rect(x + rx * scale, y + ry * scale, scale, scale, color)

def draw_text(text, x, y, scale, color, spacing=1):
    cx = x
    for ch in text:
        draw_char(ch, cx, y, scale, color)
        cx += (5 + spacing) * scale
    return cx

scale_title = 20
x_title, y_title = 280, 180
for ox, oy in [(6, 6), (4, 4)]:
    draw_text('HADES', x_title + ox, y_title + oy, scale_title, shadow, spacing=1)
draw_text('HADES', x_title, y_title, scale_title, white, spacing=1)

scale_sub = 8
for ox, oy in [(3, 3)]:
    draw_text('HERMES AGENT', 184 + ox, 368 + oy, scale_sub, shadow, spacing=1)
draw_text('HERMES AGENT', 184, 368, scale_sub, white, spacing=1)
draw_text('IN DOCKER', 184, 446, scale_sub, muted, spacing=1)

boxes = [
    (858, 160, 280, 88, accent),
    (902, 272, 236, 88, accent2),
    (814, 384, 324, 88, white),
]
for x, y, w, h, c in boxes:
    draw_rect(x + 10, y + 10, w, h, shadow)
    draw_rect(x, y, w, h, c)
    draw_rect(x + 12, y + 12, w - 24, h - 24, bg1 if c != white else bg2)

small = 5
draw_text('CLI',              936, 188, small, accent,  spacing=1)
draw_text('LOCAL API',        922, 300, small, accent2, spacing=1)
draw_text('PERSISTENT CONFIG',846, 412, small, white,   spacing=1)

raw = bytearray()
for row in img:
    raw.append(0)
    for r, g, b in row:
        raw.extend((r, g, b))

def chunk(tag, data):
    return struct.pack('!I', len(data)) + tag + data + struct.pack('!I', zlib.crc32(tag + data) & 0xFFFFFFFF)

png = bytearray(b'\x89PNG\r\n\x1a\n')
png += chunk(b'IHDR', struct.pack('!IIBBBBB', W, H, 8, 2, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
png += chunk(b'IEND', b'')
(out / 'social-preview.png').write_bytes(png)

svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="640" viewBox="0 0 1280 640" role="img" aria-label="HADES — Hermes Agent Docker Environment Script">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0b1220"/>
      <stop offset="100%" stop-color="#12304f"/>
    </linearGradient>
  </defs>
  <rect width="1280" height="640" fill="url(#bg)"/>
  <rect x="92" y="86" width="1096" height="22" rx="11" fill="#40a3ff"/>
  <rect x="92" y="524" width="1096" height="22" rx="11" fill="#00e0c4"/>
  <rect x="92" y="154" width="34" height="332" rx="10" fill="#40a3ff"/>
  <rect x="130" y="154" width="18" height="332" rx="9" fill="#00e0c4"/>
  <text x="280" y="290" fill="#f5f8ff" font-size="128" font-weight="800" font-family="Inter, Segoe UI, Arial, sans-serif" letter-spacing="8">HADES</text>
  <text x="184" y="390" fill="#f5f8ff" font-size="44" font-weight="700" font-family="Inter, Segoe UI, Arial, sans-serif">Hermes Agent</text>
  <text x="184" y="450" fill="#aab9d2" font-size="40" font-weight="500" font-family="Inter, Segoe UI, Arial, sans-serif">in Docker</text>
  <g>
    <rect x="858" y="160" width="280" height="88" rx="16" fill="#40a3ff"/>
    <rect x="870" y="172" width="256" height="64" rx="10" fill="#0b1220"/>
    <text x="945" y="213" fill="#40a3ff" font-size="30" font-weight="700" font-family="Inter, Segoe UI, Arial, sans-serif">CLI</text>
  </g>
  <g>
    <rect x="902" y="272" width="236" height="88" rx="16" fill="#00e0c4"/>
    <rect x="914" y="284" width="212" height="64" rx="10" fill="#0b1220"/>
    <text x="943" y="325" fill="#00e0c4" font-size="30" font-weight="700" font-family="Inter, Segoe UI, Arial, sans-serif">LOCAL API</text>
  </g>
  <g>
    <rect x="814" y="384" width="324" height="88" rx="16" fill="#f5f8ff"/>
    <rect x="826" y="396" width="300" height="64" rx="10" fill="#12304f"/>
    <text x="848" y="437" fill="#f5f8ff" font-size="28" font-weight="700" font-family="Inter, Segoe UI, Arial, sans-serif">PERSISTENT CONFIG</text>
  </g>
</svg>
'''
(out / 'social-preview.svg').write_text(svg)
(out / 'README.md').write_text(
'# Social preview assets\n\n'
'Primary file for GitHub social preview:\n\n'
'- `social-preview.png`\n\n'
'Suggested upload path in GitHub UI:\n\n'
'1. Open repository settings\n'
'2. Go to **General**\n'
'3. Find **Social preview**\n'
'4. Upload `assets/social-preview.png`\n\n'
'The matching SVG source is `social-preview.svg` for future edits.\n'
)
print('generated:', sorted(p.name for p in out.iterdir()))
