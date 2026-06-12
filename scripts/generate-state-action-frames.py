#!/usr/bin/env python3
from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ACTION_DIR = ROOT / "public" / "assets" / "dancer-actions"
SOURCE_DIR = ACTION_DIR / "codex-running"


@dataclass(frozen=True)
class ActionSpec:
    action_id: str
    pose_family: str
    primary_motion: str
    frame_interval_ms: int


SPECS = [
    ActionSpec("idle", "idle-breathing-pose", "calm breathing dance with tiny upper-body and skirt motion", 1200),
    ActionSpec("command-running", "terminal-forward-focus", "focused forward-leaning dance with active upper-body motion", 380),
    ActionSpec("thinking", "thinking-turn-pose", "slow thinking dance with head turn and contemplative upper-body tilt", 720),
    ActionSpec("long-running", "tired-slow-pose", "tired slow dance with drooping head and softened skirt motion", 1000),
    ActionSpec("waiting-user", "raised-hand-wave", "waiting dance with obvious raised-hand wave motion", 700),
    ActionSpec("success", "star-celebration-pose", "celebration dance with lifted torso and expanded skirt motion", 300),
    ActionSpec("error", "concerned-tilt-pose", "concerned dance with tilted head and cautious body motion", 720),
]

SOURCE_INDEXES = {
    "idle": [3, 3, 4, 4, 5, 5, 3, 3],
    "command-running": [2, 2, 1, 1, 2, 2, 7, 7],
    "thinking": [5, 5, 7, 7, 5, 5, 7, 7],
    "long-running": [1, 1, 0, 0, 1, 1, 0, 0],
    "waiting-user": [6, 6, 6, 7, 7, 6, 6, 7],
    "success": [3, 4, 5, 6, 5, 4, 3, 4],
    "error": [0, 0, 7, 7, 0, 0, 7, 7],
}


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return (0, 0, image.width, image.height)
    return bbox


def region_box(bbox: tuple[int, int, int, int], name: str) -> tuple[int, int, int, int]:
    left, top, right, bottom = bbox
    width = right - left
    height = bottom - top

    regions = {
        "head": (0.30, 0.00, 0.72, 0.30),
        "upper": (0.16, 0.10, 0.84, 0.56),
        "left_arm": (0.00, 0.02, 0.42, 0.45),
        "right_arm": (0.58, 0.02, 1.00, 0.45),
        "skirt": (0.00, 0.35, 1.00, 0.78),
        "legs": (0.30, 0.62, 0.72, 1.00),
    }
    x1, y1, x2, y2 = regions[name]
    return (
        max(0, int(left + width * x1)),
        max(0, int(top + height * y1)),
        min(640, int(left + width * x2)),
        min(640, int(top + height * y2)),
    )


def paste_transformed(
    base: Image.Image,
    source: Image.Image,
    box: tuple[int, int, int, int],
    *,
    angle: float = 0,
    dx: float = 0,
    dy: float = 0,
    scale: float = 1,
    alpha: float = 0.92,
) -> None:
    crop = source.crop(box)
    if scale != 1:
        width = max(1, int(crop.width * scale))
        height = max(1, int(crop.height * scale))
        crop = crop.resize((width, height), Image.Resampling.BICUBIC)

    if angle:
        crop = crop.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)

    if alpha < 1:
        r, g, b, a = crop.split()
        a = ImageEnhance.Brightness(a).enhance(alpha)
        crop = Image.merge("RGBA", (r, g, b, a))

    cx = (box[0] + box[2]) / 2 + dx
    cy = (box[1] + box[3]) / 2 + dy
    x = int(cx - crop.width / 2)
    y = int(cy - crop.height / 2)
    base.alpha_composite(crop, (x, y))


def pose_canvas(source: Image.Image, *, angle: float = 0, dx: float = 0, dy: float = 0, scale: float = 1) -> Image.Image:
    layer = source
    if scale != 1:
        layer = source.resize((int(source.width * scale), int(source.height * scale)), Image.Resampling.BICUBIC)
    if angle:
        layer = layer.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    canvas = Image.new("RGBA", source.size, (0, 0, 0, 0))
    x = int((source.width - layer.width) / 2 + dx)
    y = int((source.height - layer.height) / 2 + dy)
    canvas.alpha_composite(layer, (x, y))
    return canvas


def fade_region(image: Image.Image, box: tuple[int, int, int, int], opacity: float) -> None:
    crop = image.crop(box)
    r, g, b, a = crop.split()
    a = ImageEnhance.Brightness(a.filter(ImageFilter.GaussianBlur(1.2))).enhance(opacity)
    image.paste(Image.merge("RGBA", (r, g, b, a)), box)


def phase(index: int, count: int) -> float:
    return math.sin(index / count * math.tau)


def make_frame(action_id: str, source: Image.Image, index: int, count: int) -> Image.Image:
    p = phase(index, count)
    q = math.cos(index / count * math.tau)
    image = source.copy()
    bbox = alpha_bbox(source)

    if action_id == "idle":
        image = pose_canvas(source, angle=0.4 * p, dy=1.0 * p, scale=0.996 + 0.004 * q)
        fade_region(image, region_box(bbox, "upper"), 0.78)
        paste_transformed(image, source, region_box(bbox, "upper"), dy=1.4 * p, scale=1 + 0.006 * p, alpha=0.82)
        paste_transformed(image, source, region_box(bbox, "skirt"), dy=-1.0 * p, scale=1 + 0.012 * q, alpha=0.76)

    elif action_id == "command-running":
        image = pose_canvas(source, angle=-4.5 + 1.0 * p, dx=-10, dy=4, scale=1.01)
        fade_region(image, region_box(bbox, "upper"), 0.52)
        fade_region(image, region_box(bbox, "head"), 0.60)
        paste_transformed(image, source, region_box(bbox, "upper"), angle=-8 + 3.0 * p, dx=-15 + 3 * q, dy=8, scale=1.03, alpha=0.96)
        paste_transformed(image, source, region_box(bbox, "head"), angle=-9 + 3.0 * p, dx=-17, dy=5, alpha=0.96)
        paste_transformed(image, source, region_box(bbox, "skirt"), angle=4 * p, dx=4 * p, scale=0.988, alpha=0.70)

    elif action_id == "thinking":
        image = pose_canvas(source, angle=3.5 * p, dx=4 * p, dy=0, scale=1.0)
        fade_region(image, region_box(bbox, "head"), 0.48)
        fade_region(image, region_box(bbox, "upper"), 0.68)
        paste_transformed(image, source, region_box(bbox, "head"), angle=13 * p, dx=13 * p, dy=2 * q, alpha=0.98)
        paste_transformed(image, source, region_box(bbox, "upper"), angle=6 * p, dx=8 * p, dy=2, alpha=0.84)
        paste_transformed(image, source, region_box(bbox, "left_arm"), angle=-13 * q, dx=-11 * q, dy=5 * p, alpha=0.84)

    elif action_id == "long-running":
        image = pose_canvas(source, angle=-3.5, dx=-4, dy=10, scale=0.99)
        fade_region(image, region_box(bbox, "head"), 0.55)
        fade_region(image, region_box(bbox, "upper"), 0.62)
        paste_transformed(image, source, region_box(bbox, "head"), angle=-11 + 2 * p, dx=-9, dy=14 + 2 * p, alpha=0.94)
        paste_transformed(image, source, region_box(bbox, "upper"), angle=-6 + p, dx=-7, dy=12, scale=0.99, alpha=0.84)
        paste_transformed(image, source, region_box(bbox, "skirt"), dy=7 + 2 * p, scale=0.975, alpha=0.72)

    elif action_id == "waiting-user":
        image = pose_canvas(source, angle=1.5 * p, dx=2 * p, dy=0, scale=1.0)
        fade_region(image, region_box(bbox, "right_arm"), 0.42)
        fade_region(image, region_box(bbox, "upper"), 0.70)
        paste_transformed(image, source, region_box(bbox, "right_arm"), angle=24 * p, dx=22 * p, dy=-18 - 5 * q, scale=1.08, alpha=1.0)
        paste_transformed(image, source, region_box(bbox, "upper"), angle=2.2 * p, dx=2 * p, dy=1, alpha=0.76)
        paste_transformed(image, source, region_box(bbox, "skirt"), angle=-3 * p, dx=-2 * p, alpha=0.72)

    elif action_id == "success":
        image = pose_canvas(source, angle=4 * p, dx=3 * p, dy=-8 - 2 * q, scale=1.025)
        fade_region(image, region_box(bbox, "upper"), 0.55)
        fade_region(image, region_box(bbox, "skirt"), 0.58)
        paste_transformed(image, source, region_box(bbox, "upper"), angle=10 * p, dx=9 * p, dy=-16 - 3 * q, scale=1.06, alpha=0.97)
        paste_transformed(image, source, region_box(bbox, "left_arm"), angle=-18 * p, dx=-15 * p, dy=-10, alpha=0.88)
        paste_transformed(image, source, region_box(bbox, "right_arm"), angle=18 * p, dx=15 * p, dy=-10, alpha=0.88)
        paste_transformed(image, source, region_box(bbox, "skirt"), angle=9 * p, dx=8 * p, dy=-4, scale=1.07, alpha=0.90)

    elif action_id == "error":
        image = pose_canvas(source, angle=-7, dx=-8, dy=4, scale=0.998)
        fade_region(image, region_box(bbox, "head"), 0.46)
        fade_region(image, region_box(bbox, "upper"), 0.60)
        paste_transformed(image, source, region_box(bbox, "head"), angle=-17 + 3 * p, dx=-16, dy=7, alpha=0.98)
        paste_transformed(image, source, region_box(bbox, "upper"), angle=-10 + 2 * p, dx=-12, dy=6, scale=0.988, alpha=0.84)
        paste_transformed(image, source, region_box(bbox, "skirt"), angle=3 * p, dx=-5, dy=2, alpha=0.70)

    return image


def write_metadata(spec: ActionSpec) -> None:
    target = ACTION_DIR / spec.action_id / "action.json"
    data = {
        "id": spec.action_id,
        "poseFamily": spec.pose_family,
        "primaryMotion": spec.primary_motion,
        "source": "public/assets/dancer-actions/codex-running",
        "motionTechnique": "local-region-pose-transform",
        "frameCount": 8,
        "frameIntervalMs": spec.frame_interval_ms,
    }
    target.write_text(json.dumps(data, indent=2) + "\n")


def main() -> None:
    source_frames = [Image.open(path).convert("RGBA") for path in sorted(SOURCE_DIR.glob("frame-*.png"))]
    if len(source_frames) < 8:
        raise SystemExit("codex-running requires at least 8 source frames")

    for spec in SPECS:
        target_dir = ACTION_DIR / spec.action_id
        target_dir.mkdir(parents=True, exist_ok=True)
        for old in target_dir.glob("frame-*.png"):
            old.unlink()

        source_indexes = SOURCE_INDEXES[spec.action_id]
        for index, source_index in enumerate(source_indexes):
            source = source_frames[source_index]
            frame = make_frame(spec.action_id, source, index, 8)
            frame.save(target_dir / f"frame-{index}.png")

        write_metadata(spec)


if __name__ == "__main__":
    main()
