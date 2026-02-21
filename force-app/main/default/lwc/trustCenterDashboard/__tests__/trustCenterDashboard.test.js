import { createElement } from "lwc";
import TrustCenterDashboard from "c/trustCenterDashboard";
import getPublicViews from "@salesforce/apex/TrustCenterController.getPublicViews";
// Mock wire adapter for getPublicViews
jest.mock(
  "@salesforce/apex/TrustCenterController.getPublicViews",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

// Mock imperative method for triggerDataAggregation
jest.mock(
  "@salesforce/apex/TrustCenterController.triggerDataAggregation",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

// Mock wire adapter for child component (trustCenterLinkManager)
jest.mock(
  "@salesforce/apex/TrustCenterController.getActiveLinks",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

// Mock imperative methods used by child component
jest.mock(
  "@salesforce/apex/TrustCenterController.createShareableLink",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock("@salesforce/apex/TrustCenterController.revokeLink", () => ({ default: jest.fn() }), {
  virtual: true,
});

// Mock refreshApex
jest.mock("@salesforce/apex", () => ({ refreshApex: jest.fn().mockResolvedValue(undefined) }), {
  virtual: true,
});

// Mock ShowToastEvent
jest.mock("lightning/platformShowToastEvent", () => ({ ShowToastEvent: jest.fn() }), {
  virtual: true,
});

// Mock custom labels - Dashboard
jest.mock("@salesforce/label/c.TC_DashboardTitle", () => ({ default: "Trust Center" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_ComplianceStatus", () => ({ default: "Compliance Status" }), {
  virtual: true,
});
jest.mock(
  "@salesforce/label/c.TC_NoFrameworks",
  () => ({ default: "No compliance frameworks available." }),
  { virtual: true }
);
jest.mock("@salesforce/label/c.TC_NoViews", () => ({ default: "No compliance data available." }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_Loading", () => ({ default: "Loading..." }), { virtual: true });
jest.mock("@salesforce/label/c.TC_Error", () => ({ default: "Error" }), { virtual: true });
jest.mock("@salesforce/label/c.TC_ErrorGeneric", () => ({ default: "An error occurred." }), {
  virtual: true,
});
jest.mock(
  "@salesforce/label/c.TC_RunAggregation",
  () => ({ default: "Aggregate Compliance Data" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.TC_AggregationComplete",
  () => ({ default: "Aggregation complete" }),
  { virtual: true }
);

// Mock child component labels (trustCenterBadge)
jest.mock("@salesforce/label/c.TC_ComplianceScore", () => ({ default: "Compliance Score" }), {
  virtual: true,
});
jest.mock(
  "@salesforce/label/c.TC_CertificationStatus",
  () => ({ default: "Certification Status" }),
  { virtual: true }
);
jest.mock("@salesforce/label/c.TC_LastAuditDate", () => ({ default: "Last Audit Date" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_Certified", () => ({ default: "Certified" }), { virtual: true });
jest.mock("@salesforce/label/c.TC_InProgress", () => ({ default: "In Progress" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_RenewalRequired", () => ({ default: "Renewal Required" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_NotStarted", () => ({ default: "Not Started" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_ScoreExcellent", () => ({ default: "Excellent" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_ScoreGood", () => ({ default: "Good" }), { virtual: true });
jest.mock("@salesforce/label/c.TC_ScoreNeedsWork", () => ({ default: "Needs Improvement" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_ScoreCritical", () => ({ default: "Critical" }), {
  virtual: true,
});

// Mock child component labels (trustCenterLinkManager)
jest.mock("@salesforce/label/c.TC_LinkManager", () => ({ default: "Link Manager" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_CreateLink", () => ({ default: "Create Link" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_CopyLink", () => ({ default: "Copy Link" }), { virtual: true });
jest.mock("@salesforce/label/c.TC_LinkCopied", () => ({ default: "Link copied" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_RevokeLink", () => ({ default: "Revoke" }), { virtual: true });
jest.mock("@salesforce/label/c.TC_LinkCreated", () => ({ default: "Link created" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_LinkRevoked", () => ({ default: "Link revoked" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_ShareableLinks", () => ({ default: "Shareable Links" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_AccessTier", () => ({ default: "Access Tier" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_ExpirationDate", () => ({ default: "Expiration Date" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_ExpirationDays", () => ({ default: "Expiration (Days)" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_AccessCount", () => ({ default: "Access Count" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_CreatedFor", () => ({ default: "Created For" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_DeactivateLink", () => ({ default: "Deactivate" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_AccessTierPublic", () => ({ default: "Public" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_AccessTierEmailGated", () => ({ default: "Email Gated" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_AccessTierNDA", () => ({ default: "NDA Required" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_NotCertified", () => ({ default: "Not Certified" }), {
  virtual: true,
});

const MOCK_VIEWS = [
  {
    Id: "a001000000test01",
    Name: "SOC 2",
    Framework__c: "SOC2",
    Compliance_Percentage__c: 95.5,
    Controls_Total__c: 100,
    Controls_Compliant__c: 95,
    Last_Audit_Date__c: "2025-06-15",
    Certification_Status__c: "Certified",
    Is_Public__c: true,
  },
  {
    Id: "a001000000test02",
    Name: "HIPAA",
    Framework__c: "HIPAA",
    Compliance_Percentage__c: 72.0,
    Controls_Total__c: 80,
    Controls_Compliant__c: 58,
    Last_Audit_Date__c: "2025-03-01",
    Certification_Status__c: "In_Progress",
    Is_Public__c: true,
  },
];

// Flush all microtasks
function flushPromises() {
  return new Promise((resolve) => {
    setTimeout(resolve, 0);
  });
}

describe("c-trust-center-dashboard", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-trust-center-dashboard", {
      is: TrustCenterDashboard,
    });
    document.body.appendChild(element);
    return element;
  }

  it("renders lightning-card with correct title", async () => {
    const element = createComponent();
    getPublicViews.emit(MOCK_VIEWS);
    await flushPromises();

    const card = element.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Trust Center");
  });

  it("renders badge components when data is returned", async () => {
    const element = createComponent();
    getPublicViews.emit(MOCK_VIEWS);
    await flushPromises();

    const badges = element.shadowRoot.querySelectorAll("c-trust-center-badge");
    expect(badges.length).toBe(2);
  });

  it("renders empty state when no views exist", async () => {
    const element = createComponent();
    getPublicViews.emit([]);
    await flushPromises();

    const emptyMessage = element.shadowRoot.querySelector(".slds-illustration");
    expect(emptyMessage).not.toBeNull();
  });

  it("renders error state when wire fails", async () => {
    const element = createComponent();
    getPublicViews.error({ body: { message: "Test error" } });
    await flushPromises();

    const errorAlert = element.shadowRoot.querySelector('[role="alert"]');
    expect(errorAlert).not.toBeNull();
  });

  it("renders link manager child component when views exist", async () => {
    const element = createComponent();
    getPublicViews.emit(MOCK_VIEWS);
    await flushPromises();

    const linkManager = element.shadowRoot.querySelector("c-trust-center-link-manager");
    expect(linkManager).not.toBeNull();
  });

  it("does not render link manager in empty state", async () => {
    const element = createComponent();
    getPublicViews.emit([]);
    await flushPromises();

    const linkManager = element.shadowRoot.querySelector("c-trust-center-link-manager");
    expect(linkManager).toBeNull();
  });

  it("passes correct props to badge components", async () => {
    const element = createComponent();
    getPublicViews.emit(MOCK_VIEWS);
    await flushPromises();

    const badges = element.shadowRoot.querySelectorAll("c-trust-center-badge");
    expect(badges[0].frameworkName).toBe("SOC 2");
    expect(badges[0].compliancePercentage).toBe(95.5);
    expect(badges[0].certificationStatus).toBe("Certified");
  });

  it("renders compliance status heading when views exist", async () => {
    const element = createComponent();
    getPublicViews.emit(MOCK_VIEWS);
    await flushPromises();

    const heading = element.shadowRoot.querySelector(".slds-text-heading_small");
    expect(heading).not.toBeNull();
    expect(heading.textContent).toBe("Compliance Status");
  });

  it("renders badge grid with correct ARIA role", async () => {
    const element = createComponent();
    getPublicViews.emit(MOCK_VIEWS);
    await flushPromises();

    const grid = element.shadowRoot.querySelector('[role="list"]');
    expect(grid).not.toBeNull();
  });
});
