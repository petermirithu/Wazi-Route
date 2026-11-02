const PlannerPanel = {
  mounted() {
    this.state = this.el.dataset.state
    this.content = this.el.querySelector("#planner-content")
    this.toggle = this.el.querySelector("#sheet-toggle")
    this.onPointerDown = event => {
      this.startY = event.clientY
      this.toggle.setPointerCapture(event.pointerId)
    }
    this.onPointerUp = event => {
      if (this.startY == null) return
      const distance = event.clientY - this.startY
      this.startY = null
      if (Math.abs(distance) > 30) {
        this.suppressClick = true
        this.pushEvent("set-sheet", {collapsed: distance > 0})
      }
    }
    this.onClick = event => {
      if (this.suppressClick) {
        event.stopImmediatePropagation()
        event.preventDefault()
        this.suppressClick = false
      }
    }
    this.onKeyDown = event => {
      const tab = event.target.closest('[role="tab"]')
      if (!tab || !["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return
      event.preventDefault()
      const tabs = [...this.el.querySelectorAll('[role="tab"]')]
      let index = tabs.indexOf(tab)
      if (event.key === "Home") index = 0
      else if (event.key === "End") index = tabs.length - 1
      else index = (index + (event.key === "ArrowRight" ? 1 : -1) + tabs.length) % tabs.length
      tabs[index].focus()
      this.pushEvent("select-route", {"route-id": tabs[index].getAttribute("phx-value-route-id")})
    }
    this.toggle.addEventListener("pointerdown", this.onPointerDown)
    this.toggle.addEventListener("pointerup", this.onPointerUp)
    this.toggle.addEventListener("click", this.onClick)
    this.el.addEventListener("keydown", this.onKeyDown)
  },

  updated() {
    if (this.state !== this.el.dataset.state) {
      this.state = this.el.dataset.state
      this.content.scrollTo({top: 0})
    }
  },

  destroyed() {
    this.toggle.removeEventListener("pointerdown", this.onPointerDown)
    this.toggle.removeEventListener("pointerup", this.onPointerUp)
    this.toggle.removeEventListener("click", this.onClick)
    this.el.removeEventListener("keydown", this.onKeyDown)
  },
}

export default PlannerPanel
