/**
 * Jest tests for JiraIssueCard component
 *
 * Tests cover:
 * - Initial render states (no issue, with issue, error)
 * - Wire adapter data handling
 * - Issue details display
 * - Action buttons (Refresh, Sync, Comment, Transition)
 * - Comment modal
 * - Transition modal
 * - Error handling
 */

// @ts-ignore - LWC1702 false positive for Jest test files
import { createElement } from "lwc";
import JiraIssueCard from "c/jiraIssueCard";

// Store callbacks for wire adapter simulation - must be global for hoisted mocks
const mockWireCallbacks = new Set();

// Mock wire adapters - class must be defined inside factory to avoid hoisting issues
jest.mock(
  "@salesforce/apex/JiraIntegrationService.getIssueStatus",
  () => ({
    default: class {
      constructor(callback) {
        this._callback = callback;
        if (typeof callback === "function") {
          mockWireCallbacks.add(callback);
        }
      }
      connect() {}
      disconnect() {
        mockWireCallbacks.delete(this._callback);
      }
      update() {}
    },
  }),
  { virtual: true }
);

// Mock imperative Apex methods - variables to control mock behavior
let mockSyncResult = {};
let mockSyncError = null;
let mockCommentResult = {};
let mockCommentError = null;
let mockTransitionsResult = [];
let mockTransitionsError = null;
let mockTransitionResult = {};
let mockTransitionError = null;

jest.mock(
  "@salesforce/apex/JiraIntegrationService.syncIssueStatus",
  () => ({
    default: jest.fn((params) => {
      if (mockSyncError) return Promise.reject(mockSyncError);
      return Promise.resolve(mockSyncResult);
    }),
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/JiraIntegrationService.addComment",
  () => ({
    default: jest.fn((params) => {
      if (mockCommentError) return Promise.reject(mockCommentError);
      return Promise.resolve(mockCommentResult);
    }),
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/JiraIntegrationService.getAvailableTransitions",
  () => ({
    default: jest.fn((params) => {
      if (mockTransitionsError) return Promise.reject(mockTransitionsError);
      return Promise.resolve(mockTransitionsResult);
    }),
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/JiraIntegrationService.transitionIssue",
  () => ({
    default: jest.fn((params) => {
      if (mockTransitionError) return Promise.reject(mockTransitionError);
      return Promise.resolve(mockTransitionResult);
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
const MOCK_ISSUE = {
  key: "COMPLIANCE-123",
  summary: "Missing MFA for admin users",
  status: "In Progress",
  priority: "High",
  assignee: "John Doe",
  url: "https://jira.example.com/browse/COMPLIANCE-123",
  createdAt: "2025-01-10T10:00:00.000Z",
  updatedAt: "2025-01-15T14:30:00.000Z",
};

const MOCK_TRANSITIONS = [
  { id: "11", name: "To Do" },
  { id: "21", name: "In Progress" },
  { id: "31", name: "Done" },
];

// Helper to emit data to wire adapters
function emitWireData(data) {
  mockWireCallbacks.forEach((callback) => {
    if (typeof callback === "function") {
      callback({ data, error: undefined });
    }
  });
}

// Helper to emit error to wire adapters
function emitWireError(error) {
  mockWireCallbacks.forEach((callback) => {
    if (typeof callback === "function") {
      callback({ data: undefined, error });
    }
  });
}

describe("c-jira-issue-card", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockWireCallbacks.clear();
    mockSyncResult = {};
    mockSyncError = null;
    mockCommentResult = {};
    mockCommentError = null;
    mockTransitionsResult = MOCK_TRANSITIONS;
    mockTransitionsError = null;
    mockTransitionResult = {};
    mockTransitionError = null;
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
  }

  async function createComponent(props = {}) {
    const element = createElement("c-jira-issue-card", {
      is: JiraIssueCard,
    });
    Object.assign(element, {
      recordId: props.recordId || "a00test123",
      jiraKey: props.jiraKey || null,
      jiraUrl: props.jiraUrl || null,
    });
    document.body.appendChild(element);
    await flushPromises();
    return element;
  }

  describe("Initial Render", () => {
    it("renders the lightning card with correct title", async () => {
      const element = await createComponent();
      const card = element.shadowRoot.querySelector("lightning-card");
      expect(card).not.toBeNull();
      expect(card.title).toBe("Jira Issue");
    });

    it("renders Open in Jira button in card actions", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const openButton = Array.from(buttons).find((btn) => btn.label === "Open in Jira");
      expect(openButton).not.toBeNull();
    });
  });

  describe("No Issue State", () => {
    it("shows no issue linked message when jiraKey is null", async () => {
      const element = await createComponent();

      const noIssueText = element.shadowRoot.textContent;
      expect(noIssueText).toContain("No Jira issue linked");
    });

    it("displays link icon when no issue", async () => {
      const element = await createComponent();
      await flushPromises(); // Extra flush to ensure template renders

      // Try querying all lightning-icons first
      const allIcons = element.shadowRoot.querySelectorAll("lightning-icon");
      
      // Find the one with utility:link
      const linkIcon = Array.from(allIcons).find(icon => icon.iconName === "utility:link");
      expect(linkIcon).not.toBeNull();
    });

    it("disables Open in Jira button when no issue", async () => {
      const element = await createComponent();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const openButton = Array.from(buttons).find((btn) => btn.label === "Open in Jira");
      expect(openButton.disabled).toBe(true);
    });
  });

  describe("Wire Adapter - Issue Status", () => {
    it("displays issue details when data is returned", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const textContent = element.shadowRoot.textContent;
      expect(textContent).toContain("COMPLIANCE-123");
    });

    it("displays issue summary", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const textContent = element.shadowRoot.textContent;
      expect(textContent).toContain("Missing MFA for admin users");
    });

    it("displays issue status badge", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const textContent = element.shadowRoot.textContent;
      expect(textContent).toContain("In Progress");
    });

    it("displays priority with icon", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const textContent = element.shadowRoot.textContent;
      expect(textContent).toContain("High");
    });

    it("displays assignee", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const textContent = element.shadowRoot.textContent;
      expect(textContent).toContain("John Doe");
    });

    it("handles wire adapter error", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireError({ body: { message: "Failed to load issue" } });
      await flushPromises();

      const errorAlert = element.shadowRoot.querySelector(".slds-alert_error");
      expect(errorAlert).not.toBeNull();
    });
  });

  describe("Issue Action Buttons", () => {
    it("renders Refresh button", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const refreshButton = Array.from(buttons).find((btn) => btn.label === "Refresh");
      expect(refreshButton).not.toBeNull();
    });

    it("renders Sync button", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const syncButton = Array.from(buttons).find((btn) => btn.label === "Sync");
      expect(syncButton).not.toBeNull();
    });

    it("renders Add Comment button", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const commentButton = Array.from(buttons).find((btn) => btn.label === "Add Comment");
      expect(commentButton).not.toBeNull();
    });

    it("renders Transition button", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const transitionButton = Array.from(buttons).find((btn) => btn.label === "Transition");
      expect(transitionButton).not.toBeNull();
    });
  });

  describe("Sync Functionality", () => {
    it("calls syncIssueStatus when Sync is clicked", async () => {
      const element = await createComponent({
        recordId: "a00test123",
        jiraKey: "COMPLIANCE-123",
      });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const syncButton = Array.from(buttons).find((btn) => btn.label === "Sync");
      syncButton.click();
      await flushPromises();

      const syncIssueStatus = require("@salesforce/apex/JiraIntegrationService.syncIssueStatus").default;
      expect(syncIssueStatus).toHaveBeenCalledWith({ gapId: "a00test123" });
    });
  });

  describe("Comment Modal", () => {
    it("opens comment modal when Add Comment is clicked", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const commentButton = Array.from(buttons).find((btn) => btn.label === "Add Comment");
      commentButton.click();
      await flushPromises();

      const modal = element.shadowRoot.querySelector('[role="dialog"]');
      expect(modal).not.toBeNull();
    });

    it("modal has textarea for comment", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const commentButton = Array.from(buttons).find((btn) => btn.label === "Add Comment");
      commentButton.click();
      await flushPromises();

      const textarea = element.shadowRoot.querySelector("lightning-textarea");
      expect(textarea).not.toBeNull();
    });

    it("closes modal when Cancel is clicked", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const commentButton = Array.from(buttons).find((btn) => btn.label === "Add Comment");
      commentButton.click();
      await flushPromises();

      const modalButtons = element.shadowRoot.querySelectorAll(
        ".slds-modal__footer lightning-button"
      );
      const cancelButton = Array.from(modalButtons).find((btn) => btn.label === "Cancel");
      cancelButton.click();
      await flushPromises();

      const modal = element.shadowRoot.querySelector('[role="dialog"]');
      expect(modal).toBeNull();
    });

    it("calls addComment when submitting", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const commentButton = Array.from(buttons).find((btn) => btn.label === "Add Comment");
      commentButton.click();
      await flushPromises();

      // Enter comment
      const textarea = element.shadowRoot.querySelector("lightning-textarea");
      textarea.value = "Test comment";
      textarea.dispatchEvent(new CustomEvent("change", { target: { value: "Test comment" } }));
      await flushPromises();

      const modalButtons = element.shadowRoot.querySelectorAll(
        ".slds-modal__footer lightning-button"
      );
      const submitButton = Array.from(modalButtons).find(
        (btn) => btn.variant === "brand"
      );
      submitButton.click();
      await flushPromises();

      const addComment = require("@salesforce/apex/JiraIntegrationService.addComment").default;
      expect(addComment).toHaveBeenCalled();
    });
  });

  describe("Transition Modal", () => {
    it("opens transition modal when Transition is clicked", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const transitionButton = Array.from(buttons).find((btn) => btn.label === "Transition");
      transitionButton.click();
      await flushPromises();

      const modal = element.shadowRoot.querySelector('[role="dialog"]');
      expect(modal).not.toBeNull();
    });

    it("fetches available transitions", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const transitionButton = Array.from(buttons).find((btn) => btn.label === "Transition");
      transitionButton.click();
      await flushPromises();

      const getAvailableTransitions = require("@salesforce/apex/JiraIntegrationService.getAvailableTransitions").default;
      expect(getAvailableTransitions).toHaveBeenCalledWith({ jiraKey: "COMPLIANCE-123" });
    });

    it("modal has combobox for transitions", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const transitionButton = Array.from(buttons).find((btn) => btn.label === "Transition");
      transitionButton.click();
      await flushPromises();
      await flushPromises();

      const combobox = element.shadowRoot.querySelector("lightning-combobox");
      expect(combobox).not.toBeNull();
    });

    it("shows current status in transition modal", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const transitionButton = Array.from(buttons).find((btn) => btn.label === "Transition");
      transitionButton.click();
      await flushPromises();
      await flushPromises();

      const modalContent = element.shadowRoot.querySelector(".slds-modal__content");
      expect(modalContent.textContent).toContain("In Progress");
    });
  });

  describe("Status Styling", () => {
    it("applies success theme for done status", async () => {
      const doneIssue = { ...MOCK_ISSUE, status: "Done" };
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(doneIssue);
      await flushPromises();
      await flushPromises();

      const statusBadge = element.shadowRoot.querySelector(".slds-theme_success");
      expect(statusBadge).not.toBeNull();
    });

    it("applies warning theme for in progress status", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE); // status: "In Progress"
      await flushPromises();
      await flushPromises();

      const statusBadge = element.shadowRoot.querySelector(".slds-theme_warning");
      expect(statusBadge).not.toBeNull();
    });
  });

  describe("Priority Icon", () => {
    it("shows arrowup icon for high priority", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE); // priority: "High"
      await flushPromises();
      await flushPromises();

      const icons = element.shadowRoot.querySelectorAll("lightning-icon");
      const arrowUp = Array.from(icons).find(
        (icon) => icon.iconName === "utility:arrowup"
      );
      expect(arrowUp).not.toBeNull();
    });

    it("shows arrowdown icon for low priority", async () => {
      const lowIssue = { ...MOCK_ISSUE, priority: "Low" };
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(lowIssue);
      await flushPromises();
      await flushPromises();

      const icons = element.shadowRoot.querySelectorAll("lightning-icon");
      const arrowDown = Array.from(icons).find(
        (icon) => icon.iconName === "utility:arrowdown"
      );
      expect(arrowDown).not.toBeNull();
    });
  });

  describe("Date Formatting", () => {
    it("formats created date", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const textContent = element.shadowRoot.textContent;
      // Should contain formatted date (locale-dependent)
      expect(textContent).toContain("2025");
    });
  });

  describe("Error Handling", () => {
    it("handles sync error gracefully", async () => {
      mockSyncError = { body: { message: "Sync failed" } };

      const element = await createComponent({
        recordId: "a00test123",
        jiraKey: "COMPLIANCE-123",
      });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const syncButton = Array.from(buttons).find((btn) => btn.label === "Sync");
      syncButton.click();
      await flushPromises();

      // Component should still be functional
      expect(element.shadowRoot.querySelector("lightning-card")).not.toBeNull();
      
      // Reset
      mockSyncError = null;
    });

    it("handles comment error gracefully", async () => {
      mockCommentError = { body: { message: "Comment failed" } };

      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const commentButton = Array.from(buttons).find((btn) => btn.label === "Add Comment");
      commentButton.click();
      await flushPromises();

      const textarea = element.shadowRoot.querySelector("lightning-textarea");
      textarea.value = "Test";
      textarea.dispatchEvent(new CustomEvent("change", { target: { value: "Test" } }));
      await flushPromises();

      const modalButtons = element.shadowRoot.querySelectorAll(
        ".slds-modal__footer lightning-button"
      );
      const submitButton = Array.from(modalButtons).find((btn) => btn.variant === "brand");
      submitButton.click();
      await flushPromises();

      // Component should still be functional
      expect(element.shadowRoot.querySelector("lightning-card")).not.toBeNull();
      
      // Reset
      mockCommentError = null;
    });
  });

  describe("Accessibility", () => {
    it("uses semantic role=dialog for modals", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireData(MOCK_ISSUE);
      await flushPromises();
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const commentButton = Array.from(buttons).find((btn) => btn.label === "Add Comment");
      commentButton.click();
      await flushPromises();

      const modal = element.shadowRoot.querySelector('[role="dialog"]');
      expect(modal).not.toBeNull();
    });

    it("error alert has role=alert", async () => {
      const element = await createComponent({ jiraKey: "COMPLIANCE-123" });
      emitWireError({ body: { message: "Error" } });
      await flushPromises();

      const alert = element.shadowRoot.querySelector('[role="alert"]');
      expect(alert).not.toBeNull();
    });
  });
});
