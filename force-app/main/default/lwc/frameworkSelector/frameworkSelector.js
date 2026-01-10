import { LightningElement, api } from "lwc";

export default class FrameworkSelector extends LightningElement {
  @api frameworks = [];
  selectedFramework;

  // Framework descriptions for GDPR, CCPA, and PCI-DSS
  frameworkDescriptions = {
    GDPR: "General Data Protection Regulation - EU data privacy and protection framework",
    CCPA: "California Consumer Privacy Act - California consumer privacy rights framework",
    "PCI-DSS": "Payment Card Industry Data Security Standard - Cardholder data security framework",
    PCI_DSS: "Payment Card Industry Data Security Standard - Cardholder data security framework",
  };

  handleFrameworkChange(event) {
    this.selectedFramework = event.detail.value;
    const selectedEvent = new CustomEvent("frameworkselected", {
      detail: { framework: this.selectedFramework },
    });
    this.dispatchEvent(selectedEvent);
  }

  get frameworkOptions() {
    return this.frameworks.map((fw) => {
      const frameworkName = fw.framework;
      const description = this.frameworkDescriptions[frameworkName] || "";
      return {
        label: frameworkName + (fw.score ? " (" + fw.score + "%)" : ""),
        value: frameworkName,
        description: description,
      };
    });
  }

  get selectedFrameworkDescription() {
    if (!this.selectedFramework) {
      return "";
    }
    return this.frameworkDescriptions[this.selectedFramework] || "";
  }
}
