import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createAssessment from "@salesforce/apex/SECDisclosureController.createAssessment";
import SEC_NewAssessmentTitle from "@salesforce/label/c.SEC_NewAssessmentTitle";
import SEC_IncidentDescriptionLabel from "@salesforce/label/c.SEC_IncidentDescriptionLabel";
import SEC_DiscoveryDateLabel from "@salesforce/label/c.SEC_DiscoveryDateLabel";
import SEC_CreateAssessmentButton from "@salesforce/label/c.SEC_CreateAssessmentButton";
import SEC_AssessmentCreated from "@salesforce/label/c.SEC_AssessmentCreated";
import SEC_AssessmentError from "@salesforce/label/c.SEC_AssessmentError";

export default class SecDisclosureForm extends LightningElement {
  @track formData = {};

  label = {
    SEC_NewAssessmentTitle,
    SEC_IncidentDescriptionLabel,
    SEC_DiscoveryDateLabel,
    SEC_CreateAssessmentButton,
    SEC_AssessmentCreated,
    SEC_AssessmentError,
  };

  handleInputChange(event) {
    const field = event.target.dataset.field;
    this.formData[field] = event.target.value;
  }

  async handleSave() {
    try {
      const assessmentId = await createAssessment({
        incidentDescription: this.formData.description,
        discoveryDate: this.formData.discoveryDate,
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: this.label.SEC_AssessmentCreated,
          variant: "success",
        })
      );
      this.dispatchEvent(new CustomEvent("assessmentcreated", { detail: { assessmentId } }));
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error.body?.message || this.label.SEC_AssessmentError,
          variant: "error",
        })
      );
    }
  }
}
