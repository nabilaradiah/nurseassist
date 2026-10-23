"""
redact_interactive.py — Manually draw redaction boxes over each image.

Use this when patient info appears in DIFFERENT positions per image
(e.g. handwritten labels, varied sticker placement).

Controls:
    Left-click + drag  → draw a redaction box
    R                  → remove last box
    C                  → clear all boxes on this image
    ENTER or SPACE     → confirm and save, move to next image
    S                  → skip this image (copy unchanged)
    Q                  → quit (saves progress so far)

Usage:
    python redact_interactive.py

Requirements:
    pip install opencv-python Pillow
"""

import cv2
import os
import sys
import shutil
from pathlib import Path

# ══════════════════════════════════════════════════════════════════════════════
# SETTINGS — edit these before running
# ══════════════════════════════════════════════════════════════════════════════

INPUT_FOLDER  = r"C:\path\to\your\dataset\images"
OUTPUT_FOLDER = r"C:\path\to\your\dataset\images_anonymised"

# Redaction colour: (B, G, R) — default is solid black
REDACT_COLOR = (0, 0, 0)

# Extensions to process
EXTENSIONS = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp'}

# ══════════════════════════════════════════════════════════════════════════════

boxes       = []     # list of (x1, y1, x2, y2) confirmed boxes
drawing     = False
start_x = start_y = 0
current_img = None   # working copy shown on screen
original_img = None  # unmodified original


def draw_boxes(img):
    """Return a copy of img with all confirmed boxes drawn."""
    display = img.copy()
    for (x1, y1, x2, y2) in boxes:
        cv2.rectangle(display, (x1, y1), (x2, y2), REDACT_COLOR, -1)
    return display


def mouse_callback(event, x, y, flags, param):
    global drawing, start_x, start_y, current_img

    if event == cv2.EVENT_LBUTTONDOWN:
        drawing = True
        start_x, start_y = x, y

    elif event == cv2.EVENT_MOUSEMOVE and drawing:
        preview = draw_boxes(original_img)
        cv2.rectangle(preview, (start_x, start_y), (x, y), (0, 0, 200), 2)
        cv2.imshow('Redact', preview)

    elif event == cv2.EVENT_LBUTTONUP:
        drawing = False
        x1, y1 = min(start_x, x), min(start_y, y)
        x2, y2 = max(start_x, x), max(start_y, y)
        if abs(x2 - x1) > 5 and abs(y2 - y1) > 5:
            boxes.append((x1, y1, x2, y2))
        current_img = draw_boxes(original_img)
        cv2.imshow('Redact', current_img)


def process_folder():
    global boxes, drawing, current_img, original_img

    if not os.path.isdir(INPUT_FOLDER):
        print(f"ERROR: Input folder not found:\n  {INPUT_FOLDER}")
        sys.exit(1)

    os.makedirs(OUTPUT_FOLDER, exist_ok=True)

    files = sorted([
        f for f in os.listdir(INPUT_FOLDER)
        if Path(f).suffix.lower() in EXTENSIONS
    ])

    if not files:
        print(f"No image files found in:\n  {INPUT_FOLDER}")
        sys.exit(0)

    # Skip already-processed files
    already_done = set(os.listdir(OUTPUT_FOLDER))
    remaining = [f for f in files if f not in already_done]

    print(f"\nTotal images : {len(files)}")
    print(f"Already done : {len(already_done)}")
    print(f"Remaining    : {len(remaining)}\n")

    if not remaining:
        print("All images already processed.")
        return

    print("Controls:")
    print("  Left-click + drag → draw redaction box")
    print("  R                 → undo last box")
    print("  C                 → clear all boxes")
    print("  ENTER / SPACE     → save and next")
    print("  S                 → skip (copy unchanged)")
    print("  Q                 → quit\n")

    cv2.namedWindow('Redact', cv2.WINDOW_NORMAL)
    cv2.setMouseCallback('Redact', mouse_callback)

    for idx, filename in enumerate(remaining):
        src = os.path.join(INPUT_FOLDER, filename)

        original_img = cv2.imread(src)
        if original_img is None:
            print(f"  Skipping (cannot read): {filename}")
            continue

        # Resize window to fit image (max 1200×800)
        h, w = original_img.shape[:2]
        scale = min(1200 / w, 800 / h, 1.0)
        if scale < 1.0:
            original_img = cv2.resize(
                original_img,
                (int(w * scale), int(h * scale)),
                interpolation=cv2.INTER_AREA,
            )

        boxes.clear()
        current_img = original_img.copy()

        cv2.setWindowTitle(
            'Redact',
            f'[{idx + 1}/{len(remaining)}] {filename} — ENTER=save  S=skip  Q=quit'
        )
        cv2.imshow('Redact', current_img)

        saved  = False
        skip   = False
        quit_  = False

        while True:
            key = cv2.waitKey(20) & 0xFF

            if key in (13, 32):   # ENTER or SPACE → save
                saved = True
                break
            elif key == ord('s'): # S → skip
                skip = True
                break
            elif key == ord('q'): # Q → quit
                quit_ = True
                break
            elif key == ord('r'): # R → undo last
                if boxes:
                    boxes.pop()
                    current_img = draw_boxes(original_img)
                    cv2.imshow('Redact', current_img)
            elif key == ord('c'): # C → clear all
                boxes.clear()
                current_img = original_img.copy()
                cv2.imshow('Redact', current_img)

        dst = os.path.join(OUTPUT_FOLDER, filename)

        if saved:
            result = draw_boxes(original_img)
            cv2.imwrite(dst, result)
            n = len(boxes)
            print(f"  [{idx + 1}/{len(remaining)}] Saved  — {n} box{'es' if n != 1 else ''}: {filename}")
        elif skip:
            shutil.copy2(src, dst)
            print(f"  [{idx + 1}/{len(remaining)}] Skipped (copied unchanged): {filename}")
        elif quit_:
            print(f"\nQuit after {idx} images. Resume later — progress is saved.")
            break

    cv2.destroyAllWindows()
    print(f"\nDone. Anonymised images in:\n  {OUTPUT_FOLDER}")


if __name__ == '__main__':
    process_folder()
