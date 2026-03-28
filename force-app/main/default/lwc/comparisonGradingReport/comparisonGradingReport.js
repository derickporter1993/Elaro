import { LightningElement, track } from "lwc";
import generateReport from "@salesforce/apex/ComparisonGradingEngine.generateReport";
import CGR_Title from "@salesforce/label/c.CGR_Title";
import CGR_Loading from "@salesforce/label/c.CGR_Loading";
import CGR_Error from "@salesforce/label/c.CGR_Error";
import CGR_NoData from "@salesforce/label/c.CGR_NoData";
import CGR_Category from "@salesforce/label/c.CGR_Category";
import CGR_Weight from "@salesforce/label/c.CGR_Weight";
import CGR_Score from "@salesforce/label/c.CGR_Score";
import CGR_Winner from "@salesforce/label/c.CGR_Winner";
import CGR_OutsideScope from "@salesforce/label/c.CGR_OutsideScope";
import CGR_Tie from "@salesforce/label/c.CGR_Tie";
import CGR_Strengths from "@salesforce/label/c.CGR_Strengths";
import CGR_Weaknesses from "@salesforce/label/c.CGR_Weaknesses";
import CGR_Methodology from "@salesforce/label/c.CGR_Methodology";

export default class ComparisonGradingReport extends LightningElement {
  label = {
    CGR_Title,
    CGR_Loading,
    CGR_Error,
    CGR_NoData,
    CGR_Category,
    CGR_Weight,
    CGR_Score,
    CGR_Winner,
    CGR_OutsideScope,
    CGR_Tie,
    CGR_Strengths,
    CGR_Weaknesses,
    CGR_Methodology,
  };

  @track report;
  isLoading = true;
  hasError = false;
  errorMessage = "";

  get hasData() {
    return this.report != null;
  }

  get isEmpty() {
    return !this.isLoading && !this.hasError && !this.hasData;
  }

  get formattedDate() {
    if (!this.report?.generatedDate) {
      return "";
    }
    return new Date(this.report.generatedDate).toLocaleDateString("en-US", {
      year: "numeric",
      month: "long",
      day: "numeric",
    });
  }

  get platformAGradeClass() {
    return `grade-badge ${this._gradeColorClass(this.report?.platformAGrade)}`;
  }

  get platformBGradeClass() {
    return `grade-badge ${this._gradeColorClass(this.report?.platformBGrade)}`;
  }

  get benchmarkRows() {
    if (!this.report) {
      return [];
    }
    const aMap = {};
    const bMap = {};
    for (const s of this.report.platformAScores) {
      aMap[s.categoryName] = s;
    }
    for (const s of this.report.platformBScores) {
      bMap[s.categoryName] = s;
    }

    return this.report.categories.map((cat) => {
      const aScore = aMap[cat.name];
      const bScore = bMap[cat.name];
      const aApplicable = aScore?.applicable ?? false;
      const bApplicable = bScore?.applicable ?? false;
      const aVal = aApplicable ? aScore.score : null;
      const bVal = bApplicable ? bScore.score : null;

      let winner = this.label.CGR_Tie;
      let winnerClass = "slds-text-color_default";
      if (aVal !== null && bVal !== null) {
        if (aVal > bVal) {
          winner = this.report.platformAName;
          winnerClass = "slds-text-color_default";
        } else if (bVal > aVal) {
          winner = this.report.platformBName;
          winnerClass = "slds-text-color_default";
        }
      } else if (aVal !== null && bVal === null) {
        winner = this.report.platformAName;
      } else if (bVal !== null && aVal === null) {
        winner = this.report.platformBName;
      } else {
        winner = "—";
      }

      return {
        key: cat.name,
        name: cat.name,
        weight: `${cat.weight}%`,
        aScore: aApplicable ? `${aVal}/10` : this.label.CGR_OutsideScope,
        bScore: bApplicable ? `${bVal}/10` : this.label.CGR_OutsideScope,
        aIsNA: !aApplicable,
        bIsNA: !bApplicable,
        delta: aVal !== null && bVal !== null ? aVal - bVal : null,
        deltaDisplay:
          aVal !== null && bVal !== null
            ? aVal - bVal > 0
              ? `+${aVal - bVal}`
              : `${aVal - bVal}`
            : "—",
        winner,
        winnerClass,
      };
    });
  }

  get platformAStrengths() {
    if (!this.report) {
      return [];
    }
    return this.report.platformAScores
      .filter((s) => s.applicable && s.strengths?.length > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 3)
      .map((s) => ({
        key: s.categoryName,
        categoryName: s.categoryName,
        score: s.score,
        items: s.strengths,
      }));
  }

  get platformAWeaknesses() {
    if (!this.report) {
      return [];
    }
    return this.report.platformAScores
      .filter((s) => s.applicable && s.weaknesses?.length > 0)
      .sort((a, b) => a.score - b.score)
      .slice(0, 3)
      .map((s) => ({
        key: s.categoryName,
        categoryName: s.categoryName,
        score: s.score,
        items: s.weaknesses,
      }));
  }

  get platformBStrengths() {
    if (!this.report) {
      return [];
    }
    return this.report.platformBScores
      .filter((s) => s.applicable && s.strengths?.length > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 3)
      .map((s) => ({
        key: s.categoryName,
        categoryName: s.categoryName,
        score: s.score,
        items: s.strengths,
      }));
  }

  get platformBWeaknesses() {
    if (!this.report) {
      return [];
    }
    return this.report.platformBScores
      .filter((s) => s.applicable && s.weaknesses?.length > 0)
      .sort((a, b) => a.score - b.score)
      .slice(0, 3)
      .map((s) => ({
        key: s.categoryName,
        categoryName: s.categoryName,
        score: s.score,
        items: s.weaknesses,
      }));
  }

  connectedCallback() {
    this._loadReport();
  }

  async _loadReport() {
    this.isLoading = true;
    this.hasError = false;
    try {
      this.report = await generateReport();
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error?.body?.message ?? this.label.CGR_Error;
    } finally {
      this.isLoading = false;
    }
  }

  _gradeColorClass(grade) {
    if (!grade) {
      return "grade-neutral";
    }
    if (grade.startsWith("A")) {
      return "grade-a";
    }
    if (grade.startsWith("B")) {
      return "grade-b";
    }
    if (grade.startsWith("C")) {
      return "grade-c";
    }
    if (grade.startsWith("D")) {
      return "grade-d";
    }
    return "grade-f";
  }
}
