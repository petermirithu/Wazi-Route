import L from "leaflet"

const RouteMap = {
  mounted() {
    this.map = L.map(this.el, {
      attributionControl: true,
      zoomControl: false,
    }).setView([-1.2864, 36.8172], 11)

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(this.map)

    L.control.zoom({position: "bottomright"}).addTo(this.map)
    this.routeLayer = L.featureGroup().addTo(this.map)

    this.handleEvent("route-selected", route => this.showRoute(route))
    this.handleEvent("route-cleared", () => this.clearRoute())

    this.panel = document.getElementById("planner-panel")
    this.controls = document.getElementById("dashboard-controls")
    this.resizeObserver = new ResizeObserver(() => {
      cancelAnimationFrame(this.resizeFrame)
      this.resizeFrame = requestAnimationFrame(() => {
        this.map.invalidateSize({pan: false})
        this.fitRoute(false)
      })
    })
    this.resizeObserver.observe(this.el)
    this.resizeObserver.observe(this.panel)
    this.resizeObserver.observe(this.controls)
    this.fitRoute(false)
  },

  fitRoute(animate = true) {
    const mapRect = this.el.getBoundingClientRect()
    const panelRect = this.panel.getBoundingClientRect()
    const controlsRect = this.controls.getBoundingClientRect()
    const mobile = window.matchMedia("(width < 48rem)").matches
    const bottom = mobile ? Math.max(0, mapRect.bottom - panelRect.top) : 0
    this.el.style.setProperty("--planner-overlay-height", `${bottom}px`)

    if (!this.routeBounds?.isValid()) return

    const top = Math.max(24, controlsRect.bottom - mapRect.top + 16)
    const left = mobile ? 24 : panelRect.right - mapRect.left + 24
    this.map.fitBounds(this.routeBounds, {
      paddingTopLeft: [left, top],
      paddingBottomRight: [24, bottom + 36],
      maxZoom: 16,
      animate,
    })
  },

  clearRoute() {
    this.routeBounds = null
    this.routeLayer.clearLayers()
    this.map.flyTo([-1.2864, 36.8172], 11, {duration: 0.6})
  },

  showRoute(route) {
    this.routeLayer.clearLayers()

    const line = L.geoJSON(route.geometry, {
      style: {
        color: "#a94f2d",
        opacity: 0.95,
        weight: 6,
        lineCap: "round",
        lineJoin: "round",
      },
    }).addTo(this.routeLayer)

    const markerStyle = {
      color: "#fffaf0",
      fillColor: "#273f30",
      fillOpacity: 1,
      radius: 8,
      weight: 3,
    }

    L.circleMarker(route.origin, markerStyle).addTo(this.routeLayer)
    L.circleMarker(route.destination, {...markerStyle, fillColor: "#e9ad45"}).addTo(this.routeLayer)

    this.routeBounds = line.getBounds()
    this.fitRoute()
  },

  destroyed() {
    this.resizeObserver.disconnect()
    cancelAnimationFrame(this.resizeFrame)
    this.map.remove()
  },
}

export default RouteMap
