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
    for (const [routeId, routeLayers] of this.routes) {
      const selected = routeId === id
      routeLayers.halo.setStyle({
        opacity: selected ? 0.94 : 0.6,
        weight: selected ? 12 : 9,
      })
      routeLayers.line.setStyle({
        color: selected ? "#bb5739" : "#5f8272",
        opacity: selected ? 1 : 0.72,
        weight: selected ? 6 : 4,
      })
      routeLayers.line.eachLayer(layer => {
        const path = layer.getElement()
        if (path) {
          path.classList.toggle("wazi-route-selected", selected)
          path.classList.toggle("wazi-route-alternative", !selected)
        }
      })
    }
    const selectedRoute = this.routes.get(id)
    selectedRoute?.halo.bringToFront()
    selectedRoute?.line.bringToFront()
    this.endpointLayer.bringToFront()
  },

  showRoutes(result) {
    this.routeLayer.clearLayers()
    this.routes.clear()
    const bounds = L.latLngBounds([])

    for (const route of result.routes) {
      const halo = L.geoJSON(route.geometry, {
        interactive: false,
        style: {
          color: "#fffaf0",
          lineCap: "round",
          lineJoin: "round",
          opacity: 0.6,
          weight: 9,
        },
      }).addTo(this.routeLayer)
      const line = L.geoJSON(route.geometry, {
        style: {lineCap: "round", lineJoin: "round"},
      }).addTo(this.routeLayer)

      line.on("click", () => this.pushEvent("select-route", {"route-id": route.id}))
      this.routes.set(route.id, {halo, line})
      bounds.extend(line.getBounds())
    }
    this.endpointLayer = L.featureGroup().addTo(this.routeLayer)

    L.marker(result.origin, {icon: this.endpointIcon("A", "origin")}).addTo(this.endpointLayer)
    L.marker(result.destination, {icon: this.endpointIcon("B", "destination")}).addTo(this.endpointLayer)

    this.routeBounds = bounds
    this.selectRoute(result.selected_id)
    this.fitRoute()
  },

  endpointIcon(label, kind) {
    return L.divIcon({
      className: "wazi-endpoint-marker",
      html: `<span class="wazi-endpoint-marker__core wazi-endpoint-marker__core--${kind}">${label}</span>`,
      iconSize: [38, 38],
      iconAnchor: [19, 19],
    })
  },

  destroyed() {
    this.resizeObserver.disconnect()
    cancelAnimationFrame(this.resizeFrame)
    this.map.remove()
  },
}

export default RouteMap
