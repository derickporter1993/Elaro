import { createElement } from "lwc";
import TrustCenterLinkManager from "c/trustCenterLinkManager";
import getActiveLinks from "@salesforce/apex/TrustCenterController.getActiveLinks";
// createShareableLink and revokeLink handled by mocks below

// Mock wire adapter for getActiveLinks
jest.mock(
  "@salesforce/apex/TrustCenterController.getActiveLinks",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

// Mock imperative methods
jest.mock(
  "@salesforce/apex/TrustCenterController.createShareableLink",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock("@salesforce/apex/TrustCenterController.revokeLink", () => ({ default: jest.fn() }), {
  virtual: true,
});

// Mock refreshApex
jest.mock("@salesforce/apex", () => ({ refreshApex: jest.fn().mockResolvedValue(undefined) }), {
  virtual: true,
});

// Mock ShowToastEvent
jest.mock("lightning/platformShowToastEvent", () => ({ ShowToastEvent: jest.fn() }), {
  virtual: true,
});

// Mock custom labels
jest.mock("@salesforce/label/c.TC_LinkManager", () => ({ default: "Link Manager" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_CreateLink", () => ({ default: "Create Link" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_CopyLink", () => ({ default: "Copy Link" }), { virtual: true });
jest.mock("@salesforce/label/c.TC_LinkCopied", () => ({ default: "Link copied" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_RevokeLink", () => ({ default: "Revoke" }), { virtual: true });
jest.mock("@salesforce/label/c.TC_LinkCreated", () => ({ default: "Link created" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_LinkRevoked", () => ({ default: "Link revoked" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_ShareableLinks", () => ({ default: "Shareable Links" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_AccessTier", () => ({ default: "Access Tier" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_ExpirationDate", () => ({ default: "Expiration Date" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_ExpirationDays", () => ({ default: "Expiration (Days)" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_AccessCount", () => ({ default: "Access Count" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_CreatedFor", () => ({ default: "Created For" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_Loading", () => ({ default: "Loading..." }), { virtual: true });
jest.mock("@salesforce/label/c.TC_Error", () => ({ default: "Error" }), { virtual: true });
jest.mock("@salesforce/label/c.TC_ErrorGeneric", () => ({ default: "An error occurred." }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_DeactivateLink", () => ({ default: "Deactivate" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_AccessTierPublic", () => ({ default: "Public" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_AccessTierEmailGated", () => ({ default: "Email Gated" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.TC_AccessTierNDA", () => ({ default: "NDA Required" }), {
  virtual: true,
});

const MOCK_LINKS = [
  {
    Id: "a021000000link01",
    Name: "TC-001",
    Link_Token__c: "abc12345-1234-1234-1234-123456789abc",
    Access_Tier__c: "Public",
    Expiration_Date__c: "2026-03-15T00:00:00.000Z",
    Access_Count__c: 5,
    Created_For__c: "Acme Corp",
    CreatedDate: "2026-02-01T00:00:00.000Z",
  },
  {
    Id: "a021000000link02",
    Name: "TC-002",
    Link_Token__c: "def12345-1234-1234-1234-123456789def",
    Access_Tier__c: "NDA_Required",
    Expiration_Date__c: "2026-04-01T00:00:00.000Z",
    Access_Count__c: 12,
    Created_For__c: "SecureTech Inc",
    CreatedDate: "2026-02-10T00:00:00.000Z",
  },
];

// Flush all microtasks
function flushPromises() {
  return new Promise((resolve) => {
    setTimeout(resolve, 0);
  });
}

describe("c-trust-center-link-manager", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-trust-center-link-manager", {
      is: TrustCenterLinkManager,
    });
    document.body.appendChild(element);
    return element;
  }

  it("renders lightning-card with correct title", async () => {
    const element = createComponent();
    getActiveLinks.emit(MOCK_LINKS);
    await flushPromises();

    const card = element.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Link Manager");
  });

  it("renders datatable when links are returned", async () => {
    const element = createComponent();
    getActiveLinks.emit(MOCK_LINKS);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data.length).toBe(2);
  });

  it("renders empty state when no links exist", async () => {
    const element = createComponent();
    getActiveLinks.emit([]);
    await flushPromises();

    const emptyMessage = element.shadowRoot.querySelector(".slds-illustration");
    expect(emptyMessage).not.toBeNull();
  });

  it("renders error state when wire fails", async () => {
    const element = createComponent();
    getActiveLinks.error({ body: { message: "Test error" } });
    await flushPromises();

    const errorAlert = element.shadowRoot.querySelector('[role="alert"]');
    expect(errorAlert).not.toBeNull();
  });

  it("maps access tier labels correctly in table data", async () => {
    const element = createComponent();
    getActiveLinks.emit(MOCK_LINKS);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable.data[0].accessTierLabel).toBe("Public");
    expect(datatable.data[1].accessTierLabel).toBe("NDA Required");
  });

  it("does not show modal by default", async () => {
    const element = createComponent();
    getActiveLinks.emit(MOCK_LINKS);
    await flushPromises();

    const modal = element.shadowRoot.querySelector('[role="dialog"]');
    expect(modal).toBeNull();
  });

  it("hides datatable in error state", async () => {
    const element = createComponent();
    getActiveLinks.error({ body: { message: "Error" } });
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).toBeNull();
  });

  it("hides datatable in empty state", async () => {
    const element = createComponent();
    getActiveLinks.emit([]);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).toBeNull();
  });

  it("datatable has correct columns configuration", async () => {
    const element = createComponent();
    getActiveLinks.emit(MOCK_LINKS);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable.columns.length).toBe(5);
    expect(datatable.columns[0].label).toBe("Created For");
    expect(datatable.columns[1].label).toBe("Access Tier");
  });
});
