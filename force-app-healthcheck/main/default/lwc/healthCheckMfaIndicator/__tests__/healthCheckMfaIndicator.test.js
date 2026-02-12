import { createElement } from "lwc";
import HealthCheckMfaIndicator from "c/healthCheckMfaIndicator";

jest.mock("@salesforce/label/c.HC_MfaAdoption", () => ({ default: "MFA Adoption" }), {
  virtual: true,
});
jest.mock(
  "@salesforce/label/c.HC_UsersOnMfa",
  () => ({ default: "{0} of {1} logins verified with MFA" }),
  { virtual: true }
);

describe("c-health-check-mfa-indicator", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function createComponent(props = {}) {
    const element = createElement("c-health-check-mfa-indicator", {
      is: HealthCheckMfaIndicator,
    });
    element.mfaPercentage = props.mfaPercentage ?? 0;
    element.totalUsers = props.totalUsers ?? 0;
    element.mfaUsers = props.mfaUsers ?? 0;
    document.body.appendChild(element);
    return element;
  }

  it("displays percentage value", () => {
    const element = createComponent({ mfaPercentage: 75, totalUsers: 100, mfaUsers: 75 });
    const percentage = element.shadowRoot.querySelector(".mfa-percentage");
    expect(percentage.textContent).toBe("75%");
  });

  it("displays user count label", async () => {
    const element = createComponent({ mfaPercentage: 60, totalUsers: 200, mfaUsers: 120 });
    await flushPromises();

    const label = element.shadowRoot.querySelector("p");
    expect(label.textContent).toContain("120");
    expect(label.textContent).toContain("200");
  });

  it("has accessible role and aria-label", () => {
    const element = createComponent({ mfaPercentage: 80, totalUsers: 50, mfaUsers: 40 });
    const container = element.shadowRoot.querySelector('[role="img"]');
    expect(container).not.toBeNull();
    expect(container.getAttribute("aria-label")).toContain("80");
  });

  it("renders SVG progress ring", () => {
    const element = createComponent({ mfaPercentage: 50 });
    const circles = element.shadowRoot.querySelectorAll("circle");
    expect(circles.length).toBe(2);
  });

  it("clamps percentage to 0-100", () => {
    const element = createComponent({ mfaPercentage: 150 });
    const percentage = element.shadowRoot.querySelector(".mfa-percentage");
    expect(percentage.textContent).toBe("100%");
  });

  it("handles zero percentage", () => {
    const element = createComponent({ mfaPercentage: 0, totalUsers: 100, mfaUsers: 0 });
    const percentage = element.shadowRoot.querySelector(".mfa-percentage");
    expect(percentage.textContent).toBe("0%");
  });
});
