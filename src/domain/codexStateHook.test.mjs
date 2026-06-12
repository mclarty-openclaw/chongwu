import { describe, expect, it } from "vitest";
import fs from "node:fs";
import path from "node:path";
import {
  buildStateFile,
  stateFromHookEvent,
} from "../../scripts/codex-companion-state-hook.mjs";

const now = new Date("2026-06-11T12:00:00+08:00");

function previousState(overrides = {}) {
  return {
    version: 1,
    updatedAt: "2026-06-11T11:59:58+08:00",
    codex: {
      detected: true,
      sessionActive: true,
      state: "thinking",
      lastExitCode: null,
      lastEvent: "UserPromptSubmit",
      taskStartedAt: null,
      ...overrides,
    },
  };
}

describe("Codex companion hook state bridge", () => {
  it("maps user prompts to the thinking state", () => {
    const next = stateFromHookEvent({ hook_event_name: "UserPromptSubmit" }, null, now);

    expect(next).toMatchObject({
      state: "thinking",
      lastEvent: "UserPromptSubmit",
      lastExitCode: null,
      taskStartedAt: null,
    });
  });

  it("maps shell tool starts to command_running and preserves the task start time", () => {
    const previous = previousState({ state: "command_running", taskStartedAt: "2026-06-11T11:59:30+08:00" });
    const next = stateFromHookEvent(
      { hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: { command: "npm test -- --run" } },
      previous,
      now,
    );

    expect(next).toMatchObject({
      state: "command_running",
      lastEvent: "PreToolUse:Bash",
      taskStartedAt: "2026-06-11T11:59:30+08:00",
    });
  });

  it("maps successful test commands to a transient success state", () => {
    const next = stateFromHookEvent(
      {
        hook_event_name: "PostToolUse",
        tool_name: "Bash",
        tool_input: { command: "npm test -- --run" },
        tool_response: { exit_code: 0 },
      },
      previousState({ state: "command_running", taskStartedAt: "2026-06-11T11:59:30+08:00" }),
      now,
    );

    expect(next).toMatchObject({
      state: "success",
      nextState: "thinking",
      lastExitCode: 0,
      taskStartedAt: null,
    });
    expect(Date.parse(next.transientUntil)).toBeGreaterThan(now.getTime());
  });

  it("maps failed tools to a transient error state", () => {
    const next = stateFromHookEvent(
      {
        hook_event_name: "PostToolUse",
        tool_name: "Bash",
        tool_input: { command: "npm run build" },
        tool_response: { exit_code: 1 },
      },
      previousState({ state: "command_running", taskStartedAt: "2026-06-11T11:59:30+08:00" }),
      now,
    );

    expect(next).toMatchObject({
      state: "error",
      nextState: "thinking",
      lastExitCode: 1,
      taskStartedAt: null,
    });
  });

  it("maps turn stop to waiting_user unless the final message clearly completed work", () => {
    expect(
      stateFromHookEvent({ hook_event_name: "Stop", last_assistant_message: "我需要你确认一下方向。" }, null, now),
    ).toMatchObject({ state: "waiting_user", lastEvent: "Stop" });

    expect(
      stateFromHookEvent({ hook_event_name: "Stop", last_assistant_message: "已完成，测试通过。" }, null, now),
    ).toMatchObject({ state: "success", nextState: "waiting_user" });
  });

  it("builds the v1 state file consumed by the native pet", () => {
    const stateFile = buildStateFile(
      { state: "waiting_user", lastEvent: "Stop", lastExitCode: null, taskStartedAt: null },
      now,
    );

    expect(stateFile).toEqual({
      version: 1,
      updatedAt: now.toISOString(),
      codex: {
        detected: true,
        sessionActive: true,
        state: "waiting_user",
        lastExitCode: null,
        lastEvent: "Stop",
        taskStartedAt: null,
      },
    });
  });

  it("installs a global hook config that writes Codex lifecycle events", () => {
    const hooksPath = path.resolve(process.env.HOME || "", ".codex/hooks.json");
    const projectHooksPath = path.resolve(".codex/hooks.json");

    expect(fs.existsSync(hooksPath)).toBe(true);
    expect(fs.readFileSync(hooksPath, "utf8")).toContain("codex-companion-state-hook.mjs");
    expect(fs.existsSync(projectHooksPath)).toBe(false);
  });
});
