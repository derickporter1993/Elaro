import { LightningElement, wire } from "lwc";
import getDashboardSummary from "@salesforce/apex/ComplianceDashboardController.getDashboardSummary";
import CD_CardTitle from "@salesforce/label/c.CD_CardTitle";
import CD_LoadingAlt from "@salesforce/label/c.CD_LoadingAlt";
import CD_ErrorLoading from "@salesforce/label/c.CD_ErrorLoading";
import CD_RecentEvidence from "@salesforce/label/c.CD_RecentEvidence";
import CD_UnknownError from "@salesforce/label/c.ELKPI_UnknownError";

export default class ComplianceDashboard extends LightningElement {
  dashboardData;
  error;
  loading = true;

  label = {
    CD_CardTitle,
    CD_LoadingAlt,
    CD_ErrorLoading,
    CD_RecentEvidence,
  };

  @wire(getDashboardSummary)
  wiredDashboard({ error, data }) {
    this.loading = false;
    if (data) {
      this.dashboardData = data;
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.dashboardData = undefined;
    }
  }

  get hasData() {
    return this.dashboardData && this.dashboardData.frameworks;
  }

  get frameworks() {
    return this.hasData ? this.dashboardData.frameworks : [];
  }

  get recentGaps() {
    return this.hasData && this.dashboardData.recentGaps ? this.dashboardData.recentGaps : [];
  }

  get recentEvidence() {
    return this.hasData && this.dashboardData.recentEvidence
      ? this.dashboardData.recentEvidence
      : [];
  }

  get errorMessage() {
    if (!this.error) return "";
    return this.error?.body?.message || this.error?.message || CD_UnknownError;
  }
}
