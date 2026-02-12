import { LightningElement } from "lwc";
import runFullScan from "@salesforce/apex/HealthCheckController.runFullScan";
import HC_ScanInProgress from "@salesforce/label/c.HC_ScanInProgress";
import HC_ScanComplete from "@salesforce/label/c.HC_ScanComplete";
import HC_ScanFailed from "@salesforce/label/c.HC_ScanFailed";
import HC_NoDataAvailable from "@salesforce/label/c.HC_NoDataAvailable";
import HC_OverallScore from "@salesforce/label/c.HC_OverallScore";

export default class HealthCheckDashboard extends LightningElement {
  label = {
    HC_ScanInProgress,
    HC_ScanComplete,
    HC_ScanFailed,
    HC_NoDataAvailable,
    HC_OverallScore,
  };

  scanResult;
  isLoading = false;
  errorMessage;

  get hasError() {
    return !!this.errorMessage;
  }

  get hasData() {
    return !!this.scanResult;
  }

  get isEmpty() {
    return !this.isLoading && !this.hasError && !this.hasData;
  }

  get overallScore() {
    return this.scanResult?.overallScore ?? 0;
  }

  get findings() {
    return this.scanResult?.findings ?? [];
  }

  get recommendations() {
    return this.scanResult?.recommendations ?? [];
  }

  get mfaPercentage() {
    return this.scanResult?.mfaPercentage ?? 0;
  }

  get totalUsers() {
    return this.scanResult?.totalUsers ?? 0;
  }

  get mfaUsers() {
    return this.scanResult?.mfaUsers ?? 0;
  }

  get findingsCount() {
    return this.findings.length;
  }

  async handleRunScan() {
    this.isLoading = true;
    this.errorMessage = undefined;

    try {
      this.scanResult = await runFullScan();
    } catch (error) {
      this.errorMessage = error?.body?.message || error?.message || this.label.HC_ScanFailed;
      this.scanResult = undefined;
    } finally {
      this.isLoading = false;
    }
  }
}
