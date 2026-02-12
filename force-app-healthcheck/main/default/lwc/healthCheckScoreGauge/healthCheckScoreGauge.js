import { LightningElement, api } from "lwc";
import HC_ScoreExcellent from "@salesforce/label/c.HC_ScoreExcellent";
import HC_ScoreGood from "@salesforce/label/c.HC_ScoreGood";
import HC_ScoreNeedsWork from "@salesforce/label/c.HC_ScoreNeedsWork";
import HC_ScoreCritical from "@salesforce/label/c.HC_ScoreCritical";

const CIRCUMFERENCE = 2 * Math.PI * 54;
const COLOR_RED = "#D32F2F";
const COLOR_AMBER = "#F57C00";
const COLOR_GREEN = "#2E7D32";

export default class HealthCheckScoreGauge extends LightningElement {
  label = { HC_ScoreExcellent, HC_ScoreGood, HC_ScoreNeedsWork, HC_ScoreCritical };

  @api score = 0;

  get normalizedScore() {
    return Math.max(0, Math.min(100, this.score || 0));
  }

  get strokeDashoffset() {
    const progress = this.normalizedScore / 100;
    return CIRCUMFERENCE * (1 - progress);
  }

  get strokeDasharray() {
    return CIRCUMFERENCE;
  }

  get gaugeColor() {
    if (this.normalizedScore <= 40) return COLOR_RED;
    if (this.normalizedScore <= 70) return COLOR_AMBER;
    return COLOR_GREEN;
  }

  get scoreLabel() {
    if (this.normalizedScore >= 71) return this.label.HC_ScoreExcellent;
    if (this.normalizedScore >= 41) return this.label.HC_ScoreNeedsWork;
    return this.label.HC_ScoreCritical;
  }

  get ariaLabel() {
    return `Security score: ${this.normalizedScore} out of 100 - ${this.scoreLabel}`;
  }
}
