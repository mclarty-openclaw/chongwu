#!/usr/bin/env python3
from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


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
    "idle": [3, 3, 3, 3, 3, 3, 3, 3],
    "command-running": [2, 2, 1, 1, 2, 2, 7, 7],
    "thinking": [5, 5, 7, 7, 5, 5, 7, 7],
    "long-running": [1, 1, 0, 0, 1, 1, 0, 0],
    "waiting-user": [6, 6, 6, 7, 7, 6, 6, 7],
    "success": [3, 4, 5, 6, 5, 4, 3, 4],
    "error": [0, 0, 7, 7, 0, 0, 7, 7],
}


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


def phase(index: int, count: int) -> float:
    return math.sin(index / count * math.tau)


def make_frame(action_id: str, source: Image.Image, index: int, count: int) -> Image.Image:
    p = phase(index, count)
    q = math.cos(index / count * math.tau)

    if action_id == "idle":
        return pose_canvas(source, angle=0.25 * p, dy=0.8 * p, scale=0.998 + 0.002 * q)

    elif action_id == "command-running":
        return pose_canvas(source, angle=-1.2 + 0.35 * p, dx=-4, dy=2, scale=1.005)

    elif action_id == "thinking":
        return pose_canvas(source, angle=0.9 * p, dx=2.5 * p, dy=0.5 * q, scale=1.0)

    elif action_id == "long-running":
        return pose_canvas(source, angle=-2.2 + 0.25 * p, dx=-3, dy=7 + 1.0 * p, scale=0.992)

    elif action_id == "waiting-user":
        return pose_canvas(source, angle=0.6 * p, dx=1.5 * p, dy=-1.0 * q, scale=1.004)

    elif action_id == "success":
        return pose_canvas(source, angle=1.8 * p, dx=2.5 * p, dy=-7 - 1.5 * q, scale=1.025)

    elif action_id == "error":
        return pose_canvas(source, angle=-3.8 + 0.35 * p, dx=-5, dy=3 + 0.8 * q, scale=0.996)

    return source.copy()


def write_metadata(spec: ActionSpec) -> None:
    target = ACTION_DIR / spec.action_id / "action.json"
    data = {
        "id": spec.action_id,
        "poseFamily": spec.pose_family,
        "primaryMotion": spec.primary_motion,
        "source": "public/assets/dancer-actions/codex-running",
        "motionTechnique": "single-source-pose-selection",
        "artifactControls": ["single-source-frame-no-overlay-afterimage"],
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
