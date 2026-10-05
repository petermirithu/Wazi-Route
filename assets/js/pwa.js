let installPrompt = null
let installedInSession = false
const standalone = window.matchMedia("(display-mode: standalone)")
const installHelp = () => document.getElementById("install-help")
const installButton = () => document.getElementById("pwa-install")

function setStatus(message) {
  const status = document.getElementById("pwa-install-status")
  if (status) status.textContent = message
}

function syncInstallUI() {
  const installed = installedInSession || standalone.matches || navigator.standalone === true
  if (installHelp()) installHelp().hidden = installed
  if (installButton()) installButton().hidden = installed || !installPrompt
  if (!window.isSecureContext) setStatus("Open this site over HTTPS to install it.")
}

window.addEventListener("beforeinstallprompt", event => {
  event.preventDefault()
  installPrompt = event
  syncInstallUI()
})

window.addEventListener("appinstalled", () => {
  installPrompt = null
  installedInSession = true
  syncInstallUI()
})

standalone.addEventListener("change", syncInstallUI)
window.addEventListener("phx:page-loading-stop", syncInstallUI)

document.addEventListener("click", async event => {
  const button = event.target.closest("#pwa-install")
  if (!button || !installPrompt) return

  const prompt = installPrompt
  installPrompt = null
  button.hidden = true
  try {
    await prompt.prompt()
    const {outcome} = await prompt.userChoice
    setStatus(outcome === "accepted"
      ? "Follow your browser's instructions to finish installing Wazi Route."
      : "You can install later using your browser menu.")
  } catch {
    setStatus("Use your browser menu to add Wazi Route to your home screen.")
  }
})

syncInstallUI()

if (window.isSecureContext && "serviceWorker" in navigator) {
  const register = () => navigator.serviceWorker.register("/sw.js", {
    scope: "/",
    updateViaCache: "none",
  }).catch(error => console.warn("Wazi Route offline support is unavailable:", error))

  if (document.readyState === "complete") register()
  else window.addEventListener("load", register, {once: true})
}
