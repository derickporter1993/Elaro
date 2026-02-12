import { createElement } from "lwc";
import HealthCheckCtaBanner from "c/healthCheckCtaBanner";

jest.mock("@salesforce/label/c.HC_CtaTitle", () => ({ default: "Ready for Full Compliance?" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.HC_CtaBody", () => ({ default: "Found {0} findings." }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.HC_CtaLink", () => ({ default: "View on AppExchange" }), {
  virtual: true,
});

describe("c-health-check-cta-banner", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function createComponent(findingsCount = 0) {
    const element = createElement("c-health-check-cta-banner", {
      is: HealthCheckCtaBanner,
    });
    element.findingsCount = findingsCount;
    document.body.appendChild(element);
    return element;
  }

  it("renders title", () => {
    const element = createComponent(5);
    const heading = element.shadowRoot.querySelector("h2");
    expect(heading.textContent).toBe("Ready for Full Compliance?");
  });

  it("interpolates findings count in body text", () => {
    const element = createComponent(12);
    const body = element.shadowRoot.querySelector("p");
    expect(body.textContent).toContain("12");
  });

  it("renders AppExchange button", () => {
    const element = createComponent(5);
    const button = element.shadowRoot.querySelector("lightning-button");
    expect(button).not.toBeNull();
    expect(button.label).toBe("View on AppExchange");
  });

  it("opens new window on CTA click", () => {
    const element = createComponent(5);
    const openSpy = jest.spyOn(window, "open").mockImplementation(() => null);

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    expect(openSpy).toHaveBeenCalledWith(expect.stringContaining("appexchange"), "_blank");
    openSpy.mockRestore();
  });

  it("handles zero findings count", () => {
    const element = createComponent(0);
    const body = element.shadowRoot.querySelector("p");
    expect(body.textContent).toContain("0");
  });
});
