import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getDashboardData from "@salesforce/apex/VendorRiskController.getDashboardData";
import getFilteredVendors from "@salesforce/apex/VendorRiskController.getFilteredVendors";
import refreshRiskScore from "@salesforce/apex/VendorRiskController.refreshRiskScore";
import getOverdueVendors from "@salesforce/apex/VendorRiskController.getOverdueVendors";

import VR_Title from "@salesforce/label/c.VR_Title";
import VR_Loading from "@salesforce/label/c.VR_Loading";
import VR_Error from "@salesforce/label/c.VR_Error";
import VR_NoData from "@salesforce/label/c.VR_NoData";
import VR_TotalVendors from "@salesforce/label/c.VR_TotalVendors";
import VR_ActiveVendors from "@salesforce/label/c.VR_ActiveVendors";
import VR_AverageRisk from "@salesforce/label/c.VR_AverageRisk";
import VR_OverdueAssessments from "@salesforce/label/c.VR_OverdueAssessments";
import VR_HighRisk from "@salesforce/label/c.VR_HighRisk";
import VR_FilterByStatus from "@salesforce/label/c.VR_FilterByStatus";
import VR_FilterByType from "@salesforce/label/c.VR_FilterByType";
import VR_AllStatuses from "@salesforce/label/c.VR_AllStatuses";
import VR_AllTypes from "@salesforce/label/c.VR_AllTypes";

const STATUS_OPTIONS = [
  { label: "All Statuses", value: "" },
  { label: "Active", value: "ACTIVE" },
  { label: "Under Review", value: "UNDER_REVIEW" },
  { label: "Suspended", value: "SUSPENDED" },
  { label: "Terminated", value: "TERMINATED" },
];

const TYPE_OPTIONS = [
  { label: "All Types", value: "" },
  { label: "Cloud Service", value: "CLOUD_SERVICE" },
  { label: "Integration", value: "INTEGRATION" },
  { label: "Data Processor", value: "DATA_PROCESSOR" },
  { label: "Consulting", value: "CONSULTING" },
  { label: "Other", value: "OTHER" },
];

const COLUMNS = [
  { label: "Vendor Name", fieldName: "Vendor_Name__c", type: "text", sortable: true },
  { label: "Type", fieldName: "Vendor_Type__c", type: "text", sortable: true },
  {
    label: "Risk Score",
    fieldName: "Risk_Score__c",
    type: "number",
    sortable: true,
    cellAttributes: { class: { fieldName: "riskClass" } },
  },
  { label: "Status", fieldName: "Status__c", type: "text", sortable: true },
  { label: "Last Assessment", fieldName: "Last_Assessment_Date__c", type: "date", sortable: true },
  { label: "Next Assessment", fieldName: "Next_Assessment_Date__c", type: "date", sortable: true },
  {
    label: "DPA",
    fieldName: "Data_Processing_Agreement__c",
    type: "boolean",
  },
  {
    type: "action",
    typeAttributes: {
      rowActions: [{ label: "Refresh Risk Score", name: "refresh_score" }],
    },
  },
];

export default class VendorRiskDashboard extends LightningElement {
  label = {
    VR_Title,
    VR_Loading,
    VR_Error,
    VR_NoData,
    VR_TotalVendors,
    VR_ActiveVendors,
    VR_AverageRisk,
    VR_OverdueAssessments,
    VR_HighRisk,
    VR_FilterByStatus,
    VR_FilterByType,
    VR_AllStatuses,
    VR_AllTypes,
  };

  statusOptions = STATUS_OPTIONS;
  typeOptions = TYPE_OPTIONS;
  columns = COLUMNS;

  @track vendors = [];
  @track summary = {};
  isLoading = true;
  error = null;
  statusFilter = "";
  typeFilter = "";

  get hasVendors() {
    return this.vendors && this.vendors.length > 0;
  }

  get isEmpty() {
    return !this.isLoading && !this.error && !this.hasVendors;
  }

  get riskScoreClass() {
    const score = this.summary?.averageRiskScore ?? 0;
    if (score >= 7) return "risk-critical";
    if (score >= 4) return "risk-warning";
    return "risk-low";
  }

  connectedCallback() {
    this.loadDashboardData();
  }

  async loadDashboardData() {
    this.isLoading = true;
    this.error = null;
    try {
      const data = await getDashboardData();
      this.summary = data.summary ?? {};
      this.vendors = this.enrichVendorData(data.vendors ?? []);
    } catch (err) {
      this.error = err?.body?.message ?? this.label.VR_Error;
    } finally {
      this.isLoading = false;
    }
  }

  enrichVendorData(vendors) {
    return vendors.map((vendor) => ({
      ...vendor,
      riskClass: this.getRiskClass(vendor.Risk_Score__c),
    }));
  }

  getRiskClass(score) {
    if (score == null) return "";
    if (score >= 7) return "slds-text-color_error";
    if (score >= 4) return "slds-text-color_warning";
    return "slds-text-color_success";
  }

  async handleStatusChange(event) {
    this.statusFilter = event.detail.value;
    await this.applyFilters();
  }

  async handleTypeChange(event) {
    this.typeFilter = event.detail.value;
    await this.applyFilters();
  }

  async applyFilters() {
    this.isLoading = true;
    this.error = null;
    try {
      const result = await getFilteredVendors({
        statusFilter: this.statusFilter || null,
        typeFilter: this.typeFilter || null,
      });
      this.vendors = this.enrichVendorData(result ?? []);
    } catch (err) {
      this.error = err?.body?.message ?? this.label.VR_Error;
    } finally {
      this.isLoading = false;
    }
  }

  async handleRowAction(event) {
    const action = event.detail.action;
    const row = event.detail.row;

    if (action.name === "refresh_score") {
      await this.handleRefreshScore(row.Id);
    }
  }

  async handleRefreshScore(vendorId) {
    this.isLoading = true;
    try {
      await refreshRiskScore({ vendorId });
      await this.loadDashboardData();
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Risk score refreshed successfully.",
          variant: "success",
        })
      );
    } catch (err) {
      this.error = err?.body?.message ?? this.label.VR_Error;
      this.dispatchEvent(
        new ShowToastEvent({
          title: this.label.VR_Error,
          message: err?.body?.message ?? "Unable to refresh risk score.",
          variant: "error",
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  async handleRefresh() {
    await this.loadDashboardData();
  }
}
