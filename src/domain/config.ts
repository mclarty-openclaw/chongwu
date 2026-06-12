export type ScreenSize = {
  width: number;
  height: number;
};

export type CompanionConfig = {
  version: 1;
  window: {
    x: number;
    y: number;
    scale: number;
    opacity: number;
    alwaysOnTop: boolean;
  };
  behavior: {
    idleAnimation: boolean;
    bubbleEnabled: boolean;
    launchAtLogin: boolean;
  };
};

const CANVAS_WIDTH = 460;
const CANVAS_HEIGHT = 520;
const RIGHT_MARGIN = 48;
const BOTTOM_MARGIN = 80;

export function defaultWindowPosition(screen: ScreenSize): Pick<CompanionConfig["window"], "x" | "y"> {
  return {
    x: Math.max(0, screen.width - CANVAS_WIDTH - RIGHT_MARGIN),
    y: Math.max(0, screen.height - CANVAS_HEIGHT - BOTTOM_MARGIN),
  };
}

export const DEFAULT_CONFIG: CompanionConfig = {
  version: 1,
  window: {
    ...defaultWindowPosition({ width: 1920, height: 1080 }),
    scale: 1,
    opacity: 1,
    alwaysOnTop: true,
  },
  behavior: {
    idleAnimation: true,
    bubbleEnabled: true,
    launchAtLogin: false,
  },
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function numberOrDefault(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function booleanOrDefault(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

export function normalizeCompanionConfig(value: unknown): CompanionConfig {
  if (!isRecord(value) || value.version !== 1) {
    return DEFAULT_CONFIG;
  }

  const windowConfig = isRecord(value.window) ? value.window : {};
  const behaviorConfig = isRecord(value.behavior) ? value.behavior : {};

  return {
    version: 1,
    window: {
      x: numberOrDefault(windowConfig.x, DEFAULT_CONFIG.window.x),
      y: numberOrDefault(windowConfig.y, DEFAULT_CONFIG.window.y),
      scale: clamp(numberOrDefault(windowConfig.scale, DEFAULT_CONFIG.window.scale), 0.75, 1.25),
      opacity: clamp(numberOrDefault(windowConfig.opacity, DEFAULT_CONFIG.window.opacity), 0.7, 1),
      alwaysOnTop: booleanOrDefault(windowConfig.alwaysOnTop, DEFAULT_CONFIG.window.alwaysOnTop),
    },
    behavior: {
      idleAnimation: booleanOrDefault(behaviorConfig.idleAnimation, DEFAULT_CONFIG.behavior.idleAnimation),
      bubbleEnabled: booleanOrDefault(behaviorConfig.bubbleEnabled, DEFAULT_CONFIG.behavior.bubbleEnabled),
      launchAtLogin: booleanOrDefault(behaviorConfig.launchAtLogin, DEFAULT_CONFIG.behavior.launchAtLogin),
    },
  };
}
