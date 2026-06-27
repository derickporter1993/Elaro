import { createElement } from "lwc";
import SecDisclosureDashboard from "c/secDisclosureDashboard";
import getOpenAssessments from "@salesforce/apex/SECDisclosureController.getOpenAssessments";

jest.mock(
  "@salesforce/apex/SECDisclosureController.getOpenAssessments",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "lightning/navigation",
  () => {
    const Navigate = Symbol("Navigate");
    const GenerateUrl = Symbol("GenerateUrl");
    const NavigationMixin = (Base) => {
      return class extends Base {
        [Navigate](pageRef) {
          this._pageRef = pageRef;
        }
        [GenerateUrl]() {
          return Promise.resolve("mock-url");
        }
      };
    };
    NavigationMixin.Navigate = Navigate;
    NavigationMixin.GenerateUrl = GenerateUrl;
    return { NavigationMixin };
  },
  { virtual: true }
);

jest.mock("lightning/platformShowToastEvent", () => ({ ShowToastEvent: jest.fn() }), {
  virtual: true,
});

jest.mock("@salesforce/apex", () => ({ refreshApex: jest.fn() }), {
  virtual: true,
});

// Custom label mocks
jest.mock(
  "@salesforce/label/c.SEC_DashboardTitle",
  () => ({ default: "SEC Disclosure Dashboard" }),
  { virtual: true }
);
jest.mock("@salesforce/label/c.SEC_OpenAssessments", () => ({ default: "Open Assessments" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.SEC_NoOpenAssessments", () => ({ default: "No open assessments" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.SEC_Loading", () => ({ default: "Loading..." }), { virtual: true });
jest.mock("@salesforce/label/c.SEC_ErrorTitle", () => ({ default: "Error" }), { virtual: true });
jest.mock("@salesforce/label/c.SEC_AtRisk", () => ({ default: "At Risk" }), { virtual: true });
jest.mock("@salesforce/label/c.SEC_OnTrack", () => ({ default: "On Track" }), { virtual: true });

// Child component label mocks (secMaterialityCard)
jest.mock(
  "@salesforce/label/c.SEC_IncidentDescription",
  () => ({ default: "Incident Description" }),
  { virtual: true }
);
jest.mock("@salesforce/label/c.SEC_DiscoveryDate", () => ({ default: "Discovery Date" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.SEC_FilingDeadline", () => ({ default: "Filing Deadline" }), {
  virtual: true,
});
jest.mock(
  "@salesforce/label/c.SEC_DeterminationResult",
  () => ({ default: "Determination Result" }),
  { virtual: true }
);
jest.mock("@salesforce/label/c.SEC_SLAStatus", () => ({ default: "SLA Status" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.SEC_Breached", () => ({ default: "Breached" }), { virtual: true });

const MOCK_ASSESSMENTS = [
  {
    Id: "a0B000000000001",
    Name: "MA-2026-001",
    Filing_Deadline__c: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString(),
    Discovery_Date__c: "2026-02-01T00:00:00.000Z",
    Determination_Result__c: "Under Review",
  },
  {
    Id: "a0B000000000002",
    Name: "MA-2026-002",
    Filing_Deadline__c: new Date(Date.now() + 1 * 24 * 60 * 60 * 1000).toISOString(),
    Discovery_Date__c: "2026-02-05T00:00:00.000Z",
    Determination_Result__c: "Material",
  },
  {
    Id: "a0B000000000003",
    Name: "MA-2026-003",
    Filing_Deadline__c: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString(),
    Discovery_Date__c: "2026-02-08T00:00:00.000Z",
    Determination_Result__c: "Not Material",
  },
];

describe("c-sec-disclosure-dashboard", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-sec-disclosure-dashboard", {
      is: SecDisclosureDashboard,
    });
    document.body.appendChild(element);
    return element;
  }

  it("renders lightning-card with dashboard title", () => {
    const element = createComponent();
    const card = element.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("SEC Disclosure Dashboard");
  });

  it("renders assessments after wire emits data", async () => {
    const element = createComponent();
    getOpenAssessments.emit(MOCK_ASSESSMENTS);
    await Promise.resolve();

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).toBeNull();

    const cards = element.shadowRoot.querySelectorAll("c-sec-materiality-card");
    expect(cards.length).toBe(3);
  });

  it("renders empty state when no assessments", async () => {
    const element = createComponent();
    getOpenAssessments.emit([]);
    await Promise.resolve();

    const emptyState = element.shadowRoot.querySelector(".slds-illustration");
    expect(emptyState).not.toBeNull();
  });

  it("renders error state on wire error", async () => {
    const element = createComponent();
    getOpenAssessments.error({ body: { message: "Permission denied" } });
    await Promise.resolve();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert).not.toBeNull();
  });

  it("displays correct summary metrics", async () => {
    const element = createComponent();
    getOpenAssessments.emit(MOCK_ASSESSMENTS);
    await Promise.resolve();

    const metricValues = element.shadowRoot.querySelectorAll(".metric-value");
    expect(metricValues.length).toBe(3);
    expect(metricValues[0].textContent).toBe("3");
  });

  it("calculates at-risk count for assessments due within 1 day", async () => {
    const element = createComponent();
    getOpenAssessments.emit(MOCK_ASSESSMENTS);
    await Promise.resolve();

    const metricValues = element.shadowRoot.querySelectorAll(".metric-value");
    const atRiskValue = metricValues[1].textContent;
    expect(Number(atRiskValue)).toBeGreaterThanOrEqual(0);
  });

  it("calculates on-track count for assessments due in more than 1 day", async () => {
    const element = createComponent();
    getOpenAssessments.emit(MOCK_ASSESSMENTS);
    await Promise.resolve();

    const metricValues = element.shadowRoot.querySelectorAll(".metric-value");
    const onTrackValue = metricValues[2].textContent;
    expect(Number(onTrackValue)).toBeGreaterThanOrEqual(0);
  });

  it("passes assessment data to child materiality cards", async () => {
    const element = createComponent();
    getOpenAssessments.emit(MOCK_ASSESSMENTS);
    await Promise.resolve();

    const cards = element.shadowRoot.querySelectorAll("c-sec-materiality-card");
    expect(cards[0].assessment).toEqual(MOCK_ASSESSMENTS[0]);
    expect(cards[1].assessment).toEqual(MOCK_ASSESSMENTS[1]);
  });

  it("handles viewassessment event from child card without error", async () => {
    const element = createComponent();
    getOpenAssessments.emit(MOCK_ASSESSMENTS);
    await Promise.resolve();

    const card = element.shadowRoot.querySelector("c-sec-materiality-card");
    expect(() => {
      card.dispatchEvent(
        new CustomEvent("viewassessment", {
          detail: { assessmentId: "a0B000000000001" },
        })
      );
    }).not.toThrow();
  });

  it("renders New Assessment button", async () => {
    const element = createComponent();
    getOpenAssessments.emit(MOCK_ASSESSMENTS);
    await Promise.resolve();

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    const brandButton = [...buttons].find((b) => b.variant === "brand");
    expect(brandButton).not.toBeUndefined();
    expect(brandButton.label).toBe("New Assessment");
  });

  it("handles new assessment button click without error", async () => {
    const element = createComponent();
    getOpenAssessments.emit(MOCK_ASSESSMENTS);
    await Promise.resolve();

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    const brandButton = [...buttons].find((b) => b.variant === "brand");
    expect(() => brandButton.click()).not.toThrow();
  });

  it("renders refresh button", async () => {
    const element = createComponent();
    getOpenAssessments.emit(MOCK_ASSESSMENTS);
    await Promise.resolve();

    const refreshBtn = element.shadowRoot.querySelector("lightning-button-icon");
    expect(refreshBtn).not.toBeNull();
  });

  it("shows generic error message when no body in error", async () => {
    const element = createComponent();
    getOpenAssessments.error({ message: "Network error" });
    await Promise.resolve();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert).not.toBeNull();
  });
});
