// Copies a button's data-copy text and briefly shows a checkmark.

for (const button of document.querySelectorAll<HTMLButtonElement>("[data-copy]")) {
  let timeout: ReturnType<typeof setTimeout>;
  button.addEventListener("click", async () => {
    await navigator.clipboard.writeText(button.dataset.copy!);
    button.dataset.copied = "";
    clearTimeout(timeout);
    timeout = setTimeout(() => delete button.dataset.copied, 1500);
  });
}
