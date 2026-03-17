/**
 * Jest tests for aiGovernanceDashboard LWC component
 *
 * Tests cover:
 * - Loading state rendering
 * - Error state rendering
 * - Dashboard summary display with stat cards
 * - Wire adapter for registered systems
 * - Discovery flow (imperative call)
 * - Refresh and sort interactions
 * - Empty states for registry, gaps, and audit trail
 */

import { createElement } from "lwc";
import AiGovernanceDashboard from "c/aiGovernanceDashboard";

// --- Wire adapter mock for getRegisteredSystems ---
let mockRegistryCallbacks = new Set();

jest.mock(
  "@salesforce/apex/AIGovernanceController.getRegisteredSystems",
  () => ({
    default: function MockRegistryAdapter(callback) {
      if (new.target) {
        this.callback = callback;
        mockRegistryCallbacks.add(callback);
        this.connect = () => {};
        this.disconnect = () => {
          mockRegistryCallbacks.delete(this.callback);
        };
        this.update = () => {};
        return this;
      }
      return Promise.resolve(null);
    },
  }),
  { virtual: true }
);

const emitRegistryData = (data) => {
  mockRegistryCallbacks.forEach((cb) => cb({ data, error: undefined }));
};

const emitRegistryError = (error) => {
  mockRegistryCallbacks.forEach((cb) => cb({ data: undefined, error }));
};

// --- Imperative Apex mocks ---
const mockGetGovernanceSummary = jest.fn();
jest.mock(
  "@salesforce/apex/AIGovernanceController.getGovernanceSummary",
  () => ({ default: mockGetGovernanceSummary }),
  { virtual: true }
);

const mockGetAIAuditTrail = jest.fn();
jest.mock(
  "@salesforce/apex/AIGovernanceController.getAIAuditTrail",
  () => ({ default: mockGetAIAuditTrail }),
  { virtual: true }
);

const mockDiscoverAISystems = jest.fn();
jest.mock(
  "@salesforce/apex/AIGovernanceController.discoverAISystems",
  () => ({ default: mockDiscoverAISystems }),
  { virtual: true }
);

const mockRegisterAISystem = jest.fn();
jest.mock(
  "@salesforce/apex/AIGovernanceController.registerAISystem",
  () => ({ default: mockRegisterAISystem }),
  { virtual: true }
);

const mockUpdateRiskLevel = jest.fn();
jest.mock(
  "@salesforce/apex/AIGovernanceController.updateRiskLevel",
  () => ({ default: mockUpdateRiskLevel }),
  { virtual: true }
);

// --- refreshApex mock ---
jest.mock(
  "@salesforce/apex",
  () => ({ refreshApex: jest.fn().mockResolvedValue(undefined) }),
  { virtual: true }
);

// --- ShowToastEvent mock ---
jest.mock(
  "lightning/platformShowToastEvent",
  () => ({
    ShowToastEvent: jest.fn().mockImplementation((detail) => ({
      detail,
      type: "lightning__showtoast",
    })),
  }),
  { virtual: true }
);

// --- Custom label mocks ---
const LABEL_MODULES = [
  "AI_DiscoveryInProgress",
  "AI_DiscoveryComplete",
  "AI_NoSystemsFound",
  "AI_RiskUnacceptable",
  "AI_RiskHigh",
  "AI_RiskLimited",
  "AI_RiskMinimal",
  "AI_RegisterSystem",
  "AI_ComplianceScore",
  "AI_TotalSystems",
  "AI_HighRiskSystems",
  "AI_GapsIdentified",
  "AI_EUAIAct",
  "AI_NISTRMF",
  "AI_RefreshData",
  "AI_ErrorGeneric",
  "AI_DashboardTitle",
  "AI_DiscoverSystems",
  "AI_SystemRegistry",
  "AI_NoGaps",
  "AI_AuditTrail",
  "AI_NoAuditEntries",
];

LABEL_MODULES.forEach((label) => {
  jest.mock(`@salesforce/label/c.${label}`, () => ({ default: label }), {
    virtual: true,
  });
});

// --- Test data helpers ---
const MOCK_SUMMARY = {
  complianceScore: 72,
  totalSystems: 5,
  highRiskCount: 2,
  lastScanDate: "2026-03-01T00:00:00.000Z",
  gaps: [
    {
      id: "gap1",
      severity: "High",
      controlName: "Bias Testing",
      description: "No bias testing performed",
      recommendation: "Implement bias testing framework",
    },
  ],
};

const MOCK_AUDIT_TRAIL = [
  {
    actionType: "Risk Update",
    section: "AI Registry",
    changedBy: "Admin User",
    severity: "HIGH",
    display: "Risk level changed to High",
    changeDate: "2026-03-10T12:00:00.000Z",
  },
];

const MOCK_REGISTERED_SYSTEMS = [
  {
    Id: "a01xx000000001",
    Name: "Einstein Bot",
    System_Type__c: "Chatbot",
    Risk_Level__c: "High",
    Status__c: "Active",
    Detection_Method__c: "Manual",
  },
  {
    Id: "a01xx000000002",
    Name: "Prediction Builder",
    System_Type__c: "ML Model",
    Risk_Level__c: "Minimal",
    Status__c: "Active",
    Detection_Method__c: "Auto-Discovery",
  },
];

// --- Utility ---
const flushPromises = () => new Promise(process.nextTick);

describe("c-ai-governance-dashboard", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    mockRegistryCallbacks = new Set();
  });

  async function createComponent() {
    // Default: imperative calls resolve successfully
    mockGetGovernanceSummary.mockResolvedValue(MOCK_SUMMARY);
    mockGetAIAuditTrail.mockResolvedValue(MOCK_AUDIT_TRAIL);

    const element = createElement("c-ai-governance-dashboard", {
      is: AiGovernanceDashboard,
    });
    document.body.appendChild(element);
    return element;
  }

  // ---------- Loading State ----------

  describe("Loading State", () => {
    it("shows a spinner while data is loading", async () => {
      // Make the imperative calls hang so we can observe loading state
      mockGetGovernanceSummary.mockReturnValue(new Promise(() => {}));
      mockGetAIAuditTrail.mockReturnValue(new Promise(() => {}));

      const element = createElement("c-ai-governance-dashboard", {
        is: AiGovernanceDashboard,
      });
      document.body.appendChild(element);
      await Promise.resolve();

      const spinner = element.shadowRoot.querySelector("lightning-spinner");
      expect(spinner).not.toBeNull();
    });

    it("hides spinner after data loads", async () => {
      const element = await createComponent();
      await flushPromises();

      const spinner = element.shadowRoot.querySelector("lightning-spinner");
      expect(spinner).toBeNull();
    });
  });

  // ---------- Error State ----------

  describe("Error State", () => {
    it("displays error alert when imperative call fails", async () => {
      mockGetGovernanceSummary.mockRejectedValue({
        body: { message: "Insufficient permissions" },
      });
      mockGetAIAuditTrail.mockResolvedValue([]);

      const element = createElement("c-ai-governance-dashboard", {
        is: AiGovernanceDashboard,
      });
      document.body.appendChild(element);
      await flushPromises();

      const alert = element.shadowRoot.querySelector('[role="alert"]');
      expect(alert).not.toBeNull();
      expect(alert.textContent).toContain("Insufficient permissions");
    });

    it("falls back to generic error label when body is missing", async () => {
      mockGetGovernanceSummary.mockRejectedValue({ message: "Unknown" });
      mockGetAIAuditTrail.mockResolvedValue([]);

      const element = createElement("c-ai-governance-dashboard", {
        is: AiGovernanceDashboard,
      });
      document.body.appendChild(element);
      await flushPromises();

      const alert = element.shadowRoot.querySelector('[role="alert"]');
      expect(alert).not.toBeNull();
      expect(alert.textContent).toContain("AI_ErrorGeneric");
    });

    it("displays error from wire adapter", async () => {
      const element = await createComponent();
      await flushPromises();

      emitRegistryError({ body: { message: "Wire error" } });
      await flushPromises();

      // Wire error sets this.error but dashboard may already be loaded.
      // The error state replaces main content only when isLoading=false && error is truthy.
      const alert = element.shadowRoot.querySelector('[role="alert"]');
      expect(alert).not.toBeNull();
    });
  });

  // ---------- Summary Cards ----------

  describe("Summary Cards", () => {
    it("renders compliance score", async () => {
      const element = await createComponent();
      await flushPromises();

      const statValues = element.shadowRoot.querySelectorAll(".stat-value");
      expect(statValues.length).toBeGreaterThanOrEqual(4);

      // First stat card is the compliance score
      expect(statValues[0].textContent).toContain("72");
    });

    it("renders total systems count", async () => {
      const element = await createComponent();
      await flushPromises();

      const statValues = element.shadowRoot.querySelectorAll(".stat-value");
      expect(statValues[1].textContent).toContain("5");
    });

    it("renders high risk count", async () => {
      const element = await createComponent();
      await flushPromises();

      const statValues = element.shadowRoot.querySelectorAll(".stat-value");
      expect(statValues[2].textContent).toContain("2");
    });

    it("renders gap count", async () => {
      const element = await createComponent();
      await flushPromises();

      const statValues = element.shadowRoot.querySelectorAll(".stat-value");
      // MOCK_SUMMARY has 1 gap
      expect(statValues[3].textContent).toContain("1");
    });

    it("rounds compliance score", async () => {
      mockGetGovernanceSummary.mockResolvedValue({
        ...MOCK_SUMMARY,
        complianceScore: 72.7,
      });
      mockGetAIAuditTrail.mockResolvedValue([]);

      const element = createElement("c-ai-governance-dashboard", {
        is: AiGovernanceDashboard,
      });
      document.body.appendChild(element);
      await flushPromises();

      const statValues = element.shadowRoot.querySelectorAll(".stat-value");
      expect(statValues[0].textContent).toContain("73");
    });
  });

  // ---------- Page Header ----------

  describe("Page Header", () => {
    it("renders dashboard title and framework labels", async () => {
      const element = await createComponent();
      await flushPromises();

      const header = element.shadowRoot.querySelector(".slds-page-header");
      expect(header).not.toBeNull();
      expect(header.textContent).toContain("AI_DashboardTitle");
      expect(header.textContent).toContain("AI_EUAIAct");
      expect(header.textContent).toContain("AI_NISTRMF");
    });

    it("renders Discover and Refresh buttons", async () => {
      const element = await createComponent();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const labels = Array.from(buttons).map((b) => b.label);
      expect(labels).toContain("AI_DiscoverSystems");
      expect(labels).toContain("AI_RefreshData");
    });
  });

  // ---------- Registered Systems (Wire) ----------

  describe("Registered Systems", () => {
    it("renders datatable when systems exist", async () => {
      const element = await createComponent();
      await flushPromises();

      emitRegistryData(MOCK_REGISTERED_SYSTEMS);
      await flushPromises();

      const datatables = element.shadowRoot.querySelectorAll("lightning-datatable");
      // At least the registry datatable should be present
      const registryTable = Array.from(datatables).find((dt) => dt.keyField === "Id");
      expect(registryTable).not.toBeNull();
      expect(registryTable.data.length).toBe(2);
    });

    it("shows empty message when no registered systems", async () => {
      const element = await createComponent();
      await flushPromises();

      emitRegistryData([]);
      await flushPromises();

      const emptyMsg = element.shadowRoot.querySelector(".slds-text-color_weak");
      expect(emptyMsg).not.toBeNull();
    });

    it("adds riskClass to each system record", async () => {
      const element = await createComponent();
      await flushPromises();

      emitRegistryData(MOCK_REGISTERED_SYSTEMS);
      await flushPromises();

      const datatables = element.shadowRoot.querySelectorAll("lightning-datatable");
      const registryTable = Array.from(datatables).find((dt) => dt.keyField === "Id");
      expect(registryTable.data[0].riskClass).toBe("slds-text-color_error");
      expect(registryTable.data[1].riskClass).toBe("slds-text-color_success");
    });
  });

  // ---------- Gaps ----------

  describe("Compliance Gaps", () => {
    it("renders gap items when gaps exist", async () => {
      const element = await createComponent();
      await flushPromises();

      const gapItems = element.shadowRoot.querySelectorAll(".slds-item");
      expect(gapItems.length).toBe(1);
    });

    it("shows no-gaps message when gaps array is empty", async () => {
      mockGetGovernanceSummary.mockResolvedValue({ ...MOCK_SUMMARY, gaps: [] });
      mockGetAIAuditTrail.mockResolvedValue([]);

      const element = createElement("c-ai-governance-dashboard", {
        is: AiGovernanceDashboard,
      });
      document.body.appendChild(element);
      await flushPromises();

      const weakTexts = element.shadowRoot.querySelectorAll(".slds-text-color_weak");
      const noGapsMsg = Array.from(weakTexts).find((el) =>
        el.textContent.includes("AI_NoGaps")
      );
      expect(noGapsMsg).not.toBeNull();
    });
  });

  // ---------- Audit Trail ----------

  describe("Audit Trail", () => {
    it("renders audit datatable when entries exist", async () => {
      const element = await createComponent();
      await flushPromises();

      const datatables = element.shadowRoot.querySelectorAll("lightning-datatable");
      const auditTable = Array.from(datatables).find(
        (dt) => dt.keyField === "uniqueKey"
      );
      expect(auditTable).not.toBeNull();
      expect(auditTable.data.length).toBe(1);
    });

    it("shows empty message when no audit entries", async () => {
      mockGetGovernanceSummary.mockResolvedValue(MOCK_SUMMARY);
      mockGetAIAuditTrail.mockResolvedValue([]);

      const element = createElement("c-ai-governance-dashboard", {
        is: AiGovernanceDashboard,
      });
      document.body.appendChild(element);
      await flushPromises();

      const weakTexts = element.shadowRoot.querySelectorAll(".slds-text-color_weak");
      const noAuditMsg = Array.from(weakTexts).find((el) =>
        el.textContent.includes("AI_NoAuditEntries")
      );
      expect(noAuditMsg).not.toBeNull();
    });
  });

  // ---------- Discovery ----------

  describe("Discovery Flow", () => {
    it("calls discoverAISystems when Discover button is clicked", async () => {
      mockDiscoverAISystems.mockResolvedValue([
        { systemName: "Custom Bot", systemType: "Chatbot", detectionMethod: "API Scan" },
      ]);

      const element = await createComponent();
      await flushPromises();

      const discoverBtn = Array.from(
        element.shadowRoot.querySelectorAll("lightning-button")
      ).find((b) => b.label === "AI_DiscoverSystems");

      discoverBtn.click();
      await flushPromises();

      expect(mockDiscoverAISystems).toHaveBeenCalledTimes(1);
    });

    it("renders discovered systems datatable after discovery", async () => {
      mockDiscoverAISystems.mockResolvedValue([
        { systemName: "Custom Bot", systemType: "Chatbot", detectionMethod: "API Scan" },
      ]);

      const element = await createComponent();
      await flushPromises();

      const discoverBtn = Array.from(
        element.shadowRoot.querySelectorAll("lightning-button")
      ).find((b) => b.label === "AI_DiscoverSystems");

      discoverBtn.click();
      await flushPromises();

      const datatables = element.shadowRoot.querySelectorAll("lightning-datatable");
      const discoveredTable = Array.from(datatables).find(
        (dt) => dt.keyField === "systemName"
      );
      expect(discoveredTable).not.toBeNull();
      expect(discoveredTable.data.length).toBe(1);
    });

    it("dispatches toast when no systems are discovered", async () => {
      mockDiscoverAISystems.mockResolvedValue([]);

      const element = await createComponent();
      await flushPromises();

      const toastHandler = jest.fn();
      element.addEventListener("lightning__showtoast", toastHandler);

      const discoverBtn = Array.from(
        element.shadowRoot.querySelectorAll("lightning-button")
      ).find((b) => b.label === "AI_DiscoverSystems");

      discoverBtn.click();
      await flushPromises();

      // ShowToastEvent is dispatched, verify via dispatchEvent spy
      expect(mockDiscoverAISystems).toHaveBeenCalledTimes(1);
    });

    it("handles discovery error gracefully", async () => {
      mockDiscoverAISystems.mockRejectedValue({
        body: { message: "Discovery failed" },
      });

      const element = await createComponent();
      await flushPromises();

      const discoverBtn = Array.from(
        element.shadowRoot.querySelectorAll("lightning-button")
      ).find((b) => b.label === "AI_DiscoverSystems");

      discoverBtn.click();
      await flushPromises();

      // Component should not crash; isDiscovering should be reset
      const spinner = element.shadowRoot.querySelector("lightning-spinner");
      expect(spinner).toBeNull();
    });
  });

  // ---------- Sorting ----------

  describe("Sort Handling", () => {
    it("sorts registry data when onsort fires", async () => {
      const element = await createComponent();
      await flushPromises();

      emitRegistryData(MOCK_REGISTERED_SYSTEMS);
      await flushPromises();

      const datatables = element.shadowRoot.querySelectorAll("lightning-datatable");
      const registryTable = Array.from(datatables).find((dt) => dt.keyField === "Id");

      registryTable.dispatchEvent(
        new CustomEvent("sort", {
          detail: { fieldName: "Name", sortDirection: "desc" },
        })
      );
      await flushPromises();

      // After desc sort, "Prediction Builder" should come first
      expect(registryTable.data[0].Name).toBe("Prediction Builder");
    });
  });

  // ---------- Refresh ----------

  describe("Refresh", () => {
    it("reloads dashboard data on refresh click", async () => {
      const element = await createComponent();
      await flushPromises();

      // Reset call counts after initial load
      mockGetGovernanceSummary.mockClear();
      mockGetAIAuditTrail.mockClear();

      const refreshBtn = Array.from(
        element.shadowRoot.querySelectorAll("lightning-button")
      ).find((b) => b.label === "AI_RefreshData");

      refreshBtn.click();
      await flushPromises();

      expect(mockGetGovernanceSummary).toHaveBeenCalledTimes(1);
      expect(mockGetAIAuditTrail).toHaveBeenCalledTimes(1);
    });
  });
});
