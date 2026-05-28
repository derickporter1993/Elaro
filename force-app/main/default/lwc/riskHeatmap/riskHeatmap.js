import { LightningElement, api } from "lwc";

import CardTitle from "@salesforce/label/c.RHM_CardTitle";
import HeatmapAriaLabel from "@salesforce/label/c.RHM_HeatmapAriaLabel";
import ScorePrefix from "@salesforce/label/c.RHM_ScorePrefix";
import NoRiskData from "@salesforce/label/c.RHM_NoRiskData";
import RiskCellAriaLabel from "@salesforce/label/c.RHM_RiskCellAriaLabel";

export default class RiskHeatmap extends LightningElement {
  @api risks = [];

  label = {
    CardTitle,
    HeatmapAriaLabel,
    ScorePrefix,
    NoRiskData,
  };

  get riskMatrix() {
    // Organize risks by severity and framework
    let matrix = {};

    if (this.risks && this.risks.length > 0) {
      for (let risk of this.risks) {
        let key = risk.framework + "_" + risk.severity;
        if (!matrix[key]) {
          matrix[key] = 0;
        }
        matrix[key]++;
      }
    }

    return matrix;
  }

  get risksWithClasses() {
    if (!this.risks || this.risks.length === 0) {
      return [];
    }
    return this.risks.map((risk) => {
      let severityClass = "risk-low";
      if (risk.severity === "CRITICAL") {
        severityClass = "risk-critical";
      } else if (risk.severity === "HIGH") {
        severityClass = "risk-high";
      } else if (risk.severity === "MEDIUM") {
        severityClass = "risk-medium";
      }
      return {
        ...risk,
        combinedClass: `slds-box slds-text-align_center ${severityClass}`,
        scoreText: `${ScorePrefix} ${risk.score}`,
        ariaLabel: RiskCellAriaLabel.replace("{0}", risk.framework)
          .replace("{1}", risk.severity)
          .replace("{2}", risk.score),
      };
    });
  }

  get hasRisks() {
    return this.risks && this.risks.length > 0;
  }

  get noRisks() {
    return !this.hasRisks;
  }
}
