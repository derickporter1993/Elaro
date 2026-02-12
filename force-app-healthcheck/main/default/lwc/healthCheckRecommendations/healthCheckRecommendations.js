import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import HC_GoToSetup from "@salesforce/label/c.HC_GoToSetup";

export default class HealthCheckRecommendations extends NavigationMixin(LightningElement) {
  label = { HC_GoToSetup };

  @api recommendations = [];

  get hasRecommendations() {
    return this.recommendations && this.recommendations.length > 0;
  }

  get indexedRecommendations() {
    return (this.recommendations || []).map((rec, idx) => ({
      ...rec,
      key: `rec-${idx}`,
      priorityBadge: this.getPriorityBadge(rec.priority),
      priorityClass: this.getPriorityClass(rec.priority),
    }));
  }

  getPriorityBadge(priority) {
    if (priority === 1) return "Critical";
    if (priority === 2) return "High";
    return "Medium";
  }

  getPriorityClass(priority) {
    if (priority === 1) return "slds-badge slds-badge_inverse";
    if (priority === 2) return "slds-badge";
    return "slds-badge slds-badge_lightest";
  }

  handleGoToSetup(event) {
    const setupPath = event.currentTarget.dataset.path;
    if (setupPath) {
      this[NavigationMixin.Navigate]({
        type: "standard__webPage",
        attributes: {
          url: "/lightning/setup/" + setupPath,
        },
      });
    }
  }
}
