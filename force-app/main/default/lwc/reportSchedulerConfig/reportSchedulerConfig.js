import { LightningElement, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getScheduledReports from "@salesforce/apex/ComplianceReportScheduler.getScheduledReports";
import scheduleReport from "@salesforce/apex/ComplianceReportScheduler.scheduleReport";
import cancelScheduledReport from "@salesforce/apex/ComplianceReportScheduler.cancelScheduledReport";
import sendTestReport from "@salesforce/apex/ComplianceReportScheduler.sendTestReport";

export default class ReportSchedulerConfig extends LightningElement {
  scheduledReports = [];
  isLoading = false;
  showNewReportModal = false;
  showConfirmModal = false;
  confirmMessage = "";
  confirmAction = null;

  // New report form fields
  newReportFrequency = "WEEKLY";
  newReportFramework = "ALL";
  newReportRecipients = "";

  // Wire result for refresh
  wiredReportsResult;

  // Frequency options
  get frequencyOptions() {
    return [
      { label: "Daily (8 AM)", value: "DAILY" },
      { label: "Weekly (Monday 8 AM)", value: "WEEKLY" },
      { label: "Monthly (1st of month 8 AM)", value: "MONTHLY" },
    ];
  }

  // Framework options
  get frameworkOptions() {
    return [
      { label: "All Frameworks", value: "ALL" },
      { label: "HIPAA", value: "HIPAA" },
      { label: "SOC 2", value: "SOC2" },
      { label: "NIST", value: "NIST" },
      { label: "FedRAMP", value: "FedRAMP" },
      { label: "GDPR", value: "GDPR" },
      { label: "SOX", value: "SOX" },
      { label: "PCI-DSS", value: "PCI_DSS" },
      { label: "CCPA", value: "CCPA" },
      { label: "GLBA", value: "GLBA" },
      { label: "ISO 27001", value: "ISO27001" },
    ];
  }

  // Table columns for scheduled reports
  get columns() {
    return [
      { label: "Report Name", fieldName: "name", type: "text" },
      { label: "Frequency", fieldName: "frequency", type: "text" },
      { label: "Framework", fieldName: "framework", type: "text" },
      { label: "Next Run", fieldName: "nextRun", type: "date" },
      { label: "Status", fieldName: "status", type: "text" },
      {
        type: "action",
        typeAttributes: {
          rowActions: [
            { label: "Cancel Report", name: "cancel" },
            { label: "Send Test Now", name: "test" },
          ],
        },
      },
    ];
  }

  get hasScheduledReports() {
    return this.scheduledReports && this.scheduledReports.length > 0;
  }

  get notLoading() {
    return !this.isLoading;
  }

  @wire(getScheduledReports)
  wiredReports(result) {
    this.wiredReportsResult = result;
    if (result.data) {
      this.scheduledReports = result.data.map((report) => ({
        ...report,
        nextRun: report.nextRun ? new Date(report.nextRun) : null,
      }));
    } else if (result.error) {
      this.showToast("Error", this.getErrorMessage(result.error), "error");
    }
  }

  handleNewReport() {
    this.showNewReportModal = true;
    this.newReportFrequency = "WEEKLY";
    this.newReportFramework = "ALL";
    this.newReportRecipients = "";
  }

  handleModalKeydown(event) {
    if (event.key === "Escape") {
      this.handleCloseModal();
    }
  }

  handleConfirmModalKeydown(event) {
    if (event.key === "Escape") {
      this.handleCloseConfirm();
    }
  }

  handleCloseModal() {
    this.showNewReportModal = false;
  }

  handleFrequencyChange(event) {
    this.newReportFrequency = event.detail.value;
  }

  handleFrameworkChange(event) {
    this.newReportFramework = event.detail.value;
  }

  handleRecipientsChange(event) {
    this.newReportRecipients = event.target.value;
  }

  async handleScheduleReport() {
    // Validate recipients
    const recipients = this.parseRecipients(this.newReportRecipients);
    if (recipients.length === 0) {
      this.showToast("Validation Error", "Please enter at least one valid email address", "error");
      return;
    }

    this.isLoading = true;
    this.showNewReportModal = false;

    try {
      await scheduleReport({
        frequencyStr: this.newReportFrequency,
        recipientEmails: recipients,
        frameworkFilter: this.newReportFramework,
      });

      this.showToast("Success", "Compliance report scheduled successfully", "success");
      await refreshApex(this.wiredReportsResult);
    } catch (error) {
      this.showToast("Error", this.getErrorMessage(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  handleRowAction(event) {
    const action = event.detail.action;
    const row = event.detail.row;

    switch (action.name) {
      case "cancel":
        this.confirmMessage = `Are you sure you want to cancel the scheduled report "${row.name}"?`;
        this.confirmAction = () => this.cancelReport(row.jobId);
        this.showConfirmModal = true;
        break;
      case "test":
        this.sendTest(row.framework);
        break;
      default:
        break;
    }
  }

  handleCloseConfirm() {
    this.showConfirmModal = false;
    this.confirmAction = null;
  }

  handleConfirmAction() {
    if (this.confirmAction) {
      this.confirmAction();
    }
    this.showConfirmModal = false;
    this.confirmAction = null;
  }

  async cancelReport(jobId) {
    this.isLoading = true;

    try {
      await cancelScheduledReport({ jobId });
      this.showToast("Success", "Scheduled report cancelled", "success");
      await refreshApex(this.wiredReportsResult);
    } catch (error) {
      this.showToast("Error", this.getErrorMessage(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  async sendTest(framework) {
    this.isLoading = true;

    try {
      await sendTestReport({
        frameworkFilter: framework,
        recipientEmails: [],
      });
      this.showToast("Success", "Test report sent to your email", "success");
    } catch (error) {
      this.showToast("Error", this.getErrorMessage(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  async handleRefresh() {
    this.isLoading = true;
    try {
      await refreshApex(this.wiredReportsResult);
    } finally {
      this.isLoading = false;
    }
  }

  parseRecipients(recipientString) {
    if (!recipientString) return [];
    return recipientString
      .split(/[,;\n]/)
      .map((email) => email.trim())
      .filter((email) => this.isValidEmail(email));
  }

  isValidEmail(email) {
    const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    return emailRegex.test(email);
  }

  getErrorMessage(error) {
    if (error?.body?.message) return error.body.message;
    if (error?.message) return error.message;
    return "An unexpected error occurred";
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
