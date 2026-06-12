#!/usr/bin/env python3
from __future__ import annotations

import json
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
    "idle": [3, 3, 4, 3, 3, 5, 4, 3],
    "command-running": [0, 1, 2, 1, 0, 7, 6, 7],
    "thinking": [5, 6, 5, 7, 4, 5, 7, 6],
    "long-running": [1, 1, 0, 1, 2, 2, 1, 0],
    "waiting-user": [6, 5, 6, 7, 3, 4, 6, 7],
    "success": [3, 4, 5, 6, 7, 2, 5, 4],
    "error": [0, 1, 7, 0, 2, 7, 1, 0],
}


def make_frame(source: Image.Image) -> Image.Image:
    return source.copy()


def write_metadata(spec: ActionSpec, source_indexes: list[int]) -> None:
    target = ACTION_DIR / spec.action_id / "action.json"
    data = {
        "id": spec.action_id,
        "poseFamily": spec.pose_family,
        "primaryMotion": spec.primary_motion,
        "source": "public/assets/dancer-actions/codex-running",
        "motionTechnique": "single-source-pose-selection",
        "frameFidelity": "source-pixel-copy",
        "sourceFrameIndexes": source_indexes,
        "artifactControls": ["single-source-frame-no-overlay-afterimage", "no-resample-preserve-source-detail"],
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
            frame = make_frame(source)
            frame.save(target_dir / f"frame-{index}.png")

        write_metadata(spec, source_indexes)


if __name__ == "__main__":
    main()
