import "./styles.css";
import { DEFAULT_CONFIG, normalizeCompanionConfig, type CompanionConfig } from "./domain/config";
import {
  bubbleForState,
  hatchAnimationForState,
  normalizeCodexState,
  type CodexStateFile,
  type HatchPetAnimation,
  type PetState,
} from "./domain/petState";

type HatchPetManifest = {
  name?: string;
  frameWidth?: number;
  frameHeight?: number;
  columns?: number;
  rows?: number;
  states?: Record<string, unknown>;
};

const CONFIG_STORAGE_KEY = "codexCompanion.config";
const STATE_STORAGE_KEY = "codexCompanion.stateFile";
const CANVAS_WIDTH = 460;
const CANVAS_HEIGHT = 520;
const FRAME_WIDTH = 192;
const FRAME_HEIGHT = 208;
const HATCH_COLUMNS = 8;
const HATCH_STATES: HatchPetAnimation[] = [
  "idle",
  "running-right",
  "running-left",
  "waving",
  "jumping",
  "failed",
  "waiting",
  "running",
  "review",
];

const app = document.querySelector<HTMLDivElement>("#app");

if (!app) {
  throw new Error("Missing #app root");
}

const root = app;
let config = loadConfig();
let currentState: PetState = "idle";
let previousBaseState: PetState = "idle";
let transientUntil = 0;
let frameIndex = 0;
let animationTimer = 0;
let menuOpen = false;
let paused = false;
let hatchManifest: HatchPetManifest | null = null;

root.innerHTML = `
  <main class="companion" data-state="idle">
    <section class="pet-stage" aria-label="Codex Companion">
      <div class="status-bubble" hidden></div>
      <div class="sprite hatch-sprite" hidden></div>
      <img class="sprite placeholder-sprite" src="/assets/pet-placeholder.png" alt="Codex Companion" />
    </section>
    <menu class="context-menu" hidden>
      <li class="menu-status"></li>
      <li class="menu-group" aria-label="大小">
        <button type="button" data-scale="0.75">75%</button>
        <button type="button" data-scale="1">100%</button>
        <button type="button" data-scale="1.25">125%</button>
      </li>
      <li class="menu-group" aria-label="透明度">
        <button type="button" data-opacity="0.7">70%</button>
        <button type="button" data-opacity="0.85">85%</button>
        <button type="button" data-opacity="1">100%</button>
      </li>
      <li><button type="button" data-action="always-on-top">总在最前</button></li>
      <li><button type="button" data-action="pause">暂停动画</button></li>
      <li><button type="button" data-action="exit">退出</button></li>
    </menu>
  </main>
`;

const companion = root.querySelector<HTMLElement>(".companion")!;
const bubble = root.querySelector<HTMLElement>(".status-bubble")!;
const hatchSprite = root.querySelector<HTMLElement>(".hatch-sprite")!;
const placeholderSprite = root.querySelector<HTMLImageElement>(".placeholder-sprite")!;
const contextMenu = root.querySelector<HTMLElement>(".context-menu")!;
const menuStatus = root.querySelector<HTMLElement>(".menu-status")!;

applyConfig();
wireInteractions();
void initializeRenderer();
void refreshState();
window.setInterval(refreshState, 1_000);

function loadConfig(): CompanionConfig {
  try {
    return normalizeCompanionConfig(JSON.parse(localStorage.getItem(CONFIG_STORAGE_KEY) ?? "null"));
  } catch {
    return DEFAULT_CONFIG;
  }
}

function saveConfig(nextConfig: CompanionConfig): void {
  config = normalizeCompanionConfig(nextConfig);
  localStorage.setItem(CONFIG_STORAGE_KEY, JSON.stringify(config));
  applyConfig();
}

function applyConfig(): void {
  const petHeight = Math.round(320 * config.window.scale);
  companion.style.setProperty("--pet-height", `${petHeight}px`);
  companion.style.setProperty("--window-opacity", String(config.window.opacity));
  companion.style.width = `${CANVAS_WIDTH}px`;
  companion.style.height = `${CANVAS_HEIGHT}px`;
}

async function initializeRenderer(): Promise<void> {
  hatchManifest = await loadHatchManifest();
  if (hatchManifest) {
    placeholderSprite.hidden = true;
    hatchSprite.hidden = false;
    hatchSprite.style.setProperty("--frame-width", `${hatchManifest.frameWidth ?? FRAME_WIDTH}px`);
    hatchSprite.style.setProperty("--frame-height", `${hatchManifest.frameHeight ?? FRAME_HEIGHT}px`);
    hatchSprite.style.backgroundImage = 'url("/assets/spritesheet.webp")';
    startHatchAnimation();
  }
}

async function loadHatchManifest(): Promise<HatchPetManifest | null> {
  try {
    const [manifestResponse, sheetResponse] = await Promise.all([
      fetch("/assets/pet.json", { cache: "no-store" }),
      fetch("/assets/spritesheet.webp", { cache: "no-store" }),
    ]);

    if (!manifestResponse.ok || !sheetResponse.ok) {
      return null;
    }

    return (await manifestResponse.json()) as HatchPetManifest;
  } catch {
    return null;
  }
}

async function refreshState(): Promise<void> {
  const stateFile = await readStateFile();
  const processDetected = await readCodexDetected();
  const nextState = normalizeCodexState(stateFile, processDetected);

  if (nextState !== "success" && nextState !== "error") {
    previousBaseState = nextState;
  }

  const now = Date.now();
  if ((nextState === "success" || nextState === "error") && nextState !== currentState) {
    transientUntil = now + 4_000;
  }

  currentState = transientUntil > now ? nextState : previousBaseState;
  renderState();
}

async function readStateFile(): Promise<CodexStateFile | null> {
  const fromTauri = await invokeOptional<CodexStateFile | null>("read_codex_state");
  if (fromTauri) {
    return fromTauri;
  }

  try {
    return JSON.parse(localStorage.getItem(STATE_STORAGE_KEY) ?? "null") as CodexStateFile | null;
  } catch {
    return null;
  }
}

async function readCodexDetected(): Promise<boolean> {
  return (await invokeOptional<boolean>("detect_codex_process")) ?? false;
}

async function invokeOptional<T>(command: string, args?: Record<string, unknown>): Promise<T | null> {
  if (!("__TAURI_INTERNALS__" in window)) {
    return null;
  }

  try {
    const { invoke } = await import("@tauri-apps/api/core");
    return await invoke<T>(command, args);
  } catch {
    return null;
  }
}

function renderState(): void {
  companion.dataset.state = currentState;
  menuStatus.textContent = `状态：${currentState}`;

  const bubbleText = config.behavior.bubbleEnabled ? bubbleForState(currentState) : null;
  bubble.hidden = !bubbleText;
  bubble.textContent = bubbleText ?? "";

  if (!hatchManifest) {
    placeholderSprite.dataset.animation = paused ? "paused" : currentState;
    return;
  }

  if (!paused) {
    frameIndex = 0;
    updateHatchFrame();
  }
}

function startHatchAnimation(): void {
  window.clearInterval(animationTimer);
  animationTimer = window.setInterval(() => {
    if (paused || !hatchManifest) {
      return;
    }
    frameIndex = (frameIndex + 1) % (hatchManifest.columns ?? HATCH_COLUMNS);
    updateHatchFrame();
  }, 140);
}

function updateHatchFrame(): void {
  const hatchState = hatchAnimationForState(currentState);
  const row = Math.max(0, HATCH_STATES.indexOf(hatchState));
  const frameWidth = hatchManifest?.frameWidth ?? FRAME_WIDTH;
  const frameHeight = hatchManifest?.frameHeight ?? FRAME_HEIGHT;
  hatchSprite.style.backgroundPosition = `-${frameIndex * frameWidth}px -${row * frameHeight}px`;
}

function wireInteractions(): void {
  companion.addEventListener("contextmenu", (event) => {
    event.preventDefault();
    menuOpen = !menuOpen;
    contextMenu.hidden = !menuOpen;
    contextMenu.style.left = `${Math.min(event.offsetX, CANVAS_WIDTH - 180)}px`;
    contextMenu.style.top = `${Math.min(event.offsetY, CANVAS_HEIGHT - 220)}px`;
  });

  companion.addEventListener("dblclick", () => {
    menuOpen = !menuOpen;
    contextMenu.hidden = !menuOpen;
  });

  contextMenu.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLButtonElement)) {
      return;
    }

    if (target.dataset.scale) {
      saveConfig({ ...config, window: { ...config.window, scale: Number(target.dataset.scale) } });
    }

    if (target.dataset.opacity) {
      saveConfig({ ...config, window: { ...config.window, opacity: Number(target.dataset.opacity) } });
    }

    if (target.dataset.action === "always-on-top") {
      saveConfig({ ...config, window: { ...config.window, alwaysOnTop: !config.window.alwaysOnTop } });
      void invokeOptional("set_always_on_top", { value: config.window.alwaysOnTop });
    }

    if (target.dataset.action === "pause") {
      paused = !paused;
      renderState();
    }

    if (target.dataset.action === "exit") {
      void closeWindow();
    }
  });

  companion.addEventListener("pointerdown", (event) => {
    if (event.button !== 0 || menuOpen) {
      return;
    }
    void startDrag();
  });
}

async function startDrag(): Promise<void> {
  const dragged = await invokeOptional<boolean>("start_dragging");
  if (dragged) {
    return;
  }

  if (!("__TAURI_INTERNALS__" in window)) {
    companion.classList.add("browser-drag-hint");
    window.setTimeout(() => companion.classList.remove("browser-drag-hint"), 800);
  }
}

async function closeWindow(): Promise<void> {
  const closed = await invokeOptional<boolean>("close_window");
  if (!closed) {
    root.innerHTML = "";
  }
}
