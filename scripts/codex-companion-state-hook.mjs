#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const DEFAULT_STATE_PATH = path.join(os.homedir(), "Library/Application Support/CodexCompanion/state.json");
const STATE_PATH = process.env.CODEX_COMPANION_STATE_FILE || DEFAULT_STATE_PATH;
const SUCCESS_MS = 4_000;
const ERROR_MS = 5_000;

const completionPattern = /(测试通过|构建成功|已完成|完成了|完成|通过啦|passed|success|succeeded|done|built)/i;
const testCommandPattern = /\b(npm|pnpm|yarn|bun|vitest|jest|pytest|cargo|swift)\b.*\b(test|build|check|lint)\b|\b(test|build|check|lint)\b/i;
const readOnlyToolPattern = /(read|list|search|find|open|view|screenshot|browser|web|time|weather|finance)/i;
const commandToolPattern = /(bash|shell|exec|command|apply_patch|edit|write)/i;

export function stateFromHookEvent(event, previousStateFile, now = new Date()) {
  const hookEventName = String(event?.hook_event_name || "unknown");
  const toolName = String(event?.tool_name || "");
  const command = String(event?.tool_input?.command || "");
  const lastEvent = toolName ? `${hookEventName}:${toolName}` : hookEventName;
  const previousCodex = previousStateFile?.codex || {};

  if (hookEventName === "SessionStart") {
    return baseState("codex_running", lastEvent);
  }

  if (hookEventName === "UserPromptSubmit" || hookEventName === "PreCompact" || hookEventName === "PostCompact") {
    return baseState("thinking", lastEvent);
  }

  if (hookEventName === "PermissionRequest") {
    return baseState("waiting_user", lastEvent);
  }

  if (hookEventName === "PreToolUse") {
    if (isCommandLikeTool(toolName)) {
      return baseState("command_running", lastEvent, {
        taskStartedAt: previousCodex.state === "command_running" && previousCodex.taskStartedAt
          ? previousCodex.taskStartedAt
          : now.toISOString(),
      });
    }

    return baseState("thinking", lastEvent);
  }

  if (hookEventName === "PostToolUse") {
    const exitCode = exitCodeFromResponse(event?.tool_response);

    if (exitCode !== null && exitCode !== 0) {
      return transientState("error", lastEvent, exitCode, "thinking", ERROR_MS, now);
    }

    if (isTestOrBuildCommand(command)) {
      return transientState("success", lastEvent, exitCode, "thinking", SUCCESS_MS, now);
    }

    return baseState("thinking", lastEvent, { lastExitCode: exitCode });
  }

  if (hookEventName === "Stop") {
    const message = String(event?.last_assistant_message || "");
    if (completionPattern.test(message)) {
      return transientState("success", lastEvent, null, "waiting_user", SUCCESS_MS, now);
    }

    return baseState("waiting_user", lastEvent);
  }

  return baseState("codex_running", lastEvent);
}

export function buildStateFile(nextState, now = new Date()) {
  const codex = {
    detected: true,
    sessionActive: nextState.state !== "idle",
    state: nextState.state,
    lastExitCode: nextState.lastExitCode ?? null,
    lastEvent: nextState.lastEvent ?? null,
    taskStartedAt: nextState.taskStartedAt ?? null,
  };

  if (nextState.transientUntil) {
    codex.transientUntil = nextState.transientUntil;
  }

  if (nextState.nextState) {
    codex.nextState = nextState.nextState;
  }

  return {
    version: 1,
    updatedAt: now.toISOString(),
    codex,
  };
}

export async function run(input = process.stdin, output = process.stdout) {
  const event = JSON.parse(await readAll(input) || "{}");
  const previousStateFile = readPreviousStateFile(STATE_PATH);
  const now = new Date();
  const nextState = stateFromHookEvent(event, previousStateFile, now);
  writeStateFile(STATE_PATH, buildStateFile(nextState, now));

  if (event.hook_event_name === "Stop" || event.hook_event_name === "SubagentStop") {
    output.write(JSON.stringify({ continue: true }));
  }
}

function baseState(state, lastEvent, overrides = {}) {
  return {
    state,
    lastEvent,
    lastExitCode: overrides.lastExitCode ?? null,
    taskStartedAt: overrides.taskStartedAt ?? null,
  };
}

function transientState(state, lastEvent, lastExitCode, nextState, durationMs, now) {
  return {
    state,
    nextState,
    transientUntil: new Date(now.getTime() + durationMs).toISOString(),
    lastEvent,
    lastExitCode,
    taskStartedAt: null,
  };
}

function isCommandLikeTool(toolName) {
  return commandToolPattern.test(toolName) && !readOnlyToolPattern.test(toolName);
}

function isTestOrBuildCommand(command) {
  return testCommandPattern.test(command);
}

function exitCodeFromResponse(response) {
  if (!response || typeof response !== "object") {
    return null;
  }

  for (const key of ["exit_code", "exitCode", "status", "terminationStatus"]) {
    if (Number.isInteger(response[key])) {
      return response[key];
    }
  }

  return null;
}

function readPreviousStateFile(statePath) {
  try {
    return JSON.parse(fs.readFileSync(statePath, "utf8"));
  } catch {
    return null;
  }
}

function writeStateFile(statePath, stateFile) {
  fs.mkdirSync(path.dirname(statePath), { recursive: true });
  const temporaryPath = `${statePath}.tmp`;
  fs.writeFileSync(temporaryPath, `${JSON.stringify(stateFile, null, 2)}\n`);
  fs.renameSync(temporaryPath, statePath);
}

function readAll(input) {
  return new Promise((resolve, reject) => {
    let data = "";
    input.setEncoding("utf8");
    input.on("data", (chunk) => {
      data += chunk;
    });
    input.on("end", () => resolve(data));
    input.on("error", reject);
  });
}

const isMain = process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1]);

if (isMain) {
  run().catch((error) => {
    fs.mkdirSync(path.dirname(STATE_PATH), { recursive: true });
    fs.appendFileSync(
      path.join(path.dirname(STATE_PATH), "hook-error.log"),
      `${new Date().toISOString()} ${error.stack || error.message || error}\n`,
    );
    process.exit(0);
  });
}
