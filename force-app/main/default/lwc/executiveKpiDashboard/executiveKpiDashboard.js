import { LightningElement, wire } from "lwc";
import getDashboardSummary from "@salesforce/apex/ComplianceDashboardController.getDashboardSummary";
import EKD_CardTitle from "@salesforce/label/c.EKD_CardTitle";
import EKD_LoadingAlt from "@salesforce/label/c.EKD_LoadingAlt";
import EKD_ErrorLoading from "@salesforce/label/c.EKD_ErrorLoading";
import EKD_OverallScore from "@salesforce/label/c.EKD_OverallScore";
import EKD_TotalGaps from "@salesforce/label/c.EKD_TotalGaps";
import EKD_CriticalGaps from "@salesforce/label/c.EKD_CriticalGaps";
import EKD_CompliantFrameworks from "@salesforce/label/c.EKD_CompliantFrameworks";
import EKD_UnknownError from "@salesforce/label/c.ELKPI_UnknownError";

export default class ExecutiveKpiDashboard extends LightningElement {
  dashboardData;
  error;
  loading = true;

  label = {
    EKD_CardTitle,
    EKD_LoadingAlt,
    EKD_ErrorLoading,
    EKD_OverallScore,
    EKD_TotalGaps,
    EKD_CriticalGaps,
    EKD_CompliantFrameworks,
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

  get overallScore() {
    if (
      !this.dashboardData ||
      !this.dashboardData.frameworks ||
      this.dashboardData.frameworks.length === 0
    ) {
      return 0;
    }

    let totalScore = 0;
    for (let framework of this.dashboardData.frameworks) {
      totalScore += framework.score || 0;
    }
    return (totalScore / this.dashboardData.frameworks.length).toFixed(1);
  }

  get totalGaps() {
    return this.dashboardData && this.dashboardData.recentGaps
      ? this.dashboardData.recentGaps.length
      : 0;
  }

  get criticalGaps() {
    if (!this.dashboardData || !this.dashboardData.recentGaps) return 0;
    return this.dashboardData.recentGaps.filter((gap) => gap.Severity__c === "CRITICAL").length;
  }

  get compliantFrameworks() {
    if (!this.dashboardData || !this.dashboardData.frameworks) return 0;
    return this.dashboardData.frameworks.filter((fw) => fw.status === "COMPLIANT").length;
  }

  get errorMessage() {
    if (!this.error) return "";
    return this.error?.body?.message || this.error?.message || EKD_UnknownError;
  }
}
