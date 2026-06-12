export type PetState =
  | "idle"
  | "codex_running"
  | "command_running"
  | "thinking"
  | "waiting_user"
  | "success"
  | "error"
  | "long_running";

export type PetAnimation =
  | "idle_sit"
  | "idle_blink"
  | "dance_loop"
  | "working_typing"
  | "thinking"
  | "waiting_wave"
  | "success_jump"
  | "error_sweat"
  | "long_running_coffee";

export type HatchPetAnimation =
  | "idle"
  | "running-right"
  | "running-left"
  | "waving"
  | "jumping"
  | "failed"
  | "waiting"
  | "running"
  | "review";

export type NativeMotionProfile = {
  translateX: number;
  translateY: number;
  rotateDeg: number;
  durationMs: number;
};

export type NativeActionClip = {
  id: string;
  frameIntervalMs: number;
  fallbackFrameDirectory: "dancer-frames";
};

export type CodexStateFile = {
  version: 1;
  updatedAt: string;
  codex: {
    detected: boolean;
    sessionActive: boolean;
    state: string;
    lastExitCode: number | null;
    lastEvent: string | null;
    taskStartedAt: string | null;
    transientUntil?: string | null;
    nextState?: string | null;
  };
};

const STALE_AFTER_MS = 30_000;
const LONG_RUNNING_AFTER_MS = 90_000;

const knownStates = new Set<PetState>([
  "idle",
  "codex_running",
  "command_running",
  "thinking",
  "waiting_user",
  "success",
  "error",
  "long_running",
]);

const priority: Record<PetState, number> = {
  idle: 0,
  codex_running: 1,
  thinking: 2,
  long_running: 3,
  command_running: 4,
  waiting_user: 5,
  success: 6,
  error: 7,
};

const presentationAnimations: Record<PetState, PetAnimation> = {
  idle: "idle_sit",
  codex_running: "dance_loop",
  command_running: "working_typing",
  thinking: "thinking",
  waiting_user: "waiting_wave",
  success: "success_jump",
  error: "error_sweat",
  long_running: "long_running_coffee",
};

const hatchAnimations: Record<PetState, HatchPetAnimation> = {
  idle: "idle",
  codex_running: "review",
  command_running: "running",
  thinking: "review",
  waiting_user: "waiting",
  success: "jumping",
  error: "failed",
  long_running: "review",
};

const nativeMotionProfiles: Record<PetState, NativeMotionProfile> = {
  idle: { translateX: 0, translateY: 10, rotateDeg: 1.1, durationMs: 1800 },
  codex_running: { translateX: 0, translateY: 12, rotateDeg: 1.4, durationMs: 1500 },
  command_running: { translateX: 10, translateY: 8, rotateDeg: 2.6, durationMs: 900 },
  thinking: { translateX: 0, translateY: 12, rotateDeg: 2.0, durationMs: 1300 },
  waiting_user: { translateX: 12, translateY: 10, rotateDeg: 4.0, durationMs: 1050 },
  success: { translateX: 0, translateY: 28, rotateDeg: 3.0, durationMs: 850 },
  error: { translateX: 16, translateY: 8, rotateDeg: 3.5, durationMs: 700 },
  long_running: { translateX: 0, translateY: 9, rotateDeg: 1.2, durationMs: 2200 },
};

const nativeActionClips: Record<PetState, NativeActionClip> = {
  idle: { id: "idle", frameIntervalMs: 1200, fallbackFrameDirectory: "dancer-frames" },
  codex_running: { id: "codex-running", frameIntervalMs: 420, fallbackFrameDirectory: "dancer-frames" },
  command_running: { id: "command-running", frameIntervalMs: 380, fallbackFrameDirectory: "dancer-frames" },
  thinking: { id: "codex-running", frameIntervalMs: 720, fallbackFrameDirectory: "dancer-frames" },
  waiting_user: { id: "codex-running", frameIntervalMs: 700, fallbackFrameDirectory: "dancer-frames" },
  success: { id: "success", frameIntervalMs: 300, fallbackFrameDirectory: "dancer-frames" },
  error: { id: "error", frameIntervalMs: 720, fallbackFrameDirectory: "dancer-frames" },
  long_running: { id: "codex-running", frameIntervalMs: 1000, fallbackFrameDirectory: "dancer-frames" },
};

const bubbles: Partial<Record<PetState, string>> = {
  waiting_user: "等你回复",
  success: "通过啦",
  error: "这里好像出错了",
  long_running: "还在跑...",
};

function isKnownPetState(value: string): value is PetState {
  return knownStates.has(value as PetState);
}

function isFresh(updatedAt: string, nowMs: number): boolean {
  const updatedAtMs = Date.parse(updatedAt);
  return Number.isFinite(updatedAtMs) && nowMs - updatedAtMs <= STALE_AFTER_MS;
}

export function normalizeCodexState(
  stateFile: CodexStateFile | null,
  processDetected: boolean,
  nowMs = Date.now(),
): PetState {
  if (!stateFile || !isFresh(stateFile.updatedAt, nowMs)) {
    return fallbackState(processDetected);
  }

  if (isKnownPetState(stateFile.codex.state)) {
    if (isExpiredTransient(stateFile.codex.state, stateFile.codex.transientUntil, nowMs)) {
      return nextKnownState(stateFile.codex.nextState, processDetected);
    }

    if (stateFile.codex.state === "command_running" && isLongRunning(stateFile.codex.taskStartedAt, nowMs)) {
      return "long_running";
    }

    return stateFile.codex.state;
  }

  return fallbackState(stateFile.codex.detected || processDetected);
}

function isLongRunning(taskStartedAt: string | null, nowMs: number): boolean {
  if (!taskStartedAt) {
    return false;
  }

  const taskStartedAtMs = Date.parse(taskStartedAt);
  return Number.isFinite(taskStartedAtMs) && nowMs - taskStartedAtMs >= LONG_RUNNING_AFTER_MS;
}

function isExpiredTransient(state: PetState, transientUntil: string | null | undefined, nowMs: number): boolean {
  if (state !== "success" && state !== "error") {
    return false;
  }

  if (!transientUntil) {
    return false;
  }

  const transientUntilMs = Date.parse(transientUntil);
  return Number.isFinite(transientUntilMs) && nowMs >= transientUntilMs;
}

function nextKnownState(nextState: string | null | undefined, processDetected: boolean): PetState {
  if (nextState && isKnownPetState(nextState) && nextState !== "success" && nextState !== "error") {
    return nextState;
  }

  return fallbackState(processDetected);
}

function fallbackState(processDetected: boolean): PetState {
  return processDetected ? "waiting_user" : "idle";
}

export function selectHighestPriority(states: PetState[]): PetState {
  return states.reduce<PetState>((selected, state) => (priority[state] > priority[selected] ? state : selected), "idle");
}

export function animationForState(state: PetState): PetAnimation {
  return presentationAnimations[state];
}

export function hatchAnimationForState(state: PetState): HatchPetAnimation {
  return hatchAnimations[state];
}

export function nativeMotionForState(state: PetState): NativeMotionProfile {
  return nativeMotionProfiles[state];
}

export function actionClipForState(state: PetState): NativeActionClip {
  return nativeActionClips[state];
}

export function bubbleForState(state: PetState): string | null {
  return bubbles[state] ?? null;
}
