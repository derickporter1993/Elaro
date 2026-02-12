import { LightningElement, api } from "lwc";
import HC_FilterAll from "@salesforce/label/c.HC_FilterAll";
import HC_FilterHigh from "@salesforce/label/c.HC_FilterHigh";
import HC_FilterMedium from "@salesforce/label/c.HC_FilterMedium";
import HC_FilterLow from "@salesforce/label/c.HC_FilterLow";

const COLUMNS = [
  {
    label: "Severity",
    fieldName: "severity",
    type: "text",
    sortable: true,
    initialWidth: 120,
  },
  {
    label: "Category",
    fieldName: "category",
    type: "text",
    sortable: true,
    initialWidth: 160,
  },
  { label: "Setting", fieldName: "setting", type: "text", sortable: true },
  {
    label: "Current Value",
    fieldName: "currentValue",
    type: "text",
    sortable: true,
  },
  {
    label: "Recommended Value",
    fieldName: "recommendedValue",
    type: "text",
    sortable: true,
  },
];

export default class HealthCheckRiskTable extends LightningElement {
  label = { HC_FilterAll, HC_FilterHigh, HC_FilterMedium, HC_FilterLow };

  @api findings = [];

  columns = COLUMNS;
  activeFilter = "ALL";
  sortedBy = "severity";
  sortDirection = "asc";

  get filterOptions() {
    return [
      { label: this.label.HC_FilterAll, value: "ALL" },
      { label: this.label.HC_FilterHigh, value: "HIGH_RISK" },
      { label: this.label.HC_FilterMedium, value: "MEDIUM_RISK" },
      { label: this.label.HC_FilterLow, value: "LOW_RISK" },
    ];
  }

  get filteredFindings() {
    if (!this.findings) return [];
    if (this.activeFilter === "ALL") return this.findings;
    return this.findings.filter((f) => f.severity === this.activeFilter);
  }

  get hasFindings() {
    return this.filteredFindings.length > 0;
  }

  handleFilterChange(event) {
    this.activeFilter = event.detail.value;
  }

  handleSort(event) {
    this.sortedBy = event.detail.fieldName;
    this.sortDirection = event.detail.sortDirection;
  }
}
