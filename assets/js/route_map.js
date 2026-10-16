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

    const bounds = line.getBounds()
    if (bounds.isValid()) {
      this.map.fitBounds(bounds, {padding: [48, 48], maxZoom: 16})
    }
  },

  destroyed() {
    this.map.remove()
  },
}

export default RouteMap
