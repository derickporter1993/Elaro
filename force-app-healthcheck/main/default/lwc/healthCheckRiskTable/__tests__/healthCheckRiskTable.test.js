import { createElement } from "lwc";
import HealthCheckRiskTable from "c/healthCheckRiskTable";

jest.mock("@salesforce/label/c.HC_FilterAll", () => ({ default: "All" }), { virtual: true });
jest.mock("@salesforce/label/c.HC_FilterHigh", () => ({ default: "High" }), { virtual: true });
jest.mock("@salesforce/label/c.HC_FilterMedium", () => ({ default: "Medium" }), { virtual: true });
jest.mock("@salesforce/label/c.HC_FilterLow", () => ({ default: "Low" }), { virtual: true });

const MOCK_FINDINGS = [
  {
    category: "SecurityHealthCheck",
    setting: "PasswordComplexity",
    currentValue: "None",
    recommendedValue: "High",
    severity: "HIGH_RISK",
    description: "Test",
  },
  {
    category: "Session",
    setting: "SessionTimeout",
    currentValue: "24h",
    recommendedValue: "2h",
    severity: "MEDIUM_RISK",
    description: "Test",
  },
  {
    category: "Permissions",
    setting: "ViewAllData",
    currentValue: "Enabled",
    recommendedValue: "Disabled",
    severity: "LOW_RISK",
    description: "Test",
  },
];

describe("c-health-check-risk-table", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function createComponent(findings = []) {
    const element = createElement("c-health-check-risk-table", {
      is: HealthCheckRiskTable,
    });
    element.findings = findings;
    document.body.appendChild(element);
    return element;
  }

  it("renders datatable with findings", async () => {
    const element = createComponent(MOCK_FINDINGS);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data.length).toBe(3);
  });

  it("renders empty state with no findings", async () => {
    const element = createComponent([]);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).toBeNull();
  });

  it("renders filter combobox", () => {
    const element = createComponent(MOCK_FINDINGS);
    const combobox = element.shadowRoot.querySelector("lightning-combobox");
    expect(combobox).not.toBeNull();
  });

  it("filters findings by severity", async () => {
    const element = createComponent(MOCK_FINDINGS);
    await flushPromises();

    const combobox = element.shadowRoot.querySelector("lightning-combobox");
    combobox.dispatchEvent(new CustomEvent("change", { detail: { value: "HIGH_RISK" } }));

    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable.data.length).toBe(1);
    expect(datatable.data[0].severity).toBe("HIGH_RISK");
  });

  it("shows all findings with ALL filter", async () => {
    const element = createComponent(MOCK_FINDINGS);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable.data.length).toBe(3);
  });

  it("handles null findings gracefully", async () => {
    const element = createComponent(null);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).toBeNull();
  });
});
