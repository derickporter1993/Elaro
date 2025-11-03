import { LightningElement, track } from "lwc";
import recent from "@salesforce/apex/DeploymentMetrics.recent";

export default class DeploymentMonitorDashboard extends LightningElement {
  @track rows = [];
  columns = [
    { label: "Name", fieldName: "name" },
    { label: "Status", fieldName: "status" },
    { label: "Started", fieldName: "startedOn", type: "date" },
    { label: "Finished", fieldName: "finishedOn", type: "date" },
    { label: "Passed", fieldName: "testsPassed", type: "number" },
    { label: "Failed", fieldName: "testsFailed", type: "number" },
  ];
  timer;
  pollInterval = 60000; // Base poll interval (60s)
  currentInterval = 60000; // Current interval with backoff
  errorBackoffMultiplier = 1; // Exponential backoff multiplier
  maxBackoffMultiplier = 8; // Max backoff is 8x base interval

  connectedCallback() {
    this.load();
    this.startPolling();
    // Pause polling when tab is hidden
    document.addEventListener("visibilitychange", this.handleVisibilityChange);
  }

  disconnectedCallback() {
    this.stopPolling();
    document.removeEventListener("visibilitychange", this.handleVisibilityChange);
  }

  handleVisibilityChange = () => {
    if (document.visibilityState === "visible") {
      this.startPolling();
      this.load(); // Load immediately when becoming visible
    } else {
      this.stopPolling();
    }
  };

  startPolling() {
    if (!this.timer && document.visibilityState === "visible") {
      this.timer = setInterval(() => this.load(), this.currentInterval);
    }
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  async load() {
    try {
      this.rows = await recent({ limitSize: 20 });

      // Reset backoff on success
      if (this.errorBackoffMultiplier > 1) {
        this.errorBackoffMultiplier = 1;
        this.currentInterval = this.pollInterval;
        // Restart timer with normal interval
        this.stopPolling();
        this.startPolling();
      }
    } catch (e) {
      /* eslint-disable no-console */
      console.error(e);

      // Apply exponential backoff on error
      if (this.errorBackoffMultiplier < this.maxBackoffMultiplier) {
        this.errorBackoffMultiplier *= 2;
        this.currentInterval = this.pollInterval * this.errorBackoffMultiplier;
        // Restart timer with increased interval
        this.stopPolling();
        this.startPolling();
      }
    }
  }
}
