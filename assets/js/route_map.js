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

    this.routes = new Map()
    this.handleEvent("routes-found", result => this.showRoutes(result))
    this.handleEvent("route-selected", route => this.selectRoute(route.id))
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
    this.routes.clear()
    this.map.flyTo([-1.2864, 36.8172], 11, {duration: 0.6})
  },

  selectRoute(id) {
    for (const [routeId, line] of this.routes) {
      const selected = routeId === id
      line.setStyle({
        color: selected ? "#c45124" : "#687d78",
        opacity: selected ? 1 : 0.55,
        weight: selected ? 7 : 5,
        className: selected ? "wazi-route-selected" : "wazi-route-alternative",
      })
      line.eachLayer(layer => {
        const path = layer.getElement()
        if (path) {
          path.classList.toggle("wazi-route-selected", selected)
          path.classList.toggle("wazi-route-alternative", !selected)
        }
      })
    }
    this.routes.get(id)?.bringToFront()
    this.endpointLayer.bringToFront()
  },

  showRoutes(result) {
    this.routeLayer.clearLayers()
    this.routes.clear()
    const bounds = L.latLngBounds([])

    for (const route of result.routes) {
      const line = L.geoJSON(route.geometry, {
        style: {lineCap: "round", lineJoin: "round"},
      }).addTo(this.routeLayer)
      line.on("click", () => this.pushEvent("select-route", {"route-id": route.id}))
      this.routes.set(route.id, line)
      bounds.extend(line.getBounds())
    }
    this.endpointLayer = L.featureGroup().addTo(this.routeLayer)

    const markerStyle = {
      color: "#fffaf0",
      fillColor: "#273f30",
      fillOpacity: 1,
      radius: 8,
      weight: 3,
    }

    L.circleMarker(result.origin, markerStyle).addTo(this.endpointLayer)
    L.circleMarker(result.destination, {...markerStyle, fillColor: "#e9ad45"}).addTo(this.endpointLayer)

    this.routeBounds = bounds
    this.selectRoute(result.selected_id)
    this.fitRoute()
  },

  destroyed() {
    this.resizeObserver.disconnect()
    cancelAnimationFrame(this.resizeFrame)
    this.map.remove()
  },
}

export default RouteMap
