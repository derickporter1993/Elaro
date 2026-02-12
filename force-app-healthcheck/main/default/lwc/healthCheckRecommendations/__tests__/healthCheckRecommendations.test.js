import { createElement } from "lwc";
import HealthCheckRecommendations from "c/healthCheckRecommendations";

jest.mock("@salesforce/label/c.HC_GoToSetup", () => ({ default: "Go to Setup" }), {
  virtual: true,
});

jest.mock(
  "lightning/navigation",
  () => {
    const Navigate = Symbol("Navigate");
    const mixin = (Base) => Base;
    mixin.Navigate = Navigate;
    return { NavigationMixin: mixin };
  },
  { virtual: true }
);

const MOCK_RECOMMENDATIONS = [
  {
    title: "Enable MFA for All Users",
    description: "Current adoption is 60%.",
    setupMenuPath: "SecurityMfa/home",
    priority: 1,
    category: "MFA",
  },
  {
    title: "Review Permissions",
    description: "ModifyAllData assigned to non-admin.",
    setupMenuPath: "PermSets/home",
    priority: 2,
    category: "Permissions",
  },
];

describe("c-health-check-recommendations", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function createComponent(recommendations = []) {
    const element = createElement("c-health-check-recommendations", {
      is: HealthCheckRecommendations,
    });
    element.recommendations = recommendations;
    document.body.appendChild(element);
    return element;
  }

  it("renders recommendation cards", async () => {
    const element = createComponent(MOCK_RECOMMENDATIONS);
    await flushPromises();

    const boxes = element.shadowRoot.querySelectorAll(".slds-box");
    expect(boxes.length).toBe(2);
  });

  it("shows empty state with no recommendations", async () => {
    const element = createComponent([]);
    await flushPromises();

    const boxes = element.shadowRoot.querySelectorAll(".slds-box");
    expect(boxes.length).toBe(0);
  });

  it("displays recommendation titles", async () => {
    const element = createComponent(MOCK_RECOMMENDATIONS);
    await flushPromises();

    const headings = element.shadowRoot.querySelectorAll(".slds-text-heading_small");
    expect(headings[0].textContent).toBe("Enable MFA for All Users");
  });

  it("renders Go to Setup buttons", async () => {
    const element = createComponent(MOCK_RECOMMENDATIONS);
    await flushPromises();

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    expect(buttons.length).toBe(2);
    expect(buttons[0].label).toBe("Go to Setup");
  });

  it("renders priority badges", async () => {
    const element = createComponent(MOCK_RECOMMENDATIONS);
    await flushPromises();

    const badges = element.shadowRoot.querySelectorAll(".slds-badge");
    expect(badges.length).toBeGreaterThan(0);
  });
});
