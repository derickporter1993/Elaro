import { LightningElement, api } from "lwc";
import HC_CtaTitle from "@salesforce/label/c.HC_CtaTitle";
import HC_CtaBody from "@salesforce/label/c.HC_CtaBody";
import HC_CtaLink from "@salesforce/label/c.HC_CtaLink";

export default class HealthCheckCtaBanner extends LightningElement {
  label = { HC_CtaTitle, HC_CtaBody, HC_CtaLink };

  @api findingsCount = 0;

  get bodyText() {
    return this.label.HC_CtaBody.replace("{0}", String(this.findingsCount || 0));
  }

  handleCtaClick() {
    // Opens AppExchange listing in new tab
    // URL will be updated with actual listing URL before launch
    window.open("https://appexchange.salesforce.com", "_blank");
  }
}
