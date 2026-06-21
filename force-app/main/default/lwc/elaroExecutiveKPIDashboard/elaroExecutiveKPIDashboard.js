import { LightningElement, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getKPIMetrics from "@salesforce/apex/ElaroExecutiveKPIController.getKPIMetrics";
import ELKPI_CardTitle from "@salesforce/label/c.ELKPI_CardTitle";
import ELKPI_MetricsAria from "@salesforce/label/c.ELKPI_MetricsAria";
import ELKPI_Target from "@salesforce/label/c.ELKPI_Target";
import ELKPI_LoadingAlt from "@salesforce/label/c.ELKPI_LoadingAlt";
import ELKPI_ErrorTitle from "@salesforce/label/c.ELKPI_ErrorTitle";
import ELKPI_ErrorLoadingPrefix from "@salesforce/label/c.ELKPI_ErrorLoadingPrefix";
import ELKPI_UnknownError from "@salesforce/label/c.ELKPI_UnknownError";
import ELKPI_NotApplicable from "@salesforce/label/c.ELKPI_NotApplicable";
import ELKPI_KpiCardAria from "@salesforce/label/c.ELKPI_KpiCardAria";

export default class ElaroExecutiveKPIDashboard extends LightningElement {
  kpiMetrics = [];
  isLoading = false;
  hasError = false;
  errorMessage = "";

  label = {
    ELKPI_CardTitle,
    ELKPI_MetricsAria,
    ELKPI_Target,
    ELKPI_LoadingAlt,
  };

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
        // ELKPI_KpiCardAria value is "KPI: {0}"
        cardAriaLabel: ELKPI_KpiCardAria.replace("{0}", metric.label ?? ""),
      }));
      this.isLoading = false;
      this.hasError = false;
    } else if (error) {
      this.hasError = true;
      this.errorMessage =
        ELKPI_ErrorLoadingPrefix +
        " " +
        (error?.body?.message || error?.message || ELKPI_UnknownError);
      this.isLoading = false;
      this.showError(this.errorMessage);
    }
  }

  connectedCallback() {
    this.isLoading = true;
  }

  formatValue(metric) {
    if (!metric || metric.hasError) return ELKPI_NotApplicable;
    const value = metric.currentValue;
    if (value == null) return ELKPI_NotApplicable;

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
    if (!metric || !metric.targetValue) return ELKPI_NotApplicable;
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
        title: ELKPI_ErrorTitle,
        message: message,
        variant: "error",
      })
    );
  }
}
