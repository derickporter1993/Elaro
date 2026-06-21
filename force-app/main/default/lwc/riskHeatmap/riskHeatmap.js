import { LightningElement, api } from "lwc";
import RH_CardTitle from "@salesforce/label/c.RH_CardTitle";
import RH_GridAria from "@salesforce/label/c.RH_GridAria";
import RH_ScorePrefix from "@salesforce/label/c.RH_ScorePrefix";
import RH_NoData from "@salesforce/label/c.RH_NoData";
import RH_RiskItemAria from "@salesforce/label/c.RH_RiskItemAria";

export default class RiskHeatmap extends LightningElement {
  @api risks = [];

  label = {
    RH_CardTitle,
    RH_GridAria,
    RH_ScorePrefix,
    RH_NoData,
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
      // RH_RiskItemAria value is "Risk for {0}: {1}, Score {2}"
      const ariaLabel = RH_RiskItemAria.replace("{0}", risk.framework ?? "")
        .replace("{1}", risk.severity ?? "")
        .replace("{2}", risk.score ?? "");
      return {
        ...risk,
        combinedClass: `slds-box slds-text-align_center ${severityClass}`,
        ariaLabel,
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
