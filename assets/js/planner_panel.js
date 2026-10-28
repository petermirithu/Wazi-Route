const PlannerPanel = {
  mounted() {
    this.state = this.el.dataset.state
  },

  updated() {
    if (this.state !== this.el.dataset.state) {
      this.state = this.el.dataset.state
      this.el.scrollTo({top: 0})
    }
  },
}

export default PlannerPanel
