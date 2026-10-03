#!/usr/bin/env python3
"""Compose App Store screenshots from the raw simulator screenshots.

Each slide gets a headline, a subheadline and the screenshot inside a phone
frame, rendered at 1320 x 2868 (the App Store's 6.9" iPhone size).
Captions come from AppStore/screenshot-captions.json.

Usage: compose_app_store_screenshots.py <raw dir> <output dir>
       [--locale en-US] [--bold FONT] [--regular FONT] [--cjk-fonts DIR]
       compose_app_store_screenshots.py --list-shots

Japanese, Korean, and Chinese captions use Noto Sans JP, KR, or SC
("NotoSansJP[wght].ttf" and so on) from --cjk-fonts.
"""

import argparse
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

CANVAS = (1320, 2868)
SCREEN_WIDTH = 930
BEZEL = 24
PHONE_TOP = 640
SUPERSAMPLE = 3

CAPTIONS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "AppStore", "screenshot-captions.json")

SLIDES = [
    ("08-homescreen", "dark", ("#DCE3FF", "#F4F1FF")),
    ("09-lockscreen", "dark", ("#FFE1D6", "#FFF3EC")),
    ("03-home", "light", ("#DDF3E4", "#F2FBF5")),
    ("05-editor", "light", ("#EEDDFB", "#F9F2FF")),
    ("04-detail", "light", ("#D8ECFF", "#F0F7FF")),
    ("06-settings", "light", ("#E3E8EF", "#F6F8FB")),
    ("07-premium", "light", ("#FFE9C7", "#FFF7EA")),
]

CJK_FONTS = {"ja": "NotoSansJP", "ko": "NotoSansKR", "zh-Hans": "NotoSansSC"}

SYSTEM_FONTS = [
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/SFNSDisplay.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]


def hex_color(value, alpha=255):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def load_font(path, size, weight):
    font = ImageFont.truetype(path, size)
    try:
        names = [n.decode() if isinstance(n, bytes) else n for n in font.get_variation_names()]
        if weight in names:
            font.set_variation_by_name(weight)
    except (OSError, AttributeError):
        pass
    return font


def fitted_font(path, size, weight, text, max_width):
    while size > 20:
        font = load_font(path, size, weight)
        widest = max(font.getlength(line) for line in text.split("\n"))
        if widest <= max_width:
            return font
        size -= 4
    return load_font(path, size, weight)


def gradient(size, top, bottom):
    width, height = size
    top, bottom = hex_color(top), hex_color(bottom)
    column = Image.new("RGBA", (1, height))
    for y in range(height):
        t = y / max(height - 1, 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return column.resize(size)


def rounded_mask(size, radius):
    big = (size[0] * SUPERSAMPLE, size[1] * SUPERSAMPLE)
    mask = Image.new("L", big, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big[0] - 1, big[1] - 1), radius * SUPERSAMPLE, fill=255)
    return mask.resize(size, Image.LANCZOS)


def phone(screenshot):
    scale = SCREEN_WIDTH / screenshot.width
    screen_size = (SCREEN_WIDTH, round(screenshot.height * scale))
    screen = screenshot.convert("RGBA").resize(screen_size, Image.LANCZOS)
    screen_radius = round(SCREEN_WIDTH * 0.142)

    island_width = round(SCREEN_WIDTH * 125 / 440)
    island_height = round(SCREEN_WIDTH * 37 / 440)
    island_top = round(SCREEN_WIDTH * 11 / 440)
    island = Image.new("RGBA", (island_width, island_height), (0, 0, 0, 255))
    screen.paste(island, ((SCREEN_WIDTH - island_width) // 2, island_top), rounded_mask(island.size, island_height // 2))

    size = (screen_size[0] + BEZEL * 2, screen_size[1] + BEZEL * 2)
    body = Image.new("RGBA", size, (0, 0, 0, 0))
    outer = rounded_mask(size, screen_radius + BEZEL)
    body.paste(Image.new("RGBA", size, hex_color("#3A3A3C")), (0, 0), outer)
    inner_size = (size[0] - 6, size[1] - 6)
    body.paste(Image.new("RGBA", inner_size, hex_color("#111113")), (3, 3), rounded_mask(inner_size, screen_radius + BEZEL - 3))
    body.paste(screen, (BEZEL, BEZEL), rounded_mask(screen_size, screen_radius))
    return body, outer


def compose(screenshot, headline, subheadline, colors, bold, regular):
    canvas = gradient(CANVAS, *colors)
    draw = ImageDraw.Draw(canvas)
    max_text = CANVAS[0] - 160

    headline_font = fitted_font(bold, 112, "Bold", headline, max_text)
    sub_font = fitted_font(regular, 50, "Regular", subheadline, max_text)
    y = 170
    draw.multiline_text((CANVAS[0] / 2, y), headline, font=headline_font, fill=hex_color("#111111"),
                        anchor="ma", align="center", spacing=10)
    box = draw.multiline_textbbox((CANVAS[0] / 2, y), headline, font=headline_font, anchor="ma", align="center", spacing=10)
    draw.multiline_text((CANVAS[0] / 2, box[3] + 34), subheadline, font=sub_font, fill=hex_color("#55555A"),
                        anchor="ma", align="center", spacing=12)

    body, outer = phone(screenshot)
    x = (CANVAS[0] - body.width) // 2
    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    shadow.paste(Image.new("RGBA", body.size, (20, 20, 40, 70)), (x, PHONE_TOP + 30), outer)
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(40)))
    layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    layer.paste(body, (x, PHONE_TOP), body)
    return Image.alpha_composite(canvas, layer).convert("RGB")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("raw", nargs="?")
    parser.add_argument("output", nargs="?")
    parser.add_argument("--locale", default="en-US")
    parser.add_argument("--bold")
    parser.add_argument("--regular")
    parser.add_argument("--cjk-fonts")
    parser.add_argument("--list-shots", action="store_true")
    args = parser.parse_args()

    if args.list_shots:
        print(",".join(f"{appearance}-{name}" for name, appearance, _ in SLIDES))
        return 0
    if not args.raw or not args.output:
        parser.error("raw and output folders are required")

    with open(CAPTIONS) as f:
        captions = json.load(f).get(args.locale)
    if not captions:
        print(f"::error::No captions for {args.locale} in {CAPTIONS}")
        return 1

    if args.locale in CJK_FONTS:
        if not args.cjk_fonts:
            print(f"::error::{args.locale} needs --cjk-fonts")
            return 1
        bold = regular = os.path.join(args.cjk_fonts, f"{CJK_FONTS[args.locale]}[wght].ttf")
    else:
        system = next((path for path in SYSTEM_FONTS if os.path.exists(path)), None)
        bold = args.bold or system
        regular = args.regular or args.bold or system
    if not bold or not os.path.exists(bold):
        print("::error::No font found. Pass --bold and --regular.")
        return 1

    os.makedirs(args.output, exist_ok=True)
    count = 0
    for index, (name, appearance, colors) in enumerate(SLIDES, start=1):
        source = os.path.join(args.raw, f"{appearance}-{name}.png")
        if not os.path.exists(source):
            print(f"skipping {name}: {source} not found")
            continue
        caption = captions[name]
        image = compose(Image.open(source), caption["headline"], caption["subheadline"], colors, bold, regular)
        image.save(os.path.join(args.output, f"{index:02d}-{name.split('-', 1)[1]}.png"), optimize=True)
        count += 1
    print(f"composed {count} {args.locale} App Store screenshots in {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
