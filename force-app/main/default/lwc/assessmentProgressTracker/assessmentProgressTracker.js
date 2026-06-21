import { LightningElement, api } from "lwc";
import AW_PercentComplete from "@salesforce/label/c.AW_PercentComplete";
import AW_StagePrefix from "@salesforce/label/c.AW_StagePrefix";
import AW_StageCompleted from "@salesforce/label/c.AW_StageCompleted";
import AW_StageStatusCompleted from "@salesforce/label/c.AW_StageStatusCompleted";
import AW_StageStatusCurrent from "@salesforce/label/c.AW_StageStatusCurrent";
import AW_StageStatusUpcoming from "@salesforce/label/c.AW_StageStatusUpcoming";

export default class AssessmentProgressTracker extends LightningElement {
  @api stages = [];
  @api currentStage = 1;
  @api currentStep = 1;
  @api percentComplete = 0;

  label = {
    AW_PercentComplete,
    AW_StagePrefix,
    AW_StageCompleted,
  };

  get progressLabel() {
    // AW_PercentComplete value is "{0}% Complete"
    return this.label.AW_PercentComplete.replace("{0}", Math.round(this.percentComplete));
  }

  get progressVariant() {
    if (this.percentComplete >= 100) return "expired";
    if (this.percentComplete >= 50) return "warning";
    return "base";
  }

  get stageItems() {
    return (this.stages || []).map((stage) => {
      const isCurrent = stage.stageOrder === this.currentStage;
      const isComplete = stage.isComplete === true;
      const isPast = stage.stageOrder < this.currentStage;

      let statusClass = "slds-progress__item";
      if (isComplete || isPast) {
        statusClass += " slds-is-completed";
      } else if (isCurrent) {
        statusClass += " slds-is-active";
      }

      // AW_StagePrefix value is "Stage {0}"
      const stageLabel = this.label.AW_StagePrefix.replace("{0}", stage.stageOrder);
      let statusSuffix;
      if (isComplete || isPast) {
        statusSuffix = AW_StageStatusCompleted;
      } else if (isCurrent) {
        statusSuffix = AW_StageStatusCurrent;
      } else {
        statusSuffix = AW_StageStatusUpcoming;
      }

      return {
        ...stage,
        key: `stage-${stage.stageOrder}`,
        statusClass,
        isCurrent,
        isComplete: isComplete || isPast,
        stageLabel,
        stepCount: stage.steps ? stage.steps.length : 0,
        ariaLabel: `${stageLabel} ${statusSuffix}`,
      };
    });
  }
}
