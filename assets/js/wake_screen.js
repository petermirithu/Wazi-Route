const wakeScreen = document.getElementById("wake-screen")

if (wakeScreen) {
  const status = document.getElementById("wake-status")
  const attemptLabel = document.getElementById("wake-attempt")
  const nudgeButton = document.getElementById("wake-nudge")
  const road = document.getElementById("wake-road")
  let attempts = 0
  let nudges = 0
  let timer
  let stopped = false

  const messages = [
    "Checking the road ahead…",
    "Starting the route engine…",
    "Warming up the map and road conditions…",
    "Still waking—thanks for waiting with us.",
  ]

  const updateStatus = message => {
    if (status) status.textContent = message
    if (attemptLabel) attemptLabel.textContent = `Connection check ${attempts}`
  }

  const retry = async () => {
    if (stopped) return
    attempts += 1
    updateStatus(messages[Math.min(attempts - 1, messages.length - 1)])

    try {
      const response = await fetch("/healthz", {
        cache: "no-store",
        headers: {accept: "application/json"},
      })

      if (!response.ok) throw new Error("Server is not ready")

      stopped = true
      wakeScreen.dataset.ready = "true"
      updateStatus("The road is ready. Taking you in…")
      window.setTimeout(() => window.location.reload(), 450)
    } catch {
      const delay = Math.min(3000 + attempts * 750, 8000)
      timer = window.setTimeout(retry, delay)
    }
  }

  nudgeButton?.addEventListener("click", () => {
    nudges += 1
    road?.style.setProperty("--wake-nudges", nudges)

    if (nudges === 1) updateStatus("Nice push. The engine is listening…")
    else if (nudges === 3) updateStatus("Three good nudges—nearly there.")
    else if (nudges >= 6) updateStatus("You have official road-crew energy. Still checking…")
  })

  window.addEventListener("pagehide", () => {
    stopped = true
    window.clearTimeout(timer)
  }, {once: true})

  retry()
}
