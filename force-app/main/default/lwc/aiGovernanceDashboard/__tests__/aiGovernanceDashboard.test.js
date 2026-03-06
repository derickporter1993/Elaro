/**
 * Jest tests for aiGovernanceDashboard LWC component
 *
 * Tests cover:
 * - Loading, error, and empty state rendering
 * - Summary cards display
 * - Discovery flow (discover, register)
 * - Registry table actions (sort, risk level update)
 * - Audit trail display
 * - Refresh behaviour
 */

import { createElement } from "lwc";
import AiGovernanceDashboard from "c/aiGovernanceDashboard";

// Wire adapter callback storage
let mockRegisteredSystemsCallbacks = new Set();

// Imperative mock implementations
let mockGetGovernanceSummary = jest.fn();
let mockGetRegisteredSystemsImperative = jest.fn();
let mockDiscoverAISystems = jest.fn();
let mockRegisterAISystem = jest.fn();
let mockGetAIAuditTrail = jest.fn();
let mockUpdateRiskLevel = jest.fn();

// Mock wire adapter (getRegisteredSystems) — supports wire and imperative
jest.mock(
  "@salesforce/apex/AIGovernanceController.getRegisteredSystems",
  () => ({
    default: function MockRegisteredSystemsAdapter(callback) {
      if (new.target) {
        this.callback = callback;
        mockRegisteredSystemsCallbacks.add(callback);
        this.connect = () => {};
        this.disconnect = () => {
          mockRegisteredSystemsCallbacks.delete(this.callback);
        };
        this.update = () => {};
        return this;
      }
      return mockGetRegisteredSystemsImperative();
    },
  }),
  { virtual: true }
);

// Mock imperative Apex methods
jest.mock(
  "@salesforce/apex/AIGovernanceController.getGovernanceSummary",
  () => ({ default: (...args) => mockGetGovernanceSummary(...args) }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AIGovernanceController.discoverAISystems",
  () => ({ default: (...args) => mockDiscoverAISystems(...args) }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AIGovernanceController.registerAISystem",
  () => ({ default: (...args) => mockRegisterAISystem(...args) }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AIGovernanceController.getAIAuditTrail",
  () => ({ default: (...args) => mockGetAIAuditTrail(...args) }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AIGovernanceController.updateRiskLevel",
  () => ({ default: (...args) => mockUpdateRiskLevel(...args) }),
  { virtual: true }
);

// Mock @salesforce/label imports
jest.mock("@salesforce/label/c.AI_DiscoveryInProgress", () => ({ default: "Discovering..." }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_DiscoveryComplete", () => ({ default: "Discovery Complete" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_NoSystemsFound", () => ({ default: "No AI systems found" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_RiskUnacceptable", () => ({ default: "Unacceptable" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_RiskHigh", () => ({ default: "High" }), { virtual: true });
jest.mock("@salesforce/label/c.AI_RiskLimited", () => ({ default: "Limited" }), { virtual: true });
jest.mock("@salesforce/label/c.AI_RiskMinimal", () => ({ default: "Minimal" }), { virtual: true });
jest.mock("@salesforce/label/c.AI_RegisterSystem", () => ({ default: "Register" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_ComplianceScore", () => ({ default: "Compliance Score" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_TotalSystems", () => ({ default: "Total Systems" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_HighRiskSystems", () => ({ default: "High Risk Systems" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_GapsIdentified", () => ({ default: "Gaps Identified" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_EUAIAct", () => ({ default: "EU AI Act" }), { virtual: true });
jest.mock("@salesforce/label/c.AI_NISTRMF", () => ({ default: "NIST AI RMF" }), { virtual: true });
jest.mock("@salesforce/label/c.AI_RefreshData", () => ({ default: "Refresh" }), { virtual: true });
jest.mock("@salesforce/label/c.AI_ErrorGeneric", () => ({ default: "An error occurred" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_DashboardTitle", () => ({ default: "AI Governance" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_DiscoverSystems", () => ({ default: "Discover Systems" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_SystemRegistry", () => ({ default: "System Registry" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_NoGaps", () => ({ default: "No gaps found" }), { virtual: true });
jest.mock("@salesforce/label/c.AI_AuditTrail", () => ({ default: "Audit Trail" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.AI_NoAuditEntries", () => ({ default: "No audit entries" }), {
  virtual: true,
});

// Mock refreshApex
jest.mock("@salesforce/apex", () => ({ refreshApex: jest.fn().mockResolvedValue(undefined) }), {
  virtual: true,
});

// Mock ShowToastEvent — must produce real Event objects for dispatchEvent
jest.mock(
  "lightning/platformShowToastEvent",
  () => {
    class MockShowToastEvent extends CustomEvent {
      constructor(params) {
        super("lightning__showtoast", { detail: params });
      }
    }
    return { ShowToastEvent: MockShowToastEvent };
  },
  { virtual: true }
);

// ═══════════════════════════════════════════════════════════════
// Test Helpers
// ═══════════════════════════════════════════════════════════════

const MOCK_SUMMARY = {
  complianceScore: 82,
  totalSystems: 5,
  highRiskCount: 1,
  lastScanDate: "2026-03-01T00:00:00.000Z",
  gaps: [
    {
      id: "gap-1",
      severity: "High",
      controlName: "Risk Assessment",
      description: "Missing risk assessment documentation",
      recommendation: "Complete EU AI Act risk assessment",
    },
  ],
};

const MOCK_REGISTERED_SYSTEMS = [
  {
    Id: "a0B000000000001",
    Name: "Einstein Bot",
    System_Type__c: "Chatbot",
    Risk_Level__c: "High",
    Status__c: "Active",
    Detection_Method__c: "Automatic",
  },
  {
    Id: "a0B000000000002",
    Name: "ML Pipeline",
    System_Type__c: "Prediction",
    Risk_Level__c: "Limited",
    Status__c: "Active",
    Detection_Method__c: "Manual",
  },
];

const MOCK_AUDIT_TRAIL = [
  {
    actionType: "Risk Level Changed",
    section: "Registry",
    changedBy: "Admin User",
    severity: "Medium",
    display: "Risk changed from Limited to High",
    changeDate: "2026-03-01T10:30:00.000Z",
  },
];

const MOCK_DISCOVERED_SYSTEMS = [
  {
    systemName: "New AI System",
    systemType: "Generative",
    detectionMethod: "API Scan",
    namespacePrefix: "elaro",
    useCaseDescription: "Content generation",
  },
];

const emitRegisteredSystems = (data) => {
  mockRegisteredSystemsCallbacks.forEach((cb) => cb({ data, error: undefined }));
};

const emitRegisteredSystemsError = (error) => {
  mockRegisteredSystemsCallbacks.forEach((cb) => cb({ data: undefined, error }));
};

function flushPromises() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function createComponent() {
  const element = createElement("c-ai-governance-dashboard", {
    is: AiGovernanceDashboard,
  });
  document.body.appendChild(element);
  return element;
}

// ═══════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════

describe("c-ai-governance-dashboard", () => {
  beforeEach(() => {
    mockGetGovernanceSummary.mockResolvedValue(MOCK_SUMMARY);
    mockGetAIAuditTrail.mockResolvedValue(MOCK_AUDIT_TRAIL);
    mockDiscoverAISystems.mockResolvedValue(MOCK_DISCOVERED_SYSTEMS);
    mockRegisterAISystem.mockResolvedValue(undefined);
    mockUpdateRiskLevel.mockResolvedValue(undefined);
    mockRegisteredSystemsCallbacks = new Set();
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  // ─── Loading State ───────────────────────────────────────────

  it("displays loading spinner on initial render", () => {
    const element = createComponent();

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();
  });

  // ─── Error State ─────────────────────────────────────────────

  it("displays error message when data load fails", async () => {
    mockGetGovernanceSummary.mockRejectedValue({
      body: { message: "Server error" },
    });

    const element = createComponent();
    await flushPromises();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert).not.toBeNull();
    expect(alert.textContent).toContain("Server error");
  });

  it("displays generic error when error has no body", async () => {
    mockGetGovernanceSummary.mockRejectedValue(new Error("network"));

    const element = createComponent();
    await flushPromises();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert).not.toBeNull();
    expect(alert.textContent).toContain("An error occurred");
  });

  // ─── Wire Error State ────────────────────────────────────────

  it("handles wire adapter error for registered systems", async () => {
    const element = createComponent();
    await flushPromises();

    emitRegisteredSystemsError({ body: { message: "Wire error" } });
    await flushPromises();

    // Component should still render (wire error sets this.error only if data load succeeded)
    expect(element.shadowRoot.querySelector('[role="alert"]')).not.toBeNull();
  });

  // ─── Loaded / Main Content ──────────────────────────────────

  it("renders summary cards after data loads", async () => {
    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems(MOCK_REGISTERED_SYSTEMS);
    await flushPromises();

    const statValues = element.shadowRoot.querySelectorAll(".stat-value");
    expect(statValues.length).toBe(4);

    // Compliance score
    expect(statValues[0].textContent).toContain("82");
    // Total systems
    expect(statValues[1].textContent).toContain("5");
    // High risk count
    expect(statValues[2].textContent).toContain("1");
    // Gap count
    expect(statValues[3].textContent).toContain("1");
  });

  it("renders page header with dashboard title", async () => {
    const element = createComponent();
    await flushPromises();

    const title = element.shadowRoot.querySelector(".slds-page-header__name-title span");
    expect(title).not.toBeNull();
    expect(title.textContent).toBe("AI Governance");
  });

  // ─── Empty States ────────────────────────────────────────────

  it("shows empty message when no registered systems", async () => {
    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems([]);
    await flushPromises();

    const emptyText = element.shadowRoot.querySelector(".slds-text-color_weak");
    expect(emptyText).not.toBeNull();
  });

  it("shows no-gaps message when gaps array is empty", async () => {
    mockGetGovernanceSummary.mockResolvedValue({
      ...MOCK_SUMMARY,
      gaps: [],
    });

    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems(MOCK_REGISTERED_SYSTEMS);
    await flushPromises();

    const noGapsText = Array.from(
      element.shadowRoot.querySelectorAll(".slds-text-color_weak")
    ).find((el) => el.textContent === "No gaps found");
    expect(noGapsText).not.toBeNull();
  });

  it("shows no-audit message when audit trail is empty", async () => {
    mockGetAIAuditTrail.mockResolvedValue([]);

    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems(MOCK_REGISTERED_SYSTEMS);
    await flushPromises();

    const noAuditText = Array.from(
      element.shadowRoot.querySelectorAll(".slds-text-color_weak")
    ).find((el) => el.textContent === "No audit entries");
    expect(noAuditText).not.toBeNull();
  });

  // ─── Discovery Flow ──────────────────────────────────────────

  it("calls discoverAISystems when discover button is clicked", async () => {
    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems(MOCK_REGISTERED_SYSTEMS);
    await flushPromises();

    const discoverBtn = Array.from(element.shadowRoot.querySelectorAll("lightning-button")).find(
      (btn) => btn.label === "Discover Systems"
    );

    expect(discoverBtn).not.toBeNull();
    discoverBtn.click();
    await flushPromises();

    expect(mockDiscoverAISystems).toHaveBeenCalledTimes(1);
  });

  it("dispatches toast event when no systems discovered", async () => {
    mockDiscoverAISystems.mockResolvedValue([]);

    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems(MOCK_REGISTERED_SYSTEMS);
    await flushPromises();

    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);

    const discoverBtn = Array.from(element.shadowRoot.querySelectorAll("lightning-button")).find(
      (btn) => btn.label === "Discover Systems"
    );
    discoverBtn.click();
    await flushPromises();

    expect(toastHandler).toHaveBeenCalled();
  });

  // ─── Registry Table Sorting ──────────────────────────────────

  it("updates sort state on sort event", async () => {
    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems(MOCK_REGISTERED_SYSTEMS);
    await flushPromises();

    // The registry datatable is the first one with onsort handler
    const datatables = element.shadowRoot.querySelectorAll("lightning-datatable");
    const registryTable = Array.from(datatables).find((dt) => dt.sortedBy !== undefined);
    expect(registryTable).not.toBeNull();

    registryTable.dispatchEvent(
      new CustomEvent("sort", {
        detail: { fieldName: "Risk_Level__c", sortDirection: "desc" },
      })
    );
    await flushPromises();

    expect(registryTable.sortedBy).toBe("Risk_Level__c");
    expect(registryTable.sortedDirection).toBe("desc");
  });

  // ─── Registry Row Actions ────────────────────────────────────

  it("opens record page on view action", async () => {
    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems(MOCK_REGISTERED_SYSTEMS);
    await flushPromises();

    const openSpy = jest.spyOn(window, "open").mockImplementation(() => {});

    const datatables = element.shadowRoot.querySelectorAll("lightning-datatable");
    const registryTable = Array.from(datatables).find((dt) => dt.sortedBy !== undefined);
    expect(registryTable).not.toBeNull();

    registryTable.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: {
          action: { name: "view" },
          row: MOCK_REGISTERED_SYSTEMS[0],
        },
      })
    );
    await flushPromises();

    expect(openSpy).toHaveBeenCalledWith("/a0B000000000001", "_blank");
    openSpy.mockRestore();
  });

  it("calls updateRiskLevel on risk action", async () => {
    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems(MOCK_REGISTERED_SYSTEMS);
    await flushPromises();

    const datatables = element.shadowRoot.querySelectorAll("lightning-datatable");
    const registryTable = Array.from(datatables).find((dt) => dt.sortedBy !== undefined);
    expect(registryTable).not.toBeNull();

    registryTable.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: {
          action: { name: "risk_Minimal" },
          row: MOCK_REGISTERED_SYSTEMS[0],
        },
      })
    );
    await flushPromises();

    expect(mockUpdateRiskLevel).toHaveBeenCalledWith({
      systemId: "a0B000000000001",
      newRiskLevel: "Minimal",
    });
  });

  // ─── Refresh ─────────────────────────────────────────────────

  it("reloads data when refresh button is clicked", async () => {
    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems(MOCK_REGISTERED_SYSTEMS);
    await flushPromises();

    // Reset call counts after initial load
    mockGetGovernanceSummary.mockClear();
    mockGetAIAuditTrail.mockClear();

    const refreshBtn = Array.from(element.shadowRoot.querySelectorAll("lightning-button")).find(
      (btn) => btn.label === "Refresh"
    );
    expect(refreshBtn).not.toBeNull();

    refreshBtn.click();
    await flushPromises();

    expect(mockGetGovernanceSummary).toHaveBeenCalledTimes(1);
    expect(mockGetAIAuditTrail).toHaveBeenCalledTimes(1);
  });

  // ─── Computed Properties ─────────────────────────────────────

  it("returns 0 for formattedScore when complianceScore is null", async () => {
    mockGetGovernanceSummary.mockResolvedValue({
      ...MOCK_SUMMARY,
      complianceScore: null,
    });

    const element = createComponent();
    await flushPromises();

    const scoreEl = element.shadowRoot.querySelector(".stat-value");
    expect(scoreEl.textContent).toContain("0");
  });

  // ─── Gaps Display ────────────────────────────────────────────

  it("renders gap items with severity badges", async () => {
    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems(MOCK_REGISTERED_SYSTEMS);
    await flushPromises();

    const badges = element.shadowRoot.querySelectorAll("lightning-badge");
    const gapBadge = Array.from(badges).find((b) => b.label === "High");
    expect(gapBadge).not.toBeNull();
  });

  // ─── Audit Trail ─────────────────────────────────────────────

  it("renders audit trail datatable with entries", async () => {
    const element = createComponent();
    await flushPromises();

    emitRegisteredSystems(MOCK_REGISTERED_SYSTEMS);
    await flushPromises();

    // Audit trail datatable is the one without sort attributes
    const datatables = element.shadowRoot.querySelectorAll("lightning-datatable");
    const auditTable = Array.from(datatables).find((dt) => dt.sortedBy === undefined);
    expect(auditTable).not.toBeNull();
    expect(auditTable.data.length).toBe(1);
    expect(auditTable.data[0].actionType).toBe("Risk Level Changed");
  });
});
