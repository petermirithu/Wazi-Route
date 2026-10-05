document.addEventListener("click", event => {
  const trigger = event.target.closest("[data-coming-soon]")
  if (!trigger || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

  const dialog = document.getElementById("launch-dialog")
  if (!dialog || typeof dialog.showModal !== "function") return

  event.preventDefault()
  dialog.showModal()
})

document.addEventListener("keydown", event => {
  if (event.key !== "Escape") return

  const dialog = document.getElementById("launch-dialog")
  if (dialog?.open) {
    event.preventDefault()
    dialog.close()
  }
})
