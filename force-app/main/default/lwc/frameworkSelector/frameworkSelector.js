import { LightningElement, api } from "lwc";
import FW_SelectFrameworkTitle from "@salesforce/label/c.FW_SelectFrameworkTitle";
import FW_LoadingFrameworks from "@salesforce/label/c.FW_LoadingFrameworks";
import FW_NoFrameworksAvailable from "@salesforce/label/c.FW_NoFrameworksAvailable";

export default class FrameworkSelector extends LightningElement {
  @api frameworks = [];
  selectedFramework;
  isLoading = false;
  hasError = false;
  errorMessage = "";

  label = {
    FW_SelectFrameworkTitle,
    FW_LoadingFrameworks,
    FW_NoFrameworksAvailable,
  };

  get hasFrameworks() {
    return this.frameworks && this.frameworks.length > 0;
  }

  get isEmpty() {
    return !this.isLoading && !this.hasError && !this.hasFrameworks;
  }

  get notLoading() {
    return !this.isLoading;
  }

  get notError() {
    return !this.hasError;
  }

  handleFrameworkChange(event) {
    this.selectedFramework = event.detail.value;
    const selectedEvent = new CustomEvent("frameworkselected", {
      detail: { framework: this.selectedFramework },
    });
    this.dispatchEvent(selectedEvent);
  }

  get frameworkOptions() {
    return this.frameworks.map((fw) => ({
      label: fw.framework + " (" + fw.score + "%)",
      value: fw.framework,
    }));
  }
}
