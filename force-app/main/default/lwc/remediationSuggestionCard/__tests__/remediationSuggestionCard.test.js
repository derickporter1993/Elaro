/**
 * Jest tests for RemediationSuggestionCard component
 *
 * Tests cover:
 * - Initial render states
 * - Wire adapter data handling
 * - Suggestion categorization (pending, approved, processed)
 * - Approve/Reject workflow
 * - Execute/Manual apply workflow
 * - Generate suggestions
 * - Modal functionality
 * - Error handling
 */

// @ts-ignore - LWC1702 false positive for Jest test files
import { createElement } from "lwc";
import RemediationSuggestionCard from "c/remediationSuggestionCard";

// Store callbacks for wire adapter simulation - must be global for hoisted mocks
const mockSuggestionsCallbacks = new Set();

// Mock wire adapter - class must be defined inside factory to avoid hoisting issues
jest.mock(
  "@salesforce/apex/RemediationSuggestionService.getSuggestions",
  () => ({
    default: class {
      constructor(callback) {
        this._callback = callback;
        if (typeof callback === "function") {
          mockSuggestionsCallbacks.add(callback);
        }
      }
      connect() {}
      disconnect() {
        mockSuggestionsCallbacks.delete(this._callback);
      }
      update() {}
    },
  }),
  { virtual: true }
);

// Helper to emit data to wire adapter
function emitSuggestionsData(data) {
  mockSuggestionsCallbacks.forEach((callback) => {
    if (typeof callback === "function") {
      callback({ data, error: undefined });
    }
  });
}

// Helper to emit error to wire adapter
function emitSuggestionsError(error) {
  mockSuggestionsCallbacks.forEach((callback) => {
    if (typeof callback === "function") {
      callback({ data: undefined, error });
    }
  });
}

// Mock imperative Apex methods - variables to control mock behavior
let mockGenerateResult = {};
let mockGenerateError = null;
let mockApproveResult = {};
let mockApproveError = null;
let mockRejectResult = {};
let mockRejectError = null;
let mockExecuteResult = { success: true, message: "Success" };
let mockExecuteError = null;
let mockMarkAppliedResult = {};
let mockMarkAppliedError = null;

jest.mock(
  "@salesforce/apex/RemediationSuggestionService.generateSuggestions",
  () => ({
    default: jest.fn((params) => {
      if (mockGenerateError) return Promise.reject(mockGenerateError);
      return Promise.resolve(mockGenerateResult);
    }),
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/RemediationSuggestionService.approveSuggestion",
  () => ({
    default: jest.fn((params) => {
      if (mockApproveError) return Promise.reject(mockApproveError);
      return Promise.resolve(mockApproveResult);
    }),
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/RemediationSuggestionService.rejectSuggestion",
  () => ({
    default: jest.fn((params) => {
      if (mockRejectError) return Promise.reject(mockRejectError);
      return Promise.resolve(mockRejectResult);
    }),
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/RemediationExecutor.executeRemediation",
  () => ({
    default: jest.fn((params) => {
      if (mockExecuteError) return Promise.reject(mockExecuteError);
      return Promise.resolve(mockExecuteResult);
    }),
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/RemediationExecutor.markAsManuallyApplied",
  () => ({
    default: jest.fn((params) => {
      if (mockMarkAppliedError) return Promise.reject(mockMarkAppliedError);
      return Promise.resolve(mockMarkAppliedResult);
    }),
  }),
  { virtual: true }
);

// Mock refreshApex
jest.mock(
  "@salesforce/apex",
  () => ({
    refreshApex: jest.fn().mockResolvedValue({}),
  }),
  { virtual: true }
);

// Mock ShowToastEvent - must return a valid Event
jest.mock(
  "lightning/platformShowToastEvent",
  () => ({
    ShowToastEvent: function (config) {
      return new CustomEvent("lightning__showtoast", { detail: config });
    },
  }),
  { virtual: true }
);

// Sample test data
const MOCK_PENDING_SUGGESTION = {
  Id: "sug001",
  Name: "Suggestion 1",
  Suggestion_Type__c: "PERMISSION_CHANGE",
  Description__c: "Remove elevated permissions",
  Implementation_Steps__c: "1. Navigate to Setup\n2. Remove permission",
  Auto_Remediation_Available__c: true,
  Status__c: "PENDING",
  Confidence_Score__c: 0.95,
  Risk_Reduction_Score__c: 8,
  Effort_Estimate__c: "LOW",
  Priority_Score__c: 85,
  Framework__c: "SOX",
};

const MOCK_APPROVED_SUGGESTION = {
  Id: "sug002",
  Name: "Suggestion 2",
  Suggestion_Type__c: "FIELD_LEVEL_SECURITY",
  Description__c: "Enable field encryption",
  Implementation_Steps__c: "1. Enable encryption\n2. Test",
  Auto_Remediation_Available__c: true,
  Status__c: "APPROVED",
  Confidence_Score__c: 0.88,
  Risk_Reduction_Score__c: 7,
  Effort_Estimate__c: "MEDIUM",
  Priority_Score__c: 75,
  Framework__c: "HIPAA",
  Reviewed_By__r: { Name: "Admin User" },
  Reviewed_At__c: "2025-01-15T10:00:00.000Z",
};

const MOCK_APPLIED_SUGGESTION = {
  Id: "sug003",
  Name: "Suggestion 3",
  Suggestion_Type__c: "SHARING_RULE",
  Description__c: "Updated sharing rules",
  Status__c: "APPLIED",
  Applied_By__r: { Name: "Admin User" },
  Applied_At__c: "2025-01-15T11:00:00.000Z",
};

const MOCK_REJECTED_SUGGESTION = {
  Id: "sug004",
  Name: "Suggestion 4",
  Suggestion_Type__c: "MANUAL_REVIEW",
  Description__c: "Review access patterns",
  Status__c: "REJECTED",
  Rejection_Reason__c: "Not applicable to our use case",
};

const MOCK_ALL_SUGGESTIONS = [
  MOCK_PENDING_SUGGESTION,
  MOCK_APPROVED_SUGGESTION,
  MOCK_APPLIED_SUGGESTION,
  MOCK_REJECTED_SUGGESTION,
];

describe("c-remediation-suggestion-card", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockSuggestionsCallbacks.clear();
    mockGenerateResult = {};
    mockGenerateError = null;
    mockApproveResult = {};
    mockApproveError = null;
    mockRejectResult = {};
    mockRejectError = null;
    mockExecuteResult = { success: true, message: "Success" };
    mockExecuteError = null;
    mockMarkAppliedResult = {};
    mockMarkAppliedError = null;
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
  }

  async function createComponent(recordId = "a00test123") {
    const element = createElement("c-remediation-suggestion-card", {
      is: RemediationSuggestionCard,
    });
    element.recordId = recordId;
    document.body.appendChild(element);
    await flushPromises();
    return element;
  }

  describe("Initial Render", () => {
    it("renders the lightning card with correct title", async () => {
      const element = await createComponent();
      const card = element.shadowRoot.querySelector("lightning-card");
      expect(card).not.toBeNull();
      expect(card.title).toBe("AI-Assisted Remediation");
    });

    it("renders Generate Suggestions button", async () => {
      const element = await createComponent();
      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const generateButton = Array.from(buttons).find(
        (btn) => btn.label === "Generate Suggestions"
      );
      expect(generateButton).not.toBeNull();
    });

    it("renders Refresh button", async () => {
      const element = await createComponent();
      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const refreshButton = Array.from(buttons).find((btn) => btn.label === "Refresh");
      expect(refreshButton).not.toBeNull();
    });
  });

  describe("Empty State", () => {
    it("shows empty state when no suggestions", async () => {
      const element = await createComponent();
      emitSuggestionsData([]);
      await flushPromises();
      await flushPromises();

      const emptyState = element.shadowRoot.querySelector(".slds-illustration");
      expect(emptyState).not.toBeNull();
    });

    it("empty state shows appropriate message", async () => {
      const element = await createComponent();
      emitSuggestionsData([]);
      await flushPromises();
      await flushPromises();

      const heading = element.shadowRoot.querySelector("h3");
      expect(heading.textContent).toContain("No Suggestions");
    });
  });

  describe("Wire Adapter - Suggestions", () => {
    it("displays suggestions when data is returned", async () => {
      const element = await createComponent();
      emitSuggestionsData(MOCK_ALL_SUGGESTIONS);
      await flushPromises();
      await flushPromises();

      const cards = element.shadowRoot.querySelectorAll("article.slds-card");
      expect(cards.length).toBeGreaterThan(0);
    });

    it("handles wire adapter error", async () => {
      const element = await createComponent();
      emitSuggestionsError({ body: { message: "Error loading suggestions" } });
      await flushPromises();

      // Component should still render
      expect(element.shadowRoot.querySelector("lightning-card")).not.toBeNull();
    });
  });

  describe("Suggestion Categorization", () => {
    it("shows pending suggestions section", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const pendingSection = element.shadowRoot.querySelector(".slds-section");
      expect(pendingSection).not.toBeNull();
    });

    it("shows approved suggestions section", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_APPROVED_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const approvedTheme = element.shadowRoot.querySelector(".slds-theme_success");
      expect(approvedTheme).not.toBeNull();
    });

    it("shows processed suggestions section", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_APPLIED_SUGGESTION, MOCK_REJECTED_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      // Check for history section items
      const historyItems = element.shadowRoot.querySelectorAll(".slds-box_x-small");
      expect(historyItems.length).toBeGreaterThan(0);
    });
  });

  describe("Pending Suggestion Actions", () => {
    it("renders Approve button for pending suggestions", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();
      await flushPromises(); // Extra flush for template reactivity

      // Query all buttons and find by label
      const allButtons = element.shadowRoot.querySelectorAll("lightning-button");
      const approveButton = Array.from(allButtons).find(btn => btn.label === "Approve");
      
      expect(approveButton).not.toBeNull();
    });

    it("renders Reject button for pending suggestions", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();
      await flushPromises();

      const allButtons = element.shadowRoot.querySelectorAll("lightning-button");
      const rejectButton = Array.from(allButtons).find(btn => btn.label === "Reject");
      
      expect(rejectButton).not.toBeNull();
    });

    it("clicking Approve calls approveSuggestion", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const allButtons = element.shadowRoot.querySelectorAll("lightning-button");
      const approveButton = Array.from(allButtons).find(btn => btn.label === "Approve");
      approveButton.click();
      await flushPromises();

      const approveSuggestion = require("@salesforce/apex/RemediationSuggestionService.approveSuggestion").default;
      expect(approveSuggestion).toHaveBeenCalled();
    });
  });

  describe("Reject Modal", () => {
    it("opens reject modal when Reject is clicked", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const allButtons = element.shadowRoot.querySelectorAll("lightning-button");
      const rejectButton = Array.from(allButtons).find(btn => btn.label === "Reject");
      rejectButton.click();
      await flushPromises();

      const modal = element.shadowRoot.querySelector('[role="dialog"]');
      expect(modal).not.toBeNull();
    });

    it("reject modal has textarea for reason", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const allButtons = element.shadowRoot.querySelectorAll("lightning-button");
      const rejectButton = Array.from(allButtons).find(btn => btn.label === "Reject");
      rejectButton.click();
      await flushPromises();

      const textarea = element.shadowRoot.querySelector("lightning-textarea");
      expect(textarea).not.toBeNull();
    });
  });

  describe("Approved Suggestion Actions", () => {
    it("renders Execute button for approved auto-remediable suggestions", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_APPROVED_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const executeButton = Array.from(buttons).find(btn => btn.label?.includes("Execute"));
      expect(executeButton).not.toBeNull();
    });

    it("renders Mark as Manually Applied button", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_APPROVED_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const manualButton = Array.from(buttons).find((btn) =>
        btn.label?.includes("Manually Applied")
      );
      expect(manualButton).not.toBeNull();
    });
  });

  describe("Generate Suggestions", () => {
    it("calls generateSuggestions when button is clicked", async () => {
      const element = await createComponent();
      emitSuggestionsData([]);
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const generateButton = Array.from(buttons).find(
        (btn) => btn.label === "Generate Suggestions"
      );
      generateButton.click();
      await flushPromises();

      const generateSuggestions = require("@salesforce/apex/RemediationSuggestionService.generateSuggestions").default;
      expect(generateSuggestions).toHaveBeenCalledWith({ gapId: "a00test123" });
    });
  });

  describe("Suggestion Display", () => {
    it("displays suggestion type icon", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const icons = element.shadowRoot.querySelectorAll("lightning-icon");
      expect(icons.length).toBeGreaterThan(0);
    });

    it("displays confidence score", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const text = element.shadowRoot.textContent;
      expect(text).toContain("95%"); // 0.95 * 100
    });

    it("displays auto-remediable badge when available", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const badges = element.shadowRoot.querySelectorAll("lightning-badge");
      const autoRemediableBadge = Array.from(badges).find(
        (badge) => badge.label === "Auto-remediable"
      );
      expect(autoRemediableBadge).not.toBeNull();
    });

    it("displays accordion for implementation steps", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const accordion = element.shadowRoot.querySelector("lightning-accordion");
      expect(accordion).not.toBeNull();
    });
  });

  describe("Refresh Functionality", () => {
    it("calls refresh when Refresh button is clicked", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const refreshButton = Array.from(buttons).find((btn) => btn.label === "Refresh");
      refreshButton.click();
      await flushPromises();

      // Component should handle refresh without error
      expect(element.shadowRoot.querySelector("lightning-card")).not.toBeNull();
    });
  });

  describe("Error Handling", () => {
    it("handles approve error gracefully", async () => {
      mockApproveError = { body: { message: "Approval failed" } };

      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const allButtons = element.shadowRoot.querySelectorAll("lightning-button");
      const approveButton = Array.from(allButtons).find(btn => btn.label === "Approve");
      approveButton.click();
      await flushPromises();

      // Component should still be functional
      expect(element.shadowRoot.querySelector("lightning-card")).not.toBeNull();
      
      // Reset
      mockApproveError = null;
    });

    it("handles generate suggestions error gracefully", async () => {
      mockGenerateError = { body: { message: "Generation failed" } };

      const element = await createComponent();
      emitSuggestionsData([]);
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const generateButton = Array.from(buttons).find(
        (btn) => btn.label === "Generate Suggestions"
      );
      generateButton.click();
      await flushPromises();

      // Component should still be functional
      expect(element.shadowRoot.querySelector("lightning-card")).not.toBeNull();
      
      // Reset
      mockGenerateError = null;
    });
  });

  describe("Accessibility", () => {
    it("uses semantic role=dialog for modals", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const allButtons = element.shadowRoot.querySelectorAll("lightning-button");
      const rejectButton = Array.from(allButtons).find(btn => btn.label === "Reject");
      rejectButton.click();
      await flushPromises();

      const modal = element.shadowRoot.querySelector('[role="dialog"]');
      expect(modal).not.toBeNull();
    });

    it("includes assistive text for close buttons", async () => {
      const element = await createComponent();
      emitSuggestionsData([MOCK_PENDING_SUGGESTION]);
      await flushPromises();
      await flushPromises();

      const allButtons = element.shadowRoot.querySelectorAll("lightning-button");
      const rejectButton = Array.from(allButtons).find(btn => btn.label === "Reject");
      rejectButton.click();
      await flushPromises();

      const assistiveText = element.shadowRoot.querySelector(".slds-assistive-text");
      expect(assistiveText).not.toBeNull();
    });
  });
});
