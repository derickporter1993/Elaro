/**
 * Jest tests for aiGovernanceDashboard LWC component
 *
 * Tests cover:
 * - Component instantiation
 * - Loading state rendering
 * - Error state rendering
 */

import { createElement } from "lwc";
import AiGovernanceDashboard from "c/aiGovernanceDashboard";

let mockSummaryCallbacks = new Set();
let mockSystemsCallbacks = new Set();
let mockAuditCallbacks = new Set();

// Mock wire adapters
jest.mock(
  "@salesforce/apex/AIGovernanceController.getGovernanceSummary",
  () => ({
    default: function MockAdapter(callback) {
      if (new.target) {
        this.callback = callback;
        mockSummaryCallbacks.add(callback);
        this.connect = () => {};
        this.disconnect = () => {
          mockSummaryCallbacks.delete(this.callback);
        };
        this.update = () => {};
        return this;
      }
      return Promise.resolve(null);
    },
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AIGovernanceController.getRegisteredSystems",
  () => ({
    default: function MockAdapter(callback) {
      if (new.target) {
        this.callback = callback;
        mockSystemsCallbacks.add(callback);
        this.connect = () => {};
        this.disconnect = () => {
          mockSystemsCallbacks.delete(this.callback);
        };
        this.update = () => {};
        return this;
      }
      return Promise.resolve(null);
    },
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AIGovernanceController.getAIAuditTrail",
  () => ({
    default: function MockAdapter(callback) {
      if (new.target) {
        this.callback = callback;
        mockAuditCallbacks.add(callback);
        this.connect = () => {};
        this.disconnect = () => {
          mockAuditCallbacks.delete(this.callback);
        };
        this.update = () => {};
        return this;
      }
      return Promise.resolve(null);
    },
  }),
  { virtual: true }
);

// Mock imperative methods
jest.mock(
  "@salesforce/apex/AIGovernanceController.discoverAISystems",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AIGovernanceController.registerAISystem",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/AIGovernanceController.updateRiskLevel",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

// Mock refreshApex
jest.mock("@salesforce/apex", () => ({ refreshApex: jest.fn().mockResolvedValue(undefined) }), {
  virtual: true,
});

// Mock ShowToastEvent
jest.mock("lightning/platformShowToastEvent", () => ({ ShowToastEvent: jest.fn() }), {
  virtual: true,
});

// Mock all custom labels
const LABEL_MOCKS = [
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

LABEL_MOCKS.forEach((mockLabel) => {
  jest.mock(`@salesforce/label/c.${mockLabel}`, () => ({ default: mockLabel }), { virtual: true });
});

const flushPromises = () => new Promise(process.nextTick);

describe("c-ai-governance-dashboard", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    mockSummaryCallbacks.clear();
    mockSystemsCallbacks.clear();
    mockAuditCallbacks.clear();
  });

  it("creates the component successfully", () => {
    const element = createElement("c-ai-governance-dashboard", {
      is: AiGovernanceDashboard,
    });
    document.body.appendChild(element);
    expect(element).not.toBeNull();
  });

  it("renders loading spinner initially", () => {
    const element = createElement("c-ai-governance-dashboard", {
      is: AiGovernanceDashboard,
    });
    document.body.appendChild(element);

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();
  });

  it("renders error state when wire returns error", async () => {
    const element = createElement("c-ai-governance-dashboard", {
      is: AiGovernanceDashboard,
    });
    document.body.appendChild(element);

    mockSummaryCallbacks.forEach((cb) =>
      cb({ data: undefined, error: { body: { message: "Test error" } } })
    );
    await flushPromises();

    const errorDiv = element.shadowRoot.querySelector(".slds-alert_error");
    expect(errorDiv).not.toBeNull();
  });

  it("does not render page header during loading", () => {
    const element = createElement("c-ai-governance-dashboard", {
      is: AiGovernanceDashboard,
    });
    document.body.appendChild(element);

    const pageHeader = element.shadowRoot.querySelector(".slds-page-header");
    expect(pageHeader).toBeNull();
  });
});
