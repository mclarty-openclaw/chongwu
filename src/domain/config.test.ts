import { describe, expect, it } from "vitest";
import { DEFAULT_CONFIG, defaultWindowPosition, normalizeCompanionConfig } from "./config";

describe("defaultWindowPosition", () => {
  it("places the 460 by 520 canvas near the lower-right of a 1920 by 1080 screen", () => {
    expect(defaultWindowPosition({ width: 1920, height: 1080 })).toEqual({ x: 1412, y: 480 });
  });
});

describe("normalizeCompanionConfig", () => {
  it("keeps valid persisted settings", () => {
    expect(
      normalizeCompanionConfig({
        version: 1,
        window: { x: 10, y: 20, scale: 1.25, opacity: 0.85, alwaysOnTop: false },
        behavior: { idleAnimation: false, bubbleEnabled: false, launchAtLogin: true },
      }),
    ).toEqual({
      version: 1,
      window: { x: 10, y: 20, scale: 1.25, opacity: 0.85, alwaysOnTop: false },
      behavior: { idleAnimation: false, bubbleEnabled: false, launchAtLogin: true },
    });
  });

  it("clamps invalid scale and opacity values to v1 supported ranges", () => {
    expect(
      normalizeCompanionConfig({
        ...DEFAULT_CONFIG,
        window: { ...DEFAULT_CONFIG.window, scale: 9, opacity: -1 },
      }),
    ).toMatchObject({
      window: { scale: 1.25, opacity: 0.7 },
    });
  });

  it("falls back to defaults for unreadable config data", () => {
    expect(normalizeCompanionConfig(null)).toEqual(DEFAULT_CONFIG);
    expect(normalizeCompanionConfig({ version: 99 })).toEqual(DEFAULT_CONFIG);
  });
});
