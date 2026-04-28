/**
 * Jest tests for vendorRiskDashboard LWC component
 *
 * Tests cover:
 * - Loading state rendering
 * - Data display with summary cards and vendor table
 * - Empty state when no vendors exist
 * - Error state rendering
 * - Filter interaction (status and type)
 */

import { createElement } from "lwc";
import VendorRiskDashboard from "c/vendorRiskDashboard";

// --- Mutable state for imperative mocks ---
let mockDashboardResult = null;
let mockDashboardError = null;
let mockFilteredResult = null;
let mockFilteredError = null;
let mockRefreshResult = null;
let mockRefreshError = null;
let mockOverdueResult = null;
let mockOverdueError = null;

jest.mock(
  "@salesforce/apex/VendorRiskController.getDashboardData",
  () => ({
    default: jest.fn(() => {
      if (mockDashboardError) return Promise.reject(mockDashboardError);
      return Promise.resolve(mockDashboardResult);
    }),
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/VendorRiskController.getFilteredVendors",
  () => ({
    default: jest.fn(() => {
      if (mockFilteredError) return Promise.reject(mockFilteredError);
      return Promise.resolve(mockFilteredResult);
    }),
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/VendorRiskController.refreshRiskScore",
  () => ({
    default: jest.fn(() => {
      if (mockRefreshError) return Promise.reject(mockRefreshError);
      return Promise.resolve(mockRefreshResult);
    }),
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/VendorRiskController.getOverdueVendors",
  () => ({
    default: jest.fn(() => {
      if (mockOverdueError) return Promise.reject(mockOverdueError);
      return Promise.resolve(mockOverdueResult);
    }),
  }),
  { virtual: true }
);

jest.mock("lightning/platformShowToastEvent", () => ({ ShowToastEvent: jest.fn() }), {
  virtual: true,
});

jest.mock("@salesforce/label/c.VR_Title", () => ({ default: "Vendor Risk Management" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.VR_Loading", () => ({ default: "Loading vendor data..." }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.VR_Error", () => ({ default: "Error" }), { virtual: true });
jest.mock("@salesforce/label/c.VR_NoData", () => ({ default: "No vendors found." }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.VR_TotalVendors", () => ({ default: "Total Vendors" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.VR_ActiveVendors", () => ({ default: "Active Vendors" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.VR_AverageRisk", () => ({ default: "Average Risk Score" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.VR_OverdueAssessments", () => ({ default: "Overdue Assessments" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.VR_HighRisk", () => ({ default: "High Risk" }), { virtual: true });
jest.mock("@salesforce/label/c.VR_FilterByStatus", () => ({ default: "Filter by Status" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.VR_FilterByType", () => ({ default: "Filter by Type" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.VR_AllStatuses", () => ({ default: "All Statuses" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.VR_AllTypes", () => ({ default: "All Types" }), { virtual: true });

const MOCK_VENDORS = [
  {
    Id: "a0x000000000001",
    Vendor_Name__c: "Test Cloud Provider",
    Vendor_Type__c: "CLOUD_SERVICE",
    Risk_Score__c: 8,
    Status__c: "ACTIVE",
    Last_Assessment_Date__c: "2025-12-01",
    Next_Assessment_Date__c: "2026-03-01",
    Data_Processing_Agreement__c: false,
  },
  {
    Id: "a0x000000000002",
    Vendor_Name__c: "Test Integrator",
    Vendor_Type__c: "INTEGRATION",
    Risk_Score__c: 2,
    Status__c: "ACTIVE",
    Last_Assessment_Date__c: "2026-01-15",
    Next_Assessment_Date__c: "2026-07-15",
    Data_Processing_Agreement__c: true,
  },
];

const MOCK_SUMMARY = {
  totalVendors: 2,
  activeVendors: 2,
  averageRiskScore: 5.0,
  overdueCount: 1,
  highRiskCount: 1,
};

const MOCK_DASHBOARD_DATA = {
  vendors: MOCK_VENDORS,
  summary: MOCK_SUMMARY,
};

// Helper to flush promises
const flushPromises = () => new Promise(process.nextTick);

describe("c-vendor-risk-dashboard", () => {
  beforeEach(() => {
    mockDashboardResult = null;
    mockDashboardError = null;
    mockFilteredResult = null;
    mockFilteredError = null;
    mockRefreshResult = null;
    mockRefreshError = null;
    mockOverdueResult = null;
    mockOverdueError = null;
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders loading state initially", () => {
    mockDashboardResult = MOCK_DASHBOARD_DATA;
    const element = createElement("c-vendor-risk-dashboard", { is: VendorRiskDashboard });
    document.body.appendChild(element);

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();
  });

  it("displays dashboard data after loading", async () => {
    mockDashboardResult = MOCK_DASHBOARD_DATA;
    const element = createElement("c-vendor-risk-dashboard", { is: VendorRiskDashboard });
    document.body.appendChild(element);

    await flushPromises();

    const statCards = element.shadowRoot.querySelectorAll(".stat-card");
    expect(statCards.length).toBe(5);

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data.length).toBe(2);
  });

  it("displays empty state when no vendors exist", async () => {
    mockDashboardResult = {
      vendors: [],
      summary: {
        totalVendors: 0,
        activeVendors: 0,
        averageRiskScore: 0,
        overdueCount: 0,
        highRiskCount: 0,
      },
    };
    const element = createElement("c-vendor-risk-dashboard", { is: VendorRiskDashboard });
    document.body.appendChild(element);

    await flushPromises();

    const emptyState = element.shadowRoot.querySelector(".slds-illustration");
    expect(emptyState).not.toBeNull();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).toBeNull();
  });

  it("displays error state on failure", async () => {
    mockDashboardError = { body: { message: "Test error message" } };
    const element = createElement("c-vendor-risk-dashboard", { is: VendorRiskDashboard });
    document.body.appendChild(element);

    await flushPromises();

    const alert = element.shadowRoot.querySelector(".slds-alert_error");
    expect(alert).not.toBeNull();
    expect(alert.textContent).toContain("Test error message");
  });

  it("filters vendors when status combobox changes", async () => {
    mockDashboardResult = MOCK_DASHBOARD_DATA;
    mockFilteredResult = [MOCK_VENDORS[0]];
    const element = createElement("c-vendor-risk-dashboard", { is: VendorRiskDashboard });
    document.body.appendChild(element);

    await flushPromises();

    const comboboxes = element.shadowRoot.querySelectorAll("lightning-combobox");
    const statusCombobox = comboboxes[0];

    statusCombobox.dispatchEvent(new CustomEvent("change", { detail: { value: "ACTIVE" } }));

    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data.length).toBe(1);
  });

  it("filters vendors when type combobox changes", async () => {
    mockDashboardResult = MOCK_DASHBOARD_DATA;
    mockFilteredResult = [MOCK_VENDORS[1]];
    const element = createElement("c-vendor-risk-dashboard", { is: VendorRiskDashboard });
    document.body.appendChild(element);

    await flushPromises();

    const comboboxes = element.shadowRoot.querySelectorAll("lightning-combobox");
    const typeCombobox = comboboxes[1];

    typeCombobox.dispatchEvent(new CustomEvent("change", { detail: { value: "INTEGRATION" } }));

    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data.length).toBe(1);
  });

  it("renders summary card values correctly", async () => {
    mockDashboardResult = MOCK_DASHBOARD_DATA;
    const element = createElement("c-vendor-risk-dashboard", { is: VendorRiskDashboard });
    document.body.appendChild(element);

    await flushPromises();

    const headings = element.shadowRoot.querySelectorAll(".slds-text-heading_large");
    const values = Array.from(headings).map((h) => h.textContent);

    expect(values).toContain("2");
    expect(values).toContain("5");
    expect(values).toContain("1");
  });
});
