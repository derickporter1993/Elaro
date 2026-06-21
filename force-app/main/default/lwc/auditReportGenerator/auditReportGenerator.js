import { LightningElement } from "lwc";
import generateAuditReport from "@salesforce/apex/AuditReportController.generateAuditReport";
import exportReportAsPDF from "@salesforce/apex/AuditReportController.exportReportAsPDF";
import ARG_CardTitle from "@salesforce/label/c.ARG_CardTitle";
import ARG_GeneratingAlt from "@salesforce/label/c.ARG_GeneratingAlt";
import ARG_Framework from "@salesforce/label/c.ARG_Framework";
import ARG_StartDate from "@salesforce/label/c.ARG_StartDate";
import ARG_EndDate from "@salesforce/label/c.ARG_EndDate";
import ARG_GenerateReport from "@salesforce/label/c.ARG_GenerateReport";
import ARG_ExportPDF from "@salesforce/label/c.ARG_ExportPDF";
import ARG_ReportSummary from "@salesforce/label/c.ARG_ReportSummary";
import ARG_OverallScore from "@salesforce/label/c.ARG_OverallScore";
import ARG_Status from "@salesforce/label/c.ARG_Status";
import ARG_TotalGaps from "@salesforce/label/c.ARG_TotalGaps";
import ARG_OpenGaps from "@salesforce/label/c.ARG_OpenGaps";
import ARG_TotalEvidence from "@salesforce/label/c.ARG_TotalEvidence";
import ARG_ValidationMissing from "@salesforce/label/c.ARG_ValidationMissing";
import ARG_GenerateFirst from "@salesforce/label/c.ARG_GenerateFirst";
import ARG_GenericError from "@salesforce/label/c.ARG_GenericError";

export default class AuditReportGenerator extends LightningElement {
  selectedFramework = "SOX";
  startDate;
  endDate;
  reportData;
  loading = false;
  error;

  label = {
    ARG_CardTitle,
    ARG_GeneratingAlt,
    ARG_Framework,
    ARG_StartDate,
    ARG_EndDate,
    ARG_GenerateReport,
    ARG_ExportPDF,
    ARG_ReportSummary,
    ARG_OverallScore,
    ARG_Status,
    ARG_TotalGaps,
    ARG_OpenGaps,
    ARG_TotalEvidence,
  };

  get isLoading() {
    return this.loading;
  }

  get hasError() {
    return !!this.error;
  }

  get errorMessage() {
    if (!this.error) return "";
    return this.error?.body?.message || this.error?.message || this.error;
  }

  get notLoading() {
    return !this.loading;
  }

  frameworks = [
    { label: "SOX", value: "SOX" },
    { label: "SOC 2", value: "SOC2" },
    { label: "HIPAA", value: "HIPAA" },
    { label: "GDPR", value: "GDPR" },
    { label: "CCPA", value: "CCPA" },
    { label: "GLBA", value: "GLBA" },
    { label: "NIST 800-53", value: "NIST" },
    { label: "ISO 27001", value: "ISO27001" },
    { label: "PCI-DSS", value: "PCI_DSS" },
  ];

  handleFrameworkChange(event) {
    this.selectedFramework = event.detail.value;
  }

  handleStartDateChange(event) {
    this.startDate = event.detail.value;
  }

  handleEndDateChange(event) {
    this.endDate = event.detail.value;
  }

  handleGenerateReport() {
    if (!this.selectedFramework || !this.startDate || !this.endDate) {
      this.error = ARG_ValidationMissing;
      return;
    }

    this.loading = true;
    this.error = undefined;

    generateAuditReport({
      framework: this.selectedFramework,
      startDate: this.startDate,
      endDate: this.endDate,
    })
      .then((result) => {
        this.reportData = result;
        this.loading = false;
      })
      .catch((error) => {
        this.error = error?.body?.message || error?.message || ARG_GenericError;
        this.loading = false;
      });
  }

  handleExportPDF() {
    if (!this.reportData) {
      this.error = ARG_GenerateFirst;
      return;
    }

    this.loading = true;
    exportReportAsPDF({ report: this.reportData })
      .then((contentDocumentId) => {
        // Navigate to file
        window.open("/lightning/r/ContentDocument/" + contentDocumentId + "/view", "_blank");
        this.loading = false;
      })
      .catch((error) => {
        this.error = error?.body?.message || error?.message || ARG_GenericError;
        this.loading = false;
      });
  }
}
