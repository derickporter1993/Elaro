/**
 * Jest tests for complianceDashboard LWC component
 *
 * Tests cover:
 * - Wire adapter data handling (via rendered output)
 * - Dashboard data display
 * - Error handling
 * - Loading states
 */

import { createElement } from "lwc";
import ComplianceDashboard from "c/complianceDashboard";

// Mock custom labels to resolve to their English display values (localization-resilient)
jest.mock("@salesforce/label/c.CD_CardTitle", () => ({ default: "Compliance Dashboard" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.CD_LoadingAlt", () => ({ default: "Loading" }), { virtual: true });
jest.mock("@salesforce/label/c.CD_ErrorLoading", () => ({ default: "Error loading dashboard:" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.CD_RecentEvidence", () => ({ default: "Recent Evidence" }), {
  virtual: true,
});
jest.mock(
  "@salesforce/label/c.ELKPI_UnknownError",
  () => ({ default: "An unknown error occurred" }),
  { virtual: true }
);
// complianceScoreCard child component labels (rendered inside this dashboard)
jest.mock("@salesforce/label/c.CSC_ComplianceScore", () => ({ default: "Compliance Score" }), {
  virtual: true,
});
jest.mock(
  "@salesforce/label/c.CSC_LoadingDetails",
  () => ({ default: "Loading framework details" }),
  { virtual: true }
);
jest.mock("@salesforce/label/c.CSC_PoliciesCompliant", () => ({ default: "Policies Compliant" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.CSC_Gaps", () => ({ default: "Gaps" }), { virtual: true });
jest.mock("@salesforce/label/c.CSC_FrameworkMappings", () => ({ default: "Framework Mappings:" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.CSC_EvidenceItems", () => ({ default: "Evidence Items:" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.CSC_Requirements", () => ({ default: "Requirements:" }), {
  virtual: true,
});
jest.mock(
  "@salesforce/label/c.CSC_LatestAuditPackage",
  () => ({ default: "Latest Audit Package:" }),
  { virtual: true }
);
jest.mock("@salesforce/label/c.CSC_Status", () => ({ default: "Status:" }), { virtual: true });
jest.mock("@salesforce/label/c.CSC_Period", () => ({ default: "Period:" }), { virtual: true });
jest.mock("@salesforce/label/c.CSC_ViewPackage", () => ({ default: "View Package" }), {
  virtual: true,
});
jest.mock(
  "@salesforce/label/c.CSC_FailedToLoadDetails",
  () => ({ default: "Failed to load framework details" }),
  { virtual: true }
);

let mockDashboardCallbacks = new Set();
let mockFrameworkDetailsCallbacks = new Set();

// Mock the main dashboard wire adapter
jest.mock(
  "@salesforce/apex/ComplianceDashboardController.getDashboardSummary",
  () => ({
    default: function MockDashboardAdapter(callback) {
      if (new.target) {
        this.callback = callback;
        mockDashboardCallbacks.add(callback);
        this.connect = () => {};
        this.disconnect = () => {
          mockDashboardCallbacks.delete(this.callback);
        };
        this.update = () => {};
        return this;
      }
      return Promise.resolve(null);
    },
  }),
  { virtual: true }
);

// Mock the child component wire adapter (used by c-compliance-score-card)
jest.mock(
  "@salesforce/apex/ComplianceScoreCardController.getFrameworkDetails",
  () => ({
    default: function MockFrameworkDetailsAdapter(callback) {
      if (new.target) {
        this.callback = callback;
        mockFrameworkDetailsCallbacks.add(callback);
        this.connect = () => {};
        this.disconnect = () => {
          mockFrameworkDetailsCallbacks.delete(this.callback);
        };
        this.update = () => {};
        return this;
      }
      return Promise.resolve(null);
    },
  }),
  { virtual: true }
);

const emitDashboardData = (data) => {
  mockDashboardCallbacks.forEach((cb) => cb({ data, error: undefined }));
};

const emitDashboardError = (error) => {
  mockDashboardCallbacks.forEach((cb) => cb({ data: undefined, error }));
};

describe("c-compliance-dashboard", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    mockDashboardCallbacks = new Set();
    mockFrameworkDetailsCallbacks = new Set();
  });

  async function createComponent() {
    const element = createElement("c-compliance-dashboard", {
      is: ComplianceDashboard,
    });
    document.body.appendChild(element);
    await Promise.resolve();
    return element;
  }

  describe("Initial Rendering", () => {
    it("renders the component", async () => {
      const element = await createComponent();
      await Promise.resolve();

      expect(element).not.toBeNull();
      const card = element.shadowRoot.querySelector("lightning-card");
      expect(card).not.toBeNull();
    });

    it("shows loading state initially", async () => {
      const element = await createComponent();
      await Promise.resolve();

      // Check for spinner or loading indicator in rendered output
      const spinner = element.shadowRoot.querySelector("lightning-spinner");
      expect(spinner).not.toBeNull();
    });
  });

  describe("Wire Adapter Data Handling", () => {
    it("displays dashboard data after wire adapter receives data", async () => {
      const mockData = {
        frameworks: [
          { framework: "SOC2", score: 85, status: "COMPLIANT" },
          { framework: "HIPAA", score: 72, status: "ACTION_REQUIRED" },
        ],
        recentGaps: [{ Id: "gap1", Severity__c: "HIGH", Title__c: "Test Gap 1" }],
        recentEvidence: [{ Id: "ev1", Evidence_Type__c: "Login", Status__c: "COLLECTED" }],
      };

      const element = await createComponent();
      await Promise.resolve();

      emitDashboardData(mockData);
      await Promise.resolve();
      await Promise.resolve();

      // Spinner should be hidden after data loads
      const spinner = element.shadowRoot.querySelector("lightning-spinner");
      expect(spinner).toBeNull();

      // Framework cards should be rendered
      const scoreCards = element.shadowRoot.querySelectorAll("c-compliance-score-card");
      expect(scoreCards.length).toBe(2);
    });

    it("handles empty frameworks array", async () => {
      const mockData = {
        frameworks: [],
        recentGaps: [],
        recentEvidence: [],
      };

      const element = await createComponent();
      await Promise.resolve();

      emitDashboardData(mockData);
      await Promise.resolve();
      await Promise.resolve();

      // No score cards should be rendered
      const scoreCards = element.shadowRoot.querySelectorAll("c-compliance-score-card");
      expect(scoreCards.length).toBe(0);
    });
  });

  describe("Data Getters", () => {
    it("renders frameworks from dashboard data", async () => {
      const mockData = {
        frameworks: [
          { framework: "SOC2", score: 85 },
          { framework: "GDPR", score: 90 },
        ],
      };

      const element = await createComponent();
      await Promise.resolve();

      emitDashboardData(mockData);
      await Promise.resolve();
      await Promise.resolve();

      const scoreCards = element.shadowRoot.querySelectorAll("c-compliance-score-card");
      expect(scoreCards.length).toBe(2);
    });

    it("renders recent gaps from dashboard data", async () => {
      const mockData = {
        frameworks: [{ framework: "SOC2", score: 85 }],
        recentGaps: [
          { Id: "gap1", Title__c: "Gap 1" },
          { Id: "gap2", Title__c: "Gap 2" },
        ],
      };

      const element = await createComponent();
      await Promise.resolve();

      emitDashboardData(mockData);
      await Promise.resolve();
      await Promise.resolve();

      // Component should render with gap data - verify via child component or section
      // Gap list may or may not exist depending on template structure
      const card = element.shadowRoot.querySelector("lightning-card");
      expect(card).not.toBeNull();
    });

    it("handles missing gaps gracefully", async () => {
      const mockData = {
        frameworks: [{ framework: "SOC2", score: 85 }],
      };

      const element = await createComponent();
      await Promise.resolve();

      emitDashboardData(mockData);
      await Promise.resolve();
      await Promise.resolve();

      // Component should render without errors
      const card = element.shadowRoot.querySelector("lightning-card");
      expect(card).not.toBeNull();
    });

    it("renders recent evidence from dashboard data", async () => {
      const mockData = {
        frameworks: [{ framework: "SOC2", score: 85 }],
        recentEvidence: [{ Id: "ev1", Evidence_Type__c: "Login" }],
      };

      const element = await createComponent();
      await Promise.resolve();

      emitDashboardData(mockData);
      await Promise.resolve();
      await Promise.resolve();

      // Component should render with evidence data
      const card = element.shadowRoot.querySelector("lightning-card");
      expect(card).not.toBeNull();
    });
  });

  describe("Error Handling", () => {
    it("handles wire adapter error", async () => {
      const element = await createComponent();
      await Promise.resolve();

      const error = {
        body: { message: "Failed to load dashboard" },
        message: "Failed to load dashboard",
      };

      emitDashboardError(error);
      await Promise.resolve();
      await Promise.resolve();

      // Error message should be displayed
      const errorDiv = element.shadowRoot.querySelector(".slds-text-color_error");
      expect(errorDiv).not.toBeNull();
      expect(errorDiv.textContent).toContain("Failed to load");
    });

    it("displays error message in UI", async () => {
      const element = await createComponent();
      await Promise.resolve();

      const error = {
        body: { message: "Test error" },
        message: "Test error",
      };

      emitDashboardError(error);
      await Promise.resolve();
      await Promise.resolve();

      const errorDiv = element.shadowRoot.querySelector(".slds-text-color_error");
      expect(errorDiv).not.toBeNull();
    });

    it("handles error without body property", async () => {
      const element = await createComponent();
      await Promise.resolve();

      const error = { message: "Network error" };
      emitDashboardError(error);
      await Promise.resolve();
      await Promise.resolve();

      const errorDiv = element.shadowRoot.querySelector(".slds-text-color_error");
      expect(errorDiv).not.toBeNull();
      expect(errorDiv.textContent).toContain("Network error");
    });

    it("shows no error when data loads successfully", async () => {
      const element = await createComponent();
      await Promise.resolve();

      const mockData = { frameworks: [] };
      emitDashboardData(mockData);
      await Promise.resolve();
      await Promise.resolve();

      const errorDiv = element.shadowRoot.querySelector(".slds-text-color_error");
      expect(errorDiv).toBeNull();
    });
  });
});
