import { LightningElement, api } from "lwc";
import HC_MfaAdoption from "@salesforce/label/c.HC_MfaAdoption";
import HC_UsersOnMfa from "@salesforce/label/c.HC_UsersOnMfa";

const CIRCUMFERENCE = 2 * Math.PI * 54;
const COLOR_RED = "#D32F2F";
const COLOR_AMBER = "#F57C00";
const COLOR_GREEN = "#2E7D32";

export default class HealthCheckMfaIndicator extends LightningElement {
  label = { HC_MfaAdoption, HC_UsersOnMfa };

  @api mfaPercentage = 0;
  @api totalUsers = 0;
  @api mfaUsers = 0;

  get normalizedPercentage() {
    return Math.max(0, Math.min(100, this.mfaPercentage || 0));
  }

  get strokeDashoffset() {
    const progress = this.normalizedPercentage / 100;
    return CIRCUMFERENCE * (1 - progress);
  }

  get strokeDasharray() {
    return CIRCUMFERENCE;
  }

  get ringColor() {
    if (this.normalizedPercentage <= 40) return COLOR_RED;
    if (this.normalizedPercentage <= 70) return COLOR_AMBER;
    return COLOR_GREEN;
  }

  get usersLabel() {
    return this.label.HC_UsersOnMfa.replace("{0}", String(this.mfaUsers || 0)).replace(
      "{1}",
      String(this.totalUsers || 0)
    );
  }

  get ariaLabel() {
    return `MFA adoption: ${this.normalizedPercentage}%. ${this.usersLabel}`;
  }
}
