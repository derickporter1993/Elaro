import { LightningElement, api, wire } from "lwc";
import getFrameworkDetails from "@salesforce/apex/ComplianceScoreCardController.getFrameworkDetails";
import { NavigationMixin } from "lightning/navigation";
import CSC_ComplianceScore from "@salesforce/label/c.CSC_ComplianceScore";
import CSC_LoadingDetails from "@salesforce/label/c.CSC_LoadingDetails";
import CSC_PoliciesCompliant from "@salesforce/label/c.CSC_PoliciesCompliant";
import CSC_Gaps from "@salesforce/label/c.CSC_Gaps";
import CSC_FrameworkMappings from "@salesforce/label/c.CSC_FrameworkMappings";
import CSC_EvidenceItems from "@salesforce/label/c.CSC_EvidenceItems";
import CSC_Requirements from "@salesforce/label/c.CSC_Requirements";
import CSC_LatestAuditPackage from "@salesforce/label/c.CSC_LatestAuditPackage";
import CSC_Status from "@salesforce/label/c.CSC_Status";
import CSC_Period from "@salesforce/label/c.CSC_Period";
import CSC_ViewPackage from "@salesforce/label/c.CSC_ViewPackage";
import CSC_FailedToLoadDetails from "@salesforce/label/c.CSC_FailedToLoadDetails";

export default class ComplianceScoreCard extends NavigationMixin(LightningElement) {
  @api framework;
  frameworkDetails = null;
  isLoadingDetails = false;
  hasError = false;
  errorMessage = "";

  label = {
    CSC_ComplianceScore,
    CSC_LoadingDetails,
    CSC_PoliciesCompliant,
    CSC_Gaps,
    CSC_FrameworkMappings,
    CSC_EvidenceItems,
    CSC_Requirements,
    CSC_LatestAuditPackage,
    CSC_Status,
    CSC_Period,
    CSC_ViewPackage,
  };

  get frameworkKey() {
    return this.framework?.framework || this.framework?.key || null;
  }

  @wire(getFrameworkDetails, { framework: "$frameworkKey" })
  wiredFrameworkDetails({ error, data }) {
    if (data) {
      this.frameworkDetails = data;
      this.isLoadingDetails = false;
      this.hasError = false;
      this.errorMessage = "";
    } else if (error) {
      // Error logged for debugging - framework details are optional
      this.isLoadingDetails = false;
      this.hasError = true;
      this.errorMessage = error?.body?.message || error?.message || CSC_FailedToLoadDetails;
    } else {
      this.isLoadingDetails = true;
      this.hasError = false;
      this.errorMessage = "";
    }
  }

  get scoreClass() {
    if (this.framework && this.framework.score >= 90) {
      return "score-high";
    }
    if (this.framework && this.framework.score >= 70) {
      return "score-medium";
    }
    return "score-low";
  }

  get statusIcon() {
    if (this.framework && this.framework.status === "COMPLIANT") {
      return "utility:success";
    }
    if (this.framework && this.framework.status === "PARTIALLY_COMPLIANT") {
      return "utility:warning";
    }
    return "utility:error";
  }

  get hasFrameworkDetails() {
    return this.frameworkDetails !== null;
  }

  get mappingCount() {
    return this.frameworkDetails?.mappingCount ?? 0;
  }

  get evidenceCount() {
    return this.frameworkDetails?.evidenceCount ?? 0;
  }

  get requirementCount() {
    return this.frameworkDetails?.requirementCount ?? 0;
  }

  get latestAuditPackage() {
    return this.frameworkDetails?.latestAuditPackage;
  }

  get hasLatestPackage() {
    return this.latestAuditPackage !== null && this.latestAuditPackage !== undefined;
  }

  get formattedLatestPackage() {
    if (!this.latestAuditPackage) return null;
    const status = this.latestAuditPackage.status || "";
    return {
      ...this.latestAuditPackage,
      formattedPeriodStart: this.formatDate(this.latestAuditPackage.periodStart),
      formattedPeriodEnd: this.formatDate(this.latestAuditPackage.periodEnd),
      statusClass: `status-${status.toLowerCase()}`,
    };
  }

  formatDate(dateValue) {
    if (!dateValue) return "";
    const date = new Date(dateValue);
    return date.toLocaleDateString("en-US", { year: "numeric", month: "short", day: "numeric" });
  }

  handleViewAuditPackage(event) {
    const packageId = event.currentTarget.dataset.packageId;
    if (packageId) {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: packageId,
          actionName: "view",
        },
      });
    }
  }
}
