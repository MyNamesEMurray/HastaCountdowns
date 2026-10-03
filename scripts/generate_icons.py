"""Generates Hasta's app icons.

The mark is a small countdown widget: a rounded tile with a big number,
the "DAYS" label under it, and a sparkle in the corner.

Outputs:
  App/AppIcon.icon                      layered Liquid Glass icon (iOS 26+)
  App/Assets.xcassets/AppIcon.appiconset
      flat default, dark, and tinted icons for earlier iOS versions
  App/Assets.xcassets/AppIcon-<Name>.appiconset   alternate icons
  App/Assets.xcassets/IconPreview-<Name>.imageset previews for Settings

The number and label use Nunito (scripts/fonts, SIL Open Font License).
"""

import json
import math
import os
import shutil
from collections import namedtuple

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, "..", "App")
ASSETS = os.path.join(APP, "Assets.xcassets")
FONT = os.path.join(HERE, "fonts", "Nunito[wght].ttf")

SIZE = 1024
SS = 4
PX = SIZE * SS

TILE = (232, 232, 792, 792)
TILE_RADIUS = 132
NUMBER = "9"
NUMBER_SIZE = 430
NUMBER_ORIGIN = (TILE[0] + 82, TILE[3] - 160)
LABEL = "DAYS"
LABEL_SIZE = 70
LABEL_TRACKING = 6
LABEL_ORIGIN = (TILE[0] + 90, TILE[3] - 82)
SPARKLE_CENTER = (TILE[2] - 112, TILE[1] + 112)
SPARKLE_RADIUS = 58

Inks = namedtuple("Inks", "tile number label sparkle")

BRAND_TOP = (255, 179, 64)
BRAND_BOTTOM = (255, 45, 85)
LIGHT = Inks((255, 255, 255), (255, 62, 86), (255, 122, 84), (255, 160, 40))
DARK = Inks((46, 40, 44), (255, 96, 112), (255, 150, 112), (255, 176, 64))
TINTED = Inks((92, 92, 92), (255, 255, 255), (214, 214, 214), (255, 255, 255))
DARK_BG = ((60, 32, 40), (20, 12, 16))

Variant = namedtuple("Variant", "name top bottom inks")
ALTERNATES = [
    Variant("Midnight", (34, 34, 70), (6, 6, 14), Inks((30, 30, 48), (255, 159, 10), (255, 192, 96), (255, 159, 10))),
    Variant("Ocean", (100, 210, 255), (10, 96, 255), Inks((255, 255, 255), (10, 108, 255), (64, 150, 255), (80, 196, 250))),
    Variant("Mint", (110, 235, 200), (0, 160, 140), Inks((255, 255, 255), (0, 150, 128), (36, 186, 156), (60, 206, 168))),
    Variant("Mono", (255, 255, 255), (229, 229, 234), Inks((28, 28, 30), (255, 255, 255), (190, 190, 196), (255, 255, 255))),
]


def scaled(box):
    return tuple(v * SS for v in box)


def font(size):
    face = ImageFont.truetype(FONT, size * SS)
    face.set_variation_by_name("Black")
    return face


def tile_mask():
    mask = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(mask).rounded_rectangle(scaled(TILE), TILE_RADIUS * SS, fill=255)
    return mask


def number_mask():
    mask = Image.new("L", (PX, PX), 0)
    x, y = NUMBER_ORIGIN
    ImageDraw.Draw(mask).text((x * SS, y * SS), NUMBER, font=font(NUMBER_SIZE), fill=255, anchor="ls")
    return mask


def label_mask():
    mask = Image.new("L", (PX, PX), 0)
    draw = ImageDraw.Draw(mask)
    face = font(LABEL_SIZE)
    x, y = LABEL_ORIGIN[0] * SS, LABEL_ORIGIN[1] * SS
    for letter in LABEL:
        draw.text((x, y), letter, font=face, fill=255, anchor="ls")
        x += face.getlength(letter) + LABEL_TRACKING * SS
    return mask


def sparkle_mask():
    cx, cy = SPARKLE_CENTER[0] * SS, SPARKLE_CENTER[1] * SS
    r = SPARKLE_RADIUS * SS
    steps = 360
    points = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        c, s = math.cos(t), math.sin(t)
        points.append((cx + r * math.copysign(abs(c) ** 2.4, c), cy + r * math.copysign(abs(s) ** 2.4, s)))
    mask = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask


MASKS = {
    "tile": tile_mask(),
    "number": number_mask(),
    "label": label_mask(),
    "sparkle": sparkle_mask(),
}


def gradient(top, bottom):
    column = Image.new("RGBA", (1, PX))
    for y in range(PX):
        t = y / (PX - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    return column.resize((PX, PX))


def solid(rgb):
    return Image.new("RGBA", (PX, PX), tuple(rgb) + (255,))


def flat(inks, top=None, bottom=None):
    canvas = gradient(top, bottom) if top else Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
    if top:
        shadow = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
        offset = MASKS["tile"].transform(MASKS["tile"].size, Image.AFFINE, (1, 0, 0, 0, 1, -14 * SS))
        shadow.paste(solid((90, 20, 40)), (0, 0), offset.point(lambda v: v * 50 // 255))
        canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28 * SS)))
    for name, ink in (("tile", inks.tile), ("number", inks.number), ("label", inks.label), ("sparkle", inks.sparkle)):
        canvas.paste(solid(ink), (0, 0), MASKS[name])
    image = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    return image.convert("RGB") if top else image


def color(rgb):
    return "srgb:%.5f,%.5f,%.5f,1.00000" % tuple(c / 255 for c in rgb)


def solid_fills(name):
    return [
        {"value": {"solid": color(getattr(LIGHT, name))}},
        {"appearance": "dark", "value": {"solid": color(getattr(DARK, name))}},
        {"appearance": "tinted", "value": {"solid": color(getattr(TINTED, name))}},
    ]


def write_icon_package():
    path = os.path.join(APP, "AppIcon.icon")
    if os.path.isdir(path):
        shutil.rmtree(path)
    os.makedirs(os.path.join(path, "Assets"))
    white = solid((255, 255, 255))
    for name, mask in MASKS.items():
        layer = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
        layer.paste(white, (0, 0), mask)
        layer.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(path, "Assets", f"{name}.png"))

    def layer(name, title):
        return {"name": title, "image-name": f"{name}.png", "glass": True, "fill-specializations": solid_fills(name)}

    document = {
        "fill-specializations": [
            {"value": {"linear-gradient": [color(BRAND_TOP), color(BRAND_BOTTOM)]}},
            {"appearance": "dark", "value": {"linear-gradient": [color(DARK_BG[0]), color(DARK_BG[1])]}},
        ],
        "groups": [
            {
                "name": "Countdown",
                "layers": [layer("sparkle", "Sparkle"), layer("number", "Number"), layer("label", "Label")],
                "lighting": "individual",
                "specular": True,
                "shadow": {"kind": "neutral", "opacity": 0.3},
                "translucency": {"enabled": True, "value": 0.1},
            },
            {
                "name": "Tile",
                "layers": [layer("tile", "Tile")],
                "lighting": "individual",
                "specular": True,
                "shadow": {"kind": "neutral", "opacity": 0.5},
                "translucency": {"enabled": True, "value": 0.2},
            },
        ],
        "supported-platforms": {"squares": "shared"},
    }
    with open(os.path.join(path, "icon.json"), "w") as f:
        json.dump(document, f, indent=2, sort_keys=True)
        f.write("\n")


def write_iconset(name, images):
    folder = os.path.join(ASSETS, f"{name}.appiconset")
    if os.path.isdir(folder):
        shutil.rmtree(folder)
    os.makedirs(folder)
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
    folder = os.path.join(ASSETS, f"IconPreview-{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    image.resize((180, 180), Image.LANCZOS).save(os.path.join(folder, "preview.png"))
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(
            {"images": [{"filename": "preview.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
            f,
            indent=2,
        )


def main():
    write_icon_package()
    default = flat(LIGHT, BRAND_TOP, BRAND_BOTTOM)
    write_iconset("AppIcon", [
        ("icon.png", default, None),
        ("icon-dark.png", flat(DARK), "dark"),
        ("icon-tinted.png", flat(TINTED), "tinted"),
    ])
    write_preview("Default", default)
    for variant in ALTERNATES:
        image = flat(variant.inks, variant.top, variant.bottom)
        write_iconset(f"AppIcon-{variant.name}", [("icon.png", image, None)])
        write_preview(variant.name, image)
    print("done")


if __name__ == "__main__":
    main()
