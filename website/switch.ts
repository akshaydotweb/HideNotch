// Drives the glass switch like the macOS 26 control. Pressing opens the glass lens. A click
// plays the full sequence (lens grows, knob slides, lens settles); a drag moves the knob
// with the pointer and decides the state on release.

const GROW_MS = 50;
const SLIDE_MS = 150;

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

for (const root of document.querySelectorAll<HTMLElement>(".glass-switch")) {
  const input = root.querySelector("input")!;
  const knob = root.querySelector<HTMLElement>(".glass-switch-knob")!;
  // How far the knob travels, as laid out by --travel in styles.css.
  const travel = () => root.clientWidth - knob.offsetWidth - 2 * knob.offsetLeft;
  let startX = 0;
  let lastX = 0;
  let startP = 0;
  let p = 0;
  let dragged = false;
  let busy = false;

  const set = (checked: boolean) => {
    if (input.checked === checked) return;
    input.checked = checked;
    input.dispatchEvent(new Event("change", { bubbles: true }));
  };

  root.addEventListener("pointerdown", (event) => {
    if (busy) return;
    root.setPointerCapture(event.pointerId);
    startX = lastX = event.clientX;
    startP = p = input.checked ? 1 : 0;
    dragged = false;
    root.dataset.pressed = "";
  });

  root.addEventListener("pointermove", (event) => {
    if (busy || !("pressed" in root.dataset)) return;
    if (Math.abs(event.clientX - startX) > 3) dragged = true;
    if (!dragged) return;

    p = Math.min(1, Math.max(0, startP + (event.clientX - startX) / travel()));
    root.dataset.dragging = "";
    root.style.setProperty("--p", String(p));
    // Stretch the lens with horizontal speed.
    root.style.setProperty("--stretch", String(Math.min(Math.abs(event.clientX - lastX), 12) * 0.025));
    lastX = event.clientX;
  });

  const release = async () => {
    root.style.removeProperty("--stretch");
    if (!dragged || busy) return;
    busy = true;
    delete root.dataset.dragging;
    set(p > 0.5);
    root.style.removeProperty("--p");
    await wait(200);
    delete root.dataset.pressed;
    busy = false;
  };

  root.addEventListener("pointerup", release);
  root.addEventListener("pointercancel", release);

  // Every click (pointer or keyboard) lands here. The native toggle is cancelled so the state
  // can change mid-animation instead.
  root.addEventListener("click", async (event) => {
    event.preventDefault();
    if (dragged) {
      dragged = false;
      return;
    }
    if (busy) return;
    busy = true;
    root.dataset.pressed = "";
    await wait(GROW_MS);
    set(!input.checked);
    await wait(SLIDE_MS);
    delete root.dataset.pressed;
    busy = false;
  });
}
