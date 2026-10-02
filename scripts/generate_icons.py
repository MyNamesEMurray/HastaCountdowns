import json
import math
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "App", "Assets.xcassets")
SIZE = 1024
SCALE = 2
S = SIZE * SCALE

VARIANTS = {
    "Default": {"top": (255, 179, 64), "bottom": (255, 45, 85), "ring": (255, 255, 255)},
    "Midnight": {"top": (34, 34, 70), "bottom": (6, 6, 14), "ring": (255, 159, 10)},
    "Ocean": {"top": (100, 210, 255), "bottom": (10, 96, 255), "ring": (255, 255, 255)},
    "Mint": {"top": (110, 235, 200), "bottom": (0, 160, 140), "ring": (255, 255, 255)},
    "Mono": {"top": (255, 255, 255), "bottom": (229, 229, 234), "ring": (28, 28, 30)},
}


def gradient(top, bottom):
    img = Image.new("RGB", (S, S))
    draw = ImageDraw.Draw(img)
    for y in range(S):
        t = y / (S - 1)
        color = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (S, y)], fill=color)
    return img


def draw_ring(img, color):
    draw = ImageDraw.Draw(img)
    cx = cy = S / 2
    radius = 300 * SCALE
    width = 112 * SCALE
    start, end = -90, 210
    box = [cx - radius, cy - radius, cx + radius, cy + radius]
    draw.arc(box, start=start, end=end, fill=color, width=width)
    mid = radius - width / 2
    for angle in (start, end):
        rad = math.radians(angle)
        x = cx + mid * math.cos(rad)
        y = cy + mid * math.sin(rad)
        r = width / 2
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)
    hub = 46 * SCALE
    draw.ellipse([cx - hub, cy - hub, cx + hub, cy + hub], fill=color)


def finish(img):
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def write_iconset(name, images):
    folder = os.path.join(ROOT, f"{name}.appiconset")
    os.makedirs(folder, exist_ok=True)
    entries = []
    for filename, image, appearance in images:
        image.save(os.path.join(folder, filename))
        entry = {"filename": filename, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        if appearance:
            entry = {"appearances": [{"appearance": "luminosity", "value": appearance}], **entry}
        entries.append(entry)
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": entries, "info": {"author": "xcode", "version": 1}}, f, indent=2)


def write_preview(name, image):
    folder = os.path.join(ROOT, f"IconPreview-{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    image.resize((180, 180), Image.LANCZOS).save(os.path.join(folder, "preview.png"))
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(
            {
                "images": [{"filename": "preview.png", "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1},
            },
            f,
            indent=2,
        )


for name, spec in VARIANTS.items():
    base = gradient(spec["top"], spec["bottom"])
    draw_ring(base, spec["ring"])
    icon = finish(base)
    set_name = "AppIcon" if name == "Default" else f"AppIcon-{name}"
    images = [("icon.png", icon, None)]
    if name == "Default":
        dark = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        draw_ring(dark, (255, 159, 10, 255))
        tinted = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        draw_ring(tinted, (235, 235, 235, 255))
        images += [("icon-dark.png", finish(dark), "dark"), ("icon-tinted.png", finish(tinted), "tinted")]
    write_iconset(set_name, images)
    write_preview(name, icon)

print("done")
