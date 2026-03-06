import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createIssue from "@salesforce/apex/JiraIntegrationService.createIssue";
import isConfigured from "@salesforce/apex/JiraIntegrationService.isConfigured";
import JIRA_CreateModalHeading from "@salesforce/label/c.JIRA_CreateModalHeading";
import JIRA_CreatingIssue from "@salesforce/label/c.JIRA_CreatingIssue";
import JIRA_NotConfiguredWarning from "@salesforce/label/c.JIRA_NotConfiguredWarning";
import JIRA_CreateDescription from "@salesforce/label/c.JIRA_CreateDescription";
import JIRA_IncludeGapDescription from "@salesforce/label/c.JIRA_IncludeGapDescription";
import JIRA_IncludeFrameworkInfo from "@salesforce/label/c.JIRA_IncludeFrameworkInfo";
import JIRA_IncludeRemediationPlan from "@salesforce/label/c.JIRA_IncludeRemediationPlan";
import JIRA_IncludeSalesforceLink from "@salesforce/label/c.JIRA_IncludeSalesforceLink";
import JIRA_PriorityLabel from "@salesforce/label/c.JIRA_PriorityLabel";
import JIRA_PriorityPlaceholder from "@salesforce/label/c.JIRA_PriorityPlaceholder";
import JIRA_PriorityHint from "@salesforce/label/c.JIRA_PriorityHint";
import JIRA_CancelButton from "@salesforce/label/c.JIRA_CancelButton";
import JIRA_CreateIssueButton from "@salesforce/label/c.JIRA_CreateIssueButton";
import JIRA_NoRecordId from "@salesforce/label/c.JIRA_NoRecordId";
import JIRA_UnexpectedError from "@salesforce/label/c.JIRA_UnexpectedError";

export default class JiraCreateModal extends LightningElement {
  @api recordId; // Compliance_Gap__c Id

  isOpen = false;
  isLoading = false;
  isJiraConfigured = false;
  selectedPriority = "";
  error = null;

  label = {
    JIRA_CreateModalHeading,
    JIRA_CreatingIssue,
    JIRA_NotConfiguredWarning,
    JIRA_CreateDescription,
    JIRA_IncludeGapDescription,
    JIRA_IncludeFrameworkInfo,
    JIRA_IncludeRemediationPlan,
    JIRA_IncludeSalesforceLink,
    JIRA_PriorityLabel,
    JIRA_PriorityPlaceholder,
    JIRA_PriorityHint,
    JIRA_CancelButton,
    JIRA_CreateIssueButton,
    JIRA_NoRecordId,
    JIRA_UnexpectedError,
  };

  get priorityOptions() {
    return [
      { label: "Highest", value: "Highest" },
      { label: "High", value: "High" },
      { label: "Medium", value: "Medium" },
      { label: "Low", value: "Low" },
      { label: "Lowest", value: "Lowest" },
    ];
  }

  get isCreateDisabled() {
    return this.isLoading || !this.isJiraConfigured;
  }

  get isNotConfigured() {
    return !this.isJiraConfigured;
  }

  connectedCallback() {
    this.checkConfiguration();
  }

  async checkConfiguration() {
    try {
      this.isJiraConfigured = await isConfigured();
    } catch {
      this.isJiraConfigured = false;
    }
  }

  @api
  open() {
    this.isOpen = true;
    this.error = null;
    this.selectedPriority = "";
    this.checkConfiguration();
  }

  @api
  close() {
    this.isOpen = false;
    this.error = null;
  }

  handlePriorityChange(event) {
    this.selectedPriority = event.detail.value;
  }

  handleModalKeydown(event) {
    if (event.key === "Escape") {
      this.close();
    }
  }

  handleClose() {
    this.close();
  }

  async handleCreate() {
    if (!this.recordId) {
      this.showToast("Error", this.label.JIRA_NoRecordId, "error");
      return;
    }

    this.isLoading = true;
    this.error = null;

    try {
      const result = await createIssue({
        gapId: this.recordId,
        priority: this.selectedPriority || null,
      });

      this.showToast("Success", `Jira issue ${result.key} created successfully`, "success");

      // Dispatch event to notify parent
      this.dispatchEvent(
        new CustomEvent("issuecreated", {
          detail: {
            issueKey: result.key,
            issueUrl: result.url,
          },
        })
      );

      this.close();
    } catch (err) {
      this.error = this.getErrorMessage(err);
      this.showToast("Error", this.error, "error");
    } finally {
      this.isLoading = false;
    }
  }

  getErrorMessage(error) {
    if (error?.body?.message) return error.body.message;
    if (error?.message) return error.message;
    return this.label.JIRA_UnexpectedError;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
