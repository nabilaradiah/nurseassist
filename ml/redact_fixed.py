"""
redact_fixed.py — Batch redact a fixed region from all images in a folder.

Use this when patient info always appears in the SAME position across all images
(e.g. a hospital label strip at the top, or a corner sticker).

Usage:
    python redact_fixed.py

Requirements:
    pip install Pillow

Configuration:
    Edit the SETTINGS section below before running.
"""

from PIL import Image, ImageDraw, ImageFilter
import os
import sys

# ══════════════════════════════════════════════════════════════════════════════
# SETTINGS — edit these before running
# ══════════════════════════════════════════════════════════════════════════════

# Folder containing the original images
INPUT_FOLDER  = r"C:\path\to\your\dataset\images"

# Folder where anonymised images will be saved (created automatically)
OUTPUT_FOLDER = r"C:\path\to\your\dataset\images_anonymised"

# Region to redact — (left, top, right, bottom) in pixels
# Examples:
#   Top 80px strip:       (0, 0, 9999, 80)
#   Bottom 60px strip:    (0, -60, 9999, 9999)   ← use image height instead
#   Top-left corner box:  (0, 0, 200, 60)
#
# Set to None to skip a region.
REDACT_REGIONS = [
    (0, 0, 9999, 80),    # ← top 80px — adjust height to match your label
]

# Redaction style: 'black' fills with black, 'blur' applies heavy blur
REDACT_STYLE = 'black'   # 'black' | 'blur'

# Image file extensions to process
EXTENSIONS = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp'}

# ══════════════════════════════════════════════════════════════════════════════


def redact_region(img: Image.Image, region: tuple, style: str) -> Image.Image:
    """Apply redaction to a single region of an image."""
    w, h = img.size
    left   = max(0, region[0])
    top    = max(0, region[1])
    right  = min(w, region[2])
    bottom = min(h, region[3])

    if style == 'blur':
        # Crop the region, heavily blur it, paste back
        crop = img.crop((left, top, right, bottom))
        blurred = crop.filter(ImageFilter.GaussianBlur(radius=20))
        result = img.copy()
        result.paste(blurred, (left, top))
        return result
    else:
        # Fill with solid black
        result = img.copy().convert('RGB')
        draw = ImageDraw.Draw(result)
        draw.rectangle([left, top, right, bottom], fill=(0, 0, 0))
        return result


def process_folder():
    if not os.path.isdir(INPUT_FOLDER):
        print(f"ERROR: Input folder not found:\n  {INPUT_FOLDER}")
        sys.exit(1)

    os.makedirs(OUTPUT_FOLDER, exist_ok=True)

    files = [
        f for f in os.listdir(INPUT_FOLDER)
        if os.path.splitext(f)[1].lower() in EXTENSIONS
    ]

    if not files:
        print(f"No image files found in:\n  {INPUT_FOLDER}")
        sys.exit(0)

    print(f"Found {len(files)} images — applying redaction...")
    print(f"Style: {REDACT_STYLE}")
    print(f"Regions: {REDACT_REGIONS}\n")

    success = 0
    errors  = 0

    for i, filename in enumerate(files, 1):
        src = os.path.join(INPUT_FOLDER, filename)
        dst = os.path.join(OUTPUT_FOLDER, filename)

        try:
            img = Image.open(src)

            for region in REDACT_REGIONS:
                img = redact_region(img, region, REDACT_STYLE)

            # Always save as JPEG to normalise format
            out_name = os.path.splitext(filename)[0] + '.jpg'
            dst = os.path.join(OUTPUT_FOLDER, out_name)
            img.convert('RGB').save(dst, 'JPEG', quality=95)

            print(f"  [{i}/{len(files)}] ✓ {filename}")
            success += 1
        except Exception as e:
            print(f"  [{i}/{len(files)}] ✗ {filename} — {e}")
            errors += 1

    print(f"\nDone. {success} succeeded, {errors} failed.")
    print(f"Anonymised images saved to:\n  {OUTPUT_FOLDER}")


if __name__ == '__main__':
    process_folder()
