import { LightningElement, api } from "lwc";
import TREND_CardTitle from "@salesforce/label/c.TREND_CardTitle";
import TREND_LoadingAlt from "@salesforce/label/c.TREND_LoadingAlt";
import TREND_NoData from "@salesforce/label/c.TREND_NoData";
import TREND_ScoreLegend from "@salesforce/label/c.TREND_ScoreLegend";

export default class ComplianceTrendChart extends LightningElement {
  @api framework;
  @api data = [];
  isLoading = false;
  hasError = false;
  errorMessage = "";

  label = {
    TREND_CardTitle,
    TREND_LoadingAlt,
    TREND_NoData,
  };

  get chartData() {
    // Format data for chart library (Chart.js or similar)
    return {
      labels: this.data.map((d) => d.date),
      datasets: [
        {
          label: TREND_ScoreLegend,
          data: this.data.map((d) => d.score),
          borderColor: "rgb(75, 192, 192)",
          backgroundColor: "rgba(75, 192, 192, 0.2)",
        },
      ],
    };
  }

  get hasData() {
    return this.data && this.data.length > 0;
  }

  get isEmpty() {
    return !this.isLoading && !this.hasError && !this.hasData;
  }

  get notLoading() {
    return !this.isLoading;
  }

  get notError() {
    return !this.hasError;
  }
}
