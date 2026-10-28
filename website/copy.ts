// Copies a button's data-copy text and briefly shows a checkmark.

import { track } from "@plausible-analytics/tracker";

for (const button of document.querySelectorAll<HTMLButtonElement>("[data-copy]")) {
  let timeout: ReturnType<typeof setTimeout>;
  button.addEventListener("click", async () => {
    await navigator.clipboard.writeText(button.dataset.copy!);
    track("Copy Homebrew command", {});
    button.dataset.copied = "";
    clearTimeout(timeout);
    timeout = setTimeout(() => delete button.dataset.copied, 1500);
  });
}
