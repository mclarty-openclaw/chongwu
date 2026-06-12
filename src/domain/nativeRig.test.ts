import { readFileSync } from "node:fs";
import { readdirSync, statSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const swiftSource = readFileSync(resolve(process.cwd(), "native/CodexCompanion.swift"), "utf8");

describe("native desktop dancer rig", () => {
  it("plays a generated dancer frame sequence instead of moving one flat image", () => {
    expect(swiftSource).toContain("loadDancerFrames");
    expect(swiftSource).toContain("loadActionClip(for state");
    expect(swiftSource).toContain("framesForCurrentState");
    expect(swiftSource).toContain("updateDancerFrame");
    expect(swiftSource).toContain("dancer-actions");
    expect(swiftSource).not.toContain("codex.pet.motion");
    expect(swiftSource).not.toContain("dancerRigView = DancerRigView");
  });

  it("ships a separate native action clip for every Codex state", () => {
    const actionIds = [
      "idle",
      "codex-running",
      "command-running",
      "thinking",
      "long-running",
      "waiting-user",
      "success",
      "error",
    ];

    for (const actionId of actionIds) {
      const actionPath = resolve(process.cwd(), `public/assets/dancer-actions/${actionId}`);
      const frames = readdirSync(actionPath).filter((fileName) => /^frame-\d+\.png$/.test(fileName)).sort();

      expect(frames.length, actionId).toBeGreaterThanOrEqual(8);

      for (const frameName of frames) {
        expect(statSync(resolve(actionPath, frameName)).size, `${actionId}/${frameName}`).toBeGreaterThan(10_000);
      }
    }
  });

  it("documents the long-lived states that reuse the dream dance base", () => {
    const expectedPoseFamilies: Record<string, string> = {
      idle: "resting-idle",
      "codex-running": "dance-loop",
      "command-running": "focused-terminal",
      thinking: "slow-thinking-dance",
      "long-running": "slow-dream-dance",
      "waiting-user": "wave-dance-reminder",
      success: "jump-celebration",
      error: "magnifier-error",
    };

    for (const [actionId, poseFamily] of Object.entries(expectedPoseFamilies)) {
      const metadataPath = resolve(process.cwd(), `public/assets/dancer-actions/${actionId}/action.json`);
      const metadata = JSON.parse(readFileSync(metadataPath, "utf8")) as { poseFamily: string; primaryMotion: string };

      expect(metadata.poseFamily, actionId).toBe(poseFamily);
      if (["thinking", "long-running", "waiting-user"].includes(actionId)) {
        expect(metadata.primaryMotion, actionId).toContain("dance");
      } else {
        expect(metadata.primaryMotion, actionId).not.toBe("shared-dance-transform");
      }
    }
  });

  it("maps long-lived Codex states to the dancing clip instead of less attractive prop actions", () => {
    expect(swiftSource).toContain("case .codexRunning: return \"codex-running\"");
    expect(swiftSource).toContain("case .thinking, .longRunning, .waitingUser: return \"codex-running\"");
    expect(swiftSource).not.toContain("case .codexRunning:\n            drawKeyboardAccent");
    expect(swiftSource).not.toContain("drawKeyboardAccent");
  });

  it("implements the v3 larger native window and screen-dominant character size", () => {
    expect(swiftSource).toContain("NSSize(width: 720, height: 820)");
    expect(swiftSource).toContain("basePetHeight: CGFloat = 620");
    expect(swiftSource).toContain("let interval = activeFrameInterval()");
    expect(swiftSource).toContain("scheduledTimer(withTimeInterval: interval");
    expect(swiftSource).toContain("return 0.42");
  });

  it("uses an animated water stage and falling skirt sparkles instead of a blue base", () => {
    expect(swiftSource).toContain("final class StageReflectionView");
    expect(swiftSource).toContain("Stage Reflection Layer");
    expect(swiftSource).toContain("Soft Reflection Layer");
    expect(swiftSource).toContain("Falling Sparkle Layer");
    expect(swiftSource).toContain("sparklePhase");
    expect(swiftSource).toContain("animateStageEffects");
    expect(swiftSource).toContain("displayLinkTimer");
    expect(swiftSource).not.toContain("auraView.layer?.backgroundColor");
    expect(swiftSource).not.toContain("auraView.layer?.cornerRadius");
  });

  it("renders state-specific visual accents except codex_running dancing", () => {
    expect(swiftSource).toContain("final class StatusAccentView");
    for (const accent of [
      "drawTerminalAccent",
      "drawThinkingAccent",
      "drawCoffeeAccent",
      "drawWaitingAccent",
      "drawSuccessAccent",
      "drawMagnifierAccent",
    ]) {
      expect(swiftSource).toContain(accent);
    }
    expect(swiftSource).toContain("statusAccentView.state = currentState");
  });

  it("adds a right-click action demo submenu that can override automatic state detection", () => {
    expect(swiftSource).toContain("demoOverrideState");
    expect(swiftSource).toContain("动作演示");
    expect(swiftSource).toContain("恢复自动状态");

    for (const selector of [
      "demoIdle",
      "demoCodexRunning",
      "demoCommandRunning",
      "demoThinking",
      "demoLongRunning",
      "demoWaitingUser",
      "demoSuccess",
      "demoError",
      "clearDemoOverride",
    ]) {
      expect(swiftSource).toContain(selector);
    }
  });

  it("honors transient state expiry from the Codex hook bridge", () => {
    expect(swiftSource).toContain("var transientUntil: String?");
    expect(swiftSource).toContain("var nextState: String?");
    expect(swiftSource).toContain("isExpiredTransient");
    expect(swiftSource).toContain("nextState(from:");
  });

  it("does not treat the companion app path as active Codex work", () => {
    expect(swiftSource).toContain("fallbackState(processDetected:");
    expect(swiftSource).toContain("/Applications/Codex.app/Contents/Resources/codex");
    expect(swiftSource).not.toContain("task.arguments = [\"-f\", \"codex\"]");
  });

  it("keeps active Codex states visible briefly before returning to waiting", () => {
    expect(swiftSource).toContain("activeStateHoldUntil");
    expect(swiftSource).toContain("minimumVisibleActiveDuration");
    expect(swiftSource).toContain("isActiveCodexState");
  });

  it("parses hook timestamps with fractional seconds", () => {
    expect(swiftSource).toContain("parseISODate");
    expect(swiftSource).toContain(".withFractionalSeconds");
  });

  it("keeps native polling and rendering low overhead", () => {
    expect(swiftSource).toContain("detectCodexProcessCached");
    expect(swiftSource).toContain("processDetectionInterval");
    expect(swiftSource).toContain("needsProcessDetection");
    expect(swiftSource).toContain("maxCachedActionClips");
    expect(swiftSource).toContain("actionClips = [:]");
    expect(swiftSource).not.toContain("actionClips = loadActionClips()");
    expect(swiftSource).toContain("stageEffectInterval");
    expect(swiftSource).toContain("shouldAnimateStageEffects");
    expect(swiftSource).toContain("displayLinkTimer = Timer.scheduledTimer(withTimeInterval: stageEffectInterval");
    expect(swiftSource).not.toContain("withTimeInterval: 1.0 / 30.0");
    expect(swiftSource).not.toContain("updateDancerFrame(force: true)\n        if abs(currentFrameInterval");
  });
});
