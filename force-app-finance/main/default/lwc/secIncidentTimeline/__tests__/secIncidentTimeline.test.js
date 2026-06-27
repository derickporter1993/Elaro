import { createElement } from "lwc";
import SecIncidentTimeline from "c/secIncidentTimeline";

// Custom label mocks
jest.mock("@salesforce/label/c.SEC_IncidentTimeline", () => ({ default: "Incident Timeline" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.SEC_EventType", () => ({ default: "Event Type" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.SEC_NoEvents", () => ({ default: "No events recorded" }), {
  virtual: true,
});

const MOCK_EVENTS = [
  {
    Id: "evt001",
    Event_Type__c: "Discovery",
    Description__c: "Security breach discovered in production",
    Event_Date__c: "2026-02-01T10:00:00.000Z",
    SLA_Status__c: "Met",
  },
  {
    Id: "evt002",
    Event_Type__c: "Determination",
    Description__c: "Materiality determination completed",
    Event_Date__c: "2026-02-03T14:00:00.000Z",
    SLA_Status__c: "Met",
  },
  {
    Id: "evt003",
    Event_Type__c: "Board Approval",
    Description__c: "Board approved disclosure",
    Event_Date__c: "2026-02-02T09:00:00.000Z",
    SLA_Status__c: null,
  },
  {
    Id: "evt004",
    Event_Type__c: "Filing",
    Description__c: "8-K filed with SEC",
    Event_Date__c: "2026-02-04T16:00:00.000Z",
    SLA_Status__c: "Met",
  },
];

describe("c-sec-incident-timeline", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent(events = []) {
    const element = createElement("c-sec-incident-timeline", {
      is: SecIncidentTimeline,
    });
    element.events = events;
    document.body.appendChild(element);
    return element;
  }

  it("renders empty state when no events provided", async () => {
    const element = createComponent([]);
    await Promise.resolve();

    const emptyMsg = element.shadowRoot.querySelector(".slds-text-color_weak");
    expect(emptyMsg).not.toBeNull();
    expect(emptyMsg.textContent).toBe("No events recorded");
  });

  it("renders empty state with default empty array", async () => {
    const element = createComponent();
    await Promise.resolve();

    const timeline = element.shadowRoot.querySelector(".slds-timeline");
    expect(timeline).toBeNull();

    const emptyMsg = element.shadowRoot.querySelector(".slds-text-color_weak");
    expect(emptyMsg).not.toBeNull();
  });

  it("renders timeline items when events are provided", async () => {
    const element = createComponent(MOCK_EVENTS);
    await Promise.resolve();

    const items = element.shadowRoot.querySelectorAll(".slds-timeline__item");
    expect(items.length).toBe(4);
  });

  it("sorts events by date descending", async () => {
    const element = createComponent(MOCK_EVENTS);
    await Promise.resolve();

    const headings = element.shadowRoot.querySelectorAll(".slds-text-heading_small");
    expect(headings[0].textContent).toBe("Filing");
    expect(headings[1].textContent).toBe("Determination");
    expect(headings[2].textContent).toBe("Board Approval");
    expect(headings[3].textContent).toBe("Discovery");
  });

  it("displays event descriptions", async () => {
    const element = createComponent([MOCK_EVENTS[0]]);
    await Promise.resolve();

    const description = element.shadowRoot.querySelector(".slds-text-body_small");
    expect(description).not.toBeNull();
    expect(description.textContent).toBe("Security breach discovered in production");
  });

  it("renders SLA badge when SLA_Status__c is present", async () => {
    const element = createComponent([MOCK_EVENTS[0]]);
    await Promise.resolve();

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge).not.toBeNull();
    expect(badge.label).toBe("Met");
  });

  it("does not render SLA badge when SLA_Status__c is null", async () => {
    const element = createComponent([MOCK_EVENTS[2]]);
    await Promise.resolve();

    const badge = element.shadowRoot.querySelector("lightning-badge");
    expect(badge).toBeNull();
  });

  it("renders lightning card with correct title", async () => {
    const element = createComponent(MOCK_EVENTS);
    await Promise.resolve();

    const card = element.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Incident Timeline");
  });

  it("renders lightning-icon for each event", async () => {
    const element = createComponent(MOCK_EVENTS);
    await Promise.resolve();

    const icons = element.shadowRoot.querySelectorAll("lightning-icon");
    expect(icons.length).toBe(4);
  });

  it("handles hasEvents getter correctly with events", () => {
    const element = createComponent(MOCK_EVENTS);
    expect(element.events.length).toBe(4);
  });

  it("handles null events gracefully", async () => {
    const element = createElement("c-sec-incident-timeline", {
      is: SecIncidentTimeline,
    });
    element.events = null;
    document.body.appendChild(element);
    await Promise.resolve();

    const emptyMsg = element.shadowRoot.querySelector(".slds-text-color_weak");
    expect(emptyMsg).not.toBeNull();
  });
});
