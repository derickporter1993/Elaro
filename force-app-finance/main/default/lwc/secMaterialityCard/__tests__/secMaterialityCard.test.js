import { createElement } from "lwc";
import SecMaterialityCard from "c/secMaterialityCard";

// Custom label mocks
jest.mock(
  "@salesforce/label/c.SEC_IncidentDescription",
  () => ({ default: "Incident Description" }),
  { virtual: true }
);
jest.mock("@salesforce/label/c.SEC_DiscoveryDate", () => ({ default: "Discovery Date" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.SEC_FilingDeadline", () => ({ default: "Filing Deadline" }), {
  virtual: true,
});
jest.mock(
  "@salesforce/label/c.SEC_DeterminationResult",
  () => ({ default: "Determination Result" }),
  { virtual: true }
);
jest.mock("@salesforce/label/c.SEC_SLAStatus", () => ({ default: "SLA Status" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.SEC_OnTrack", () => ({ default: "On Track" }), { virtual: true });
jest.mock("@salesforce/label/c.SEC_AtRisk", () => ({ default: "At Risk" }), { virtual: true });
jest.mock("@salesforce/label/c.SEC_Breached", () => ({ default: "Breached" }), { virtual: true });

describe("c-sec-materiality-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent(assessment) {
    const element = createElement("c-sec-materiality-card", {
      is: SecMaterialityCard,
    });
    element.assessment = assessment;
    document.body.appendChild(element);
    return element;
  }

  const BASE_ASSESSMENT = {
    Id: "a0B000000000001",
    Name: "MA-2026-001",
    Filing_Deadline__c: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString(),
    Discovery_Date__c: "2026-02-01T00:00:00.000Z",
    Determination_Result__c: "Under Review",
  };

  it("renders assessment name in header", async () => {
    const element = createComponent(BASE_ASSESSMENT);
    await Promise.resolve();

    const title = element.shadowRoot.querySelector(".slds-truncate");
    expect(title).not.toBeNull();
    expect(title.textContent).toBe("MA-2026-001");
  });

  it("renders SLA badge", async () => {
    const element = createComponent(BASE_ASSESSMENT);
    await Promise.resolve();

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge).not.toBeNull();
    expect(badge.label).toBe("On Track");
  });

  it("shows On Track status for deadline more than 1 day away", async () => {
    const assessment = {
      ...BASE_ASSESSMENT,
      Filing_Deadline__c: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString(),
    };
    const element = createComponent(assessment);
    await Promise.resolve();

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge.label).toBe("On Track");
  });

  it("shows At Risk status for deadline within 1 day", async () => {
    const assessment = {
      ...BASE_ASSESSMENT,
      Filing_Deadline__c: new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString(),
    };
    const element = createComponent(assessment);
    await Promise.resolve();

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge.label).toBe("At Risk");
  });

  it("shows Breached status for past deadline", async () => {
    const assessment = {
      ...BASE_ASSESSMENT,
      Filing_Deadline__c: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
    };
    const element = createComponent(assessment);
    await Promise.resolve();

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge.label).toBe("Breached");
  });

  it("shows On Track status when no deadline is set", async () => {
    const assessment = {
      ...BASE_ASSESSMENT,
      Filing_Deadline__c: undefined,
    };
    const element = createComponent(assessment);
    await Promise.resolve();

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge.label).toBe("On Track");
  });

  it("displays formatted discovery date", async () => {
    const element = createComponent(BASE_ASSESSMENT);
    await Promise.resolve();

    const details = element.shadowRoot.querySelectorAll(".slds-dl_horizontal__detail");
    expect(details.length).toBeGreaterThanOrEqual(1);
    expect(details[0].textContent).not.toBe("");
  });

  it("displays determination result", async () => {
    const element = createComponent(BASE_ASSESSMENT);
    await Promise.resolve();

    const resultSpan = element.shadowRoot.querySelector(".severity-medium");
    expect(resultSpan).not.toBeNull();
    expect(resultSpan.textContent).toBe("Under Review");
  });

  it("applies severity-high class for Material determination", async () => {
    const assessment = {
      ...BASE_ASSESSMENT,
      Determination_Result__c: "Material",
    };
    const element = createComponent(assessment);
    await Promise.resolve();

    const resultSpan = element.shadowRoot.querySelector(".severity-high");
    expect(resultSpan).not.toBeNull();
    expect(resultSpan.textContent).toBe("Material");
  });

  it("applies severity-low class for Not Material determination", async () => {
    const assessment = {
      ...BASE_ASSESSMENT,
      Determination_Result__c: "Not Material",
    };
    const element = createComponent(assessment);
    await Promise.resolve();

    const resultSpan = element.shadowRoot.querySelector(".severity-low");
    expect(resultSpan).not.toBeNull();
  });

  it("dispatches viewassessment event on card click", async () => {
    const element = createComponent(BASE_ASSESSMENT);
    await Promise.resolve();

    const handler = jest.fn();
    element.addEventListener("viewassessment", handler);

    const article = element.shadowRoot.querySelector("article");
    article.click();

    expect(handler).toHaveBeenCalled();
    expect(handler.mock.calls[0][0].detail.assessmentId).toBe("a0B000000000001");
  });

  it("has accessible role and tabindex on card", async () => {
    const element = createComponent(BASE_ASSESSMENT);
    await Promise.resolve();

    const article = element.shadowRoot.querySelector("article");
    expect(article.getAttribute("role")).toBe("button");
    expect(article.getAttribute("tabindex")).toBe("0");
  });
});
