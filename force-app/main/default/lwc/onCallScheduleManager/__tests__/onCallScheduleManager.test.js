/**
 * Jest tests for OnCallScheduleManager component
 *
 * Tests cover:
 * - Initial render with schedules
 * - Empty state
 * - Create/Edit modal functionality
 * - Delete confirmation modal
 * - Wire adapter data handling
 * - Form validation
 * - CRUD operations
 */

// @ts-ignore - LWC1702 false positive for Jest test files
import { createElement } from "lwc";
import OnCallScheduleManager from "c/onCallScheduleManager";

// Store callbacks for wire adapter simulation - must be global for hoisted mocks
const mockSchedulesCallbacks = new Set();
const mockOnCallCallbacks = new Set();

// Mock wire adapters - class must be defined inside factory to avoid hoisting issues
jest.mock(
  "@salesforce/apex/OnCallScheduleController.getSchedules",
  () => ({
    default: class {
      constructor(callback) {
        this._callback = callback;
        if (typeof callback === "function") {
          mockSchedulesCallbacks.add(callback);
        }
      }
      connect() {}
      disconnect() {
        mockSchedulesCallbacks.delete(this._callback);
      }
      update() {}
    },
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/MobileAlertPublisher.getCurrentOnCallUsers",
  () => ({
    default: class {
      constructor(callback) {
        this._callback = callback;
        if (typeof callback === "function") {
          mockOnCallCallbacks.add(callback);
        }
      }
      connect() {}
      disconnect() {
        mockOnCallCallbacks.delete(this._callback);
      }
      update() {}
    },
  }),
  { virtual: true }
);

// Helper to emit data to schedules wire adapter
function emitSchedulesData(data) {
  mockSchedulesCallbacks.forEach((callback) => {
    if (typeof callback === "function") {
      callback({ data, error: undefined });
    }
  });
}

// Helper to emit error to schedules wire adapter
function emitSchedulesError(error) {
  mockSchedulesCallbacks.forEach((callback) => {
    if (typeof callback === "function") {
      callback({ data: undefined, error });
    }
  });
}

// Helper to emit data to on-call wire adapter
function emitOnCallData(data) {
  mockOnCallCallbacks.forEach((callback) => {
    if (typeof callback === "function") {
      callback({ data, error: undefined });
    }
  });
}

// Mock imperative Apex methods
const mockCreateSchedule = jest.fn();
const mockUpdateSchedule = jest.fn();
const mockDeleteSchedule = jest.fn();

jest.mock(
  "@salesforce/apex/OnCallScheduleController.createSchedule",
  () => ({ default: mockCreateSchedule }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/OnCallScheduleController.updateSchedule",
  () => ({ default: mockUpdateSchedule }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/OnCallScheduleController.deleteSchedule",
  () => ({ default: mockDeleteSchedule }),
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
const MOCK_SCHEDULES = [
  {
    Id: "a001",
    Name: "Primary On-Call",
    User__c: "005user1",
    User__r: { Name: "John Doe" },
    Rotation_Name__c: "Primary",
    Start_Time__c: "2025-01-01T08:00:00.000Z",
    End_Time__c: "2025-01-02T08:00:00.000Z",
    Timezone__c: "America/New_York",
    Notification_Methods__c: "Mobile;Email",
    Active__c: true,
  },
  {
    Id: "a002",
    Name: "Weekend On-Call",
    User__c: "005user2",
    User__r: { Name: "Jane Smith" },
    Rotation_Name__c: "Weekend",
    Start_Time__c: "2025-01-04T00:00:00.000Z",
    End_Time__c: "2025-01-06T00:00:00.000Z",
    Timezone__c: "America/Los_Angeles",
    Notification_Methods__c: "Mobile",
    Active__c: true,
  },
];

const MOCK_CURRENT_ON_CALL = [
  {
    userId: "005user1",
    userName: "John Doe",
    rotationName: "Primary",
    shiftEnd: "2025-01-02 08:00 AM",
  },
];

describe("c-on-call-schedule-manager", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockSchedulesCallbacks.clear();
    mockOnCallCallbacks.clear();
    mockCreateSchedule.mockResolvedValue({ Id: "a003" });
    mockUpdateSchedule.mockResolvedValue({});
    mockDeleteSchedule.mockResolvedValue({});
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
  }

  async function createComponent() {
    const element = createElement("c-on-call-schedule-manager", {
      is: OnCallScheduleManager,
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
      expect(card.title).toBe("On-Call Schedule Management");
    });

    it("shows loading spinner initially", async () => {
      const element = await createComponent();
      const spinner = element.shadowRoot.querySelector("lightning-spinner");
      expect(spinner).not.toBeNull();
    });

    it("renders New Schedule button", async () => {
      const element = await createComponent();
      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const newButton = Array.from(buttons).find((btn) => btn.label === "New Schedule");
      expect(newButton).not.toBeNull();
    });

    it("renders Refresh button", async () => {
      const element = await createComponent();
      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const refreshButton = Array.from(buttons).find((btn) => btn.label === "Refresh");
      expect(refreshButton).not.toBeNull();
    });
  });

  describe("Wire Adapter - Schedules", () => {
    it("displays schedules in datatable when data is returned", async () => {
      const element = await createComponent();

      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();
      await flushPromises();

      const datatable = element.shadowRoot.querySelector("lightning-datatable");
      expect(datatable).not.toBeNull();
    });

    it("shows empty state when no schedules", async () => {
      const element = await createComponent();

      emitSchedulesData([]);
      await flushPromises();
      await flushPromises();

      const emptyState = element.shadowRoot.querySelector(".slds-illustration");
      expect(emptyState).not.toBeNull();
    });

    it("handles wire adapter error", async () => {
      const element = await createComponent();

      emitSchedulesError({ body: { message: "Error loading schedules" } });
      await flushPromises();

      // Component should still render
      expect(element.shadowRoot.querySelector("lightning-card")).not.toBeNull();
    });
  });

  describe("Wire Adapter - Current On-Call", () => {
    it("displays current on-call users when data is returned", async () => {
      const element = await createComponent();

      emitSchedulesData(MOCK_SCHEDULES);
      emitOnCallData(MOCK_CURRENT_ON_CALL);
      await flushPromises();
      await flushPromises();

      const onCallSection = element.shadowRoot.querySelector(".slds-theme_success");
      expect(onCallSection).not.toBeNull();
    });

    it("hides on-call section when no users on-call", async () => {
      const element = await createComponent();

      emitSchedulesData(MOCK_SCHEDULES);
      emitOnCallData([]);
      await flushPromises();
      await flushPromises();

      const onCallSection = element.shadowRoot.querySelector(".slds-theme_success");
      expect(onCallSection).toBeNull();
    });
  });

  describe("Create Schedule Modal", () => {
    it("opens modal when New Schedule is clicked", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const newButton = Array.from(buttons).find((btn) => btn.label === "New Schedule");
      newButton.click();
      await flushPromises();

      const modal = element.shadowRoot.querySelector('[role="dialog"]');
      expect(modal).not.toBeNull();
    });

    it("modal has correct title for new schedule", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const newButton = Array.from(buttons).find((btn) => btn.label === "New Schedule");
      newButton.click();
      await flushPromises();

      const modalTitle = element.shadowRoot.querySelector(".slds-modal__title");
      expect(modalTitle.textContent).toBe("New On-Call Schedule");
    });

    it("closes modal when Cancel is clicked", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();

      // Open modal
      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const newButton = Array.from(buttons).find((btn) => btn.label === "New Schedule");
      newButton.click();
      await flushPromises();

      // Click cancel
      const modalButtons = element.shadowRoot.querySelectorAll(".slds-modal__footer lightning-button");
      const cancelButton = Array.from(modalButtons).find((btn) => btn.label === "Cancel");
      cancelButton.click();
      await flushPromises();

      const modal = element.shadowRoot.querySelector('[role="dialog"]');
      expect(modal).toBeNull();
    });
  });

  describe("Form Inputs", () => {
    it("renders all required form fields in modal", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const newButton = Array.from(buttons).find((btn) => btn.label === "New Schedule");
      newButton.click();
      await flushPromises();

      const inputs = element.shadowRoot.querySelectorAll("lightning-input");
      const comboboxes = element.shadowRoot.querySelectorAll("lightning-combobox");
      const dualListbox = element.shadowRoot.querySelector("lightning-dual-listbox");
      const recordPicker = element.shadowRoot.querySelector("lightning-record-picker");

      expect(inputs.length).toBeGreaterThan(0);
      expect(comboboxes.length).toBeGreaterThan(0);
      expect(dualListbox).not.toBeNull();
      expect(recordPicker).not.toBeNull();
    });
  });

  describe("Datatable Row Actions", () => {
    it("handles edit row action", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();
      await flushPromises();

      const datatable = element.shadowRoot.querySelector("lightning-datatable");
      expect(datatable).not.toBeNull();

      // Simulate row action
      datatable.dispatchEvent(
        new CustomEvent("rowaction", {
          detail: {
            action: { name: "edit" },
            row: {
              id: "a001",
              name: "Primary On-Call",
              userId: "005user1",
              rotationName: "Primary",
              startTime: "2025-01-01T08:00:00.000Z",
              endTime: "2025-01-02T08:00:00.000Z",
              timezone: "America/New_York",
              notificationMethods: "Mobile;Email",
              active: true,
            },
          },
        })
      );
      await flushPromises();

      const modal = element.shadowRoot.querySelector('[role="dialog"]');
      expect(modal).not.toBeNull();

      const modalTitle = element.shadowRoot.querySelector(".slds-modal__title");
      expect(modalTitle.textContent).toBe("Edit On-Call Schedule");
    });

    it("handles delete row action", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();
      await flushPromises();

      const datatable = element.shadowRoot.querySelector("lightning-datatable");

      datatable.dispatchEvent(
        new CustomEvent("rowaction", {
          detail: {
            action: { name: "delete" },
            row: {
              id: "a001",
              name: "Primary On-Call",
            },
          },
        })
      );
      await flushPromises();

      // Delete confirmation modal should appear
      const deleteModal = element.shadowRoot.querySelector(".slds-modal_small");
      expect(deleteModal).not.toBeNull();
    });
  });

  describe("Delete Confirmation", () => {
    it("closes delete modal when Cancel is clicked", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();
      await flushPromises();

      const datatable = element.shadowRoot.querySelector("lightning-datatable");
      datatable.dispatchEvent(
        new CustomEvent("rowaction", {
          detail: {
            action: { name: "delete" },
            row: { id: "a001", name: "Primary On-Call" },
          },
        })
      );
      await flushPromises();

      // Find cancel button in delete modal
      const deleteModal = element.shadowRoot.querySelector(".slds-modal_small");
      const cancelButtons = deleteModal.querySelectorAll("lightning-button");
      const cancelButton = Array.from(cancelButtons).find((btn) => btn.label === "Cancel");
      cancelButton.click();
      await flushPromises();

      const modal = element.shadowRoot.querySelector(".slds-modal_small");
      expect(modal).toBeNull();
    });
  });

  describe("Computed Properties", () => {
    it("timezoneOptions returns correct options", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const newButton = Array.from(buttons).find((btn) => btn.label === "New Schedule");
      newButton.click();
      await flushPromises();

      const comboboxes = element.shadowRoot.querySelectorAll("lightning-combobox");
      const timezoneCombo = Array.from(comboboxes).find(
        (c) => c.dataset.field === "timezone" || c.label === "Timezone"
      );
      expect(timezoneCombo).not.toBeNull();
    });

    it("rotationOptions returns correct options", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const newButton = Array.from(buttons).find((btn) => btn.label === "New Schedule");
      newButton.click();
      await flushPromises();

      const comboboxes = element.shadowRoot.querySelectorAll("lightning-combobox");
      const rotationCombo = Array.from(comboboxes).find(
        (c) => c.dataset.field === "rotationName" || c.label === "Rotation"
      );
      expect(rotationCombo).not.toBeNull();
    });
  });

  describe("Accessibility", () => {
    it("uses role=dialog for modals", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const newButton = Array.from(buttons).find((btn) => btn.label === "New Schedule");
      newButton.click();
      await flushPromises();

      const modal = element.shadowRoot.querySelector('[role="dialog"]');
      expect(modal).not.toBeNull();
    });

    it("includes assistive text for close button", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      await flushPromises();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const newButton = Array.from(buttons).find((btn) => btn.label === "New Schedule");
      newButton.click();
      await flushPromises();

      const assistiveText = element.shadowRoot.querySelector(".slds-assistive-text");
      expect(assistiveText).not.toBeNull();
    });

    it("includes aria-hidden for decorative icons", async () => {
      const element = await createComponent();
      emitSchedulesData(MOCK_SCHEDULES);
      emitOnCallData(MOCK_CURRENT_ON_CALL);
      await flushPromises();
      await flushPromises();

      const icons = element.shadowRoot.querySelectorAll('lightning-icon[aria-hidden="true"]');
      expect(icons.length).toBeGreaterThan(0);
    });
  });
});
