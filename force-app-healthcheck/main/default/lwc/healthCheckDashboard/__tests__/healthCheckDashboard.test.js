import { createElement } from "lwc";
import HealthCheckDashboard from "c/healthCheckDashboard";
import runFullScan from "@salesforce/apex/HealthCheckController.runFullScan";

jest.mock("@salesforce/apex/HealthCheckController.runFullScan", () => ({ default: jest.fn() }), {
  virtual: true,
});

jest.mock("@salesforce/label/c.HC_ScanInProgress", () => ({ default: "Scanning..." }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.HC_ScanComplete", () => ({ default: "Complete" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.HC_ScanFailed", () => ({ default: "Failed" }), { virtual: true });
jest.mock("@salesforce/label/c.HC_NoDataAvailable", () => ({ default: "No data" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.HC_OverallScore", () => ({ default: "Overall Score" }), {
  virtual: true,
});

const MOCK_RESULT = {
  overallScore: 72,
  categoryScores: {
    SecurityHealthCheck: 80,
    MFA: 60,
    Permissions: 70,
    Session: 90,
    AuditTrail: 50,
  },
  findings: [
    {
      category: "SecurityHealthCheck",
      setting: "PasswordComplexity",
      currentValue: "None",
      recommendedValue: "High",
      severity: "HIGH_RISK",
      description: "Test finding",
    },
  ],
  recommendations: [
    {
      title: "Enable MFA",
      description: "Enable for all users",
      setupMenuPath: "SecurityMfa/home",
      priority: 1,
      category: "MFA",
    },
  ],
  scanTimestamp: "2026-02-11T00:00:00.000Z",
  mfaPercentage: 60,
  totalUsers: 100,
  mfaUsers: 60,
};

describe("c-health-check-dashboard", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-health-check-dashboard", {
      is: HealthCheckDashboard,
    });
    document.body.appendChild(element);
    return element;
  }

  it("renders empty state by default", () => {
    const element = createComponent();
    const illustration = element.shadowRoot.querySelector(".slds-illustration");
    expect(illustration).not.toBeNull();
  });

  it("renders Run Scan button", () => {
    const element = createComponent();
    const button = element.shadowRoot.querySelector("lightning-button");
    expect(button).not.toBeNull();
    expect(button.label).toBe("Run Scan");
  });

  it("shows loading spinner during scan", async () => {
    runFullScan.mockResolvedValue(MOCK_RESULT);
    const element = createComponent();

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    await Promise.resolve();
    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();
  });

  it("renders child components after successful scan", async () => {
    runFullScan.mockResolvedValue(MOCK_RESULT);
    const element = createComponent();

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    await flushPromises();

    const gauge = element.shadowRoot.querySelector("c-health-check-score-gauge");
    expect(gauge).not.toBeNull();

    const mfa = element.shadowRoot.querySelector("c-health-check-mfa-indicator");
    expect(mfa).not.toBeNull();

    const table = element.shadowRoot.querySelector("c-health-check-risk-table");
    expect(table).not.toBeNull();

    const recs = element.shadowRoot.querySelector("c-health-check-recommendations");
    expect(recs).not.toBeNull();

    const cta = element.shadowRoot.querySelector("c-health-check-cta-banner");
    expect(cta).not.toBeNull();
  });

  it("shows error state on scan failure", async () => {
    runFullScan.mockRejectedValue({ body: { message: "Permission denied" } });
    const element = createComponent();

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    await flushPromises();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert).not.toBeNull();
    expect(alert.textContent).toContain("Permission denied");
  });
});
