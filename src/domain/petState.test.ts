import { describe, expect, it } from "vitest";
import {
  actionClipForState,
  animationForState,
  bubbleForState,
  hatchAnimationForState,
  normalizeCodexState,
  nativeMotionForState,
  selectHighestPriority,
  type CodexStateFile,
  type PetState,
} from "./petState";

const now = Date.parse("2026-06-11T12:00:00+08:00");

function stateFile(state: string, updatedAt = "2026-06-11T11:59:45+08:00"): CodexStateFile {
  return {
    version: 1,
    updatedAt,
    codex: {
      detected: true,
      sessionActive: true,
      state,
      lastExitCode: null,
      lastEvent: "test",
      taskStartedAt: null,
    },
  };
}

describe("normalizeCodexState", () => {
  it("uses a fresh known state from the state file", () => {
    expect(normalizeCodexState(stateFile("command_running"), false, now)).toBe("command_running");
  });

  it("falls back to waiting_user when the state file is stale and a Codex process is detected", () => {
    expect(normalizeCodexState(stateFile("command_running", "2026-06-11T11:59:00+08:00"), true, now)).toBe(
      "waiting_user",
    );
  });

  it("falls back to idle when the state file is stale and no Codex process is detected", () => {
    expect(normalizeCodexState(stateFile("command_running", "2026-06-11T11:59:00+08:00"), false, now)).toBe(
      "idle",
    );
  });

  it("treats unknown fresh states as waiting_user when Codex is detected", () => {
    expect(normalizeCodexState(stateFile("new_future_state"), false, now)).toBe("waiting_user");
  });

  it("promotes a stale-running command to long_running after the configured threshold", () => {
    const running = stateFile("command_running");
    running.codex.taskStartedAt = "2026-06-11T11:58:00+08:00";

    expect(normalizeCodexState(running, true, now)).toBe("long_running");
  });

  it("uses the next state after a transient success or error expires", () => {
    const success = stateFile("success");
    success.codex.transientUntil = "2026-06-11T11:59:59+08:00";
    success.codex.nextState = "waiting_user";

    expect(normalizeCodexState(success, true, now)).toBe("waiting_user");
  });
});

describe("state priority and presentation", () => {
  it("selects the highest priority state", () => {
    const states: PetState[] = ["thinking", "success", "command_running", "error"];

    expect(selectHighestPriority(states)).toBe("error");
  });

  it("maps every v1 state to an animation", () => {
    const states: PetState[] = [
      "idle",
      "codex_running",
      "command_running",
      "thinking",
      "waiting_user",
      "success",
      "error",
      "long_running",
    ];

    expect(states.map(animationForState)).toEqual([
      "idle_sit",
      "dance_loop",
      "working_typing",
      "thinking",
      "waiting_wave",
      "success_jump",
      "error_sweat",
      "long_running_coffee",
    ]);
  });

  it("only shows bubbles for low-frequency status reminders", () => {
    expect(bubbleForState("waiting_user")).toBe("等你回复");
    expect(bubbleForState("success")).toBe("通过啦");
    expect(bubbleForState("error")).toBe("这里好像出错了");
    expect(bubbleForState("long_running")).toBe("还在跑...");
    expect(bubbleForState("command_running")).toBeNull();
  });

  it("maps application states to Hatch Pet animation rows", () => {
    const states: PetState[] = [
      "idle",
      "codex_running",
      "command_running",
      "thinking",
      "waiting_user",
      "success",
      "error",
      "long_running",
    ];

    expect(states.map(hatchAnimationForState)).toEqual([
      "idle",
      "review",
      "running",
      "review",
      "waiting",
      "jumping",
      "failed",
      "review",
    ]);
  });

  it("keeps native desktop global motion subtle so the frame sequence carries the character movement", () => {
    const states: PetState[] = [
      "idle",
      "codex_running",
      "command_running",
      "thinking",
      "waiting_user",
      "success",
      "error",
      "long_running",
    ];

    for (const state of states) {
      const motion = nativeMotionForState(state);

      expect(motion.durationMs).toBeGreaterThanOrEqual(700);
      expect(Math.max(Math.abs(motion.translateX), Math.abs(motion.translateY))).toBeLessThanOrEqual(4);
      expect(Math.abs(motion.rotateDeg)).toBeLessThanOrEqual(1.2);
    }
  });

  it("maps every state to a v3 native action clip and playback interval", () => {
    expect(actionClipForState("idle")).toMatchObject({ id: "codex-running", frameIntervalMs: 1200, fallbackFrameDirectory: "dancer-frames" });
    expect(actionClipForState("codex_running")).toMatchObject({
      id: "codex-running",
      frameIntervalMs: 420,
      fallbackFrameDirectory: "dancer-frames",
    });
    expect(actionClipForState("command_running")).toMatchObject({
      id: "codex-running",
      frameIntervalMs: 380,
      fallbackFrameDirectory: "dancer-frames",
    });
    expect(actionClipForState("thinking")).toMatchObject({ id: "codex-running", frameIntervalMs: 720 });
    expect(actionClipForState("long_running")).toMatchObject({ id: "codex-running", frameIntervalMs: 1000 });
    expect(actionClipForState("waiting_user")).toMatchObject({ id: "codex-running", frameIntervalMs: 700 });
    expect(actionClipForState("success")).toMatchObject({ id: "codex-running", frameIntervalMs: 300 });
    expect(actionClipForState("error")).toMatchObject({ id: "codex-running", frameIntervalMs: 720 });
  });
});
