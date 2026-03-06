import { LightningElement, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getKPIMetrics from "@salesforce/apex/ElaroExecutiveKPIController.getKPIMetrics";
import EXEC_DashboardTitle from "@salesforce/label/c.EXEC_DashboardTitle";
import EXEC_LoadingKPIs from "@salesforce/label/c.EXEC_LoadingKPIs";
import EXEC_TargetPrefix from "@salesforce/label/c.EXEC_TargetPrefix";
import EXEC_ErrorLoadingKPIs from "@salesforce/label/c.EXEC_ErrorLoadingKPIs";

export default class ElaroExecutiveKPIDashboard extends LightningElement {
  kpiMetrics = [];
  isLoading = false;
  hasError = false;
  errorMessage = "";

  label = { EXEC_DashboardTitle, EXEC_LoadingKPIs, EXEC_TargetPrefix, EXEC_ErrorLoadingKPIs };

  @wire(getKPIMetrics, { metadataRecordIds: "" })
  wiredKPIs({ error, data }) {
    if (data) {
      // Format values for display
      this.kpiMetrics = data.map((metric) => ({
        ...metric,
        formattedValue: this.formatValue(metric),
        formattedTarget: this.formatTarget(metric),
        statusBadgeVariant: this.getStatusBadgeVariant(metric),
        noError: !metric.hasError,
      }));
      this.isLoading = false;
      this.hasError = false;
    } else if (error) {
      this.hasError = true;
      this.errorMessage =
        EXEC_ErrorLoadingKPIs +
        " " +
        (error?.body?.message || error?.message || "An unknown error occurred");
      this.isLoading = false;
      this.showError(this.errorMessage);
    }
  }

  connectedCallback() {
    this.isLoading = true;
  }

  formatValue(metric) {
    if (!metric || metric.hasError) return "N/A";
    const value = metric.currentValue;
    if (value == null) return "N/A";

    if (metric.formatType === "currency") {
      return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(value);
    } else if (metric.formatType === "percent") {
      return (value * 100).toFixed(1) + "%";
    } else if (metric.formatType === "days") {
      return value.toFixed(1) + " days";
    }
    return value.toFixed(2);
  }

  formatTarget(metric) {
    if (!metric || !metric.targetValue) return "N/A";
    const value = metric.targetValue;

    if (metric.formatType === "currency") {
      return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(value);
    } else if (metric.formatType === "percent") {
      return (value * 100).toFixed(1) + "%";
    } else if (metric.formatType === "days") {
      return value.toFixed(1) + " days";
    }
    return value.toFixed(2);
  }

  getStatusBadgeVariant(metric) {
    if (!metric) return "default";
    if (metric.status === "green") return "success";
    if (metric.status === "yellow") return "warning";
    if (metric.status === "red") return "error";
    return "default";
  }

  showError(message) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Error",
        message: message,
        variant: "error",
      })
    );
  }
}
