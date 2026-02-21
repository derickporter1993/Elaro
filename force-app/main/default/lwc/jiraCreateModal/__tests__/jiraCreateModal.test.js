import { createElement } from "lwc";
import JiraCreateModal from "c/jiraCreateModal";
import createIssue from "@salesforce/apex/JiraIntegrationService.createIssue";
import isConfigured from "@salesforce/apex/JiraIntegrationService.isConfigured";

jest.mock("@salesforce/apex/JiraIntegrationService.createIssue", () => ({ default: jest.fn() }), {
  virtual: true,
});
jest.mock("@salesforce/apex/JiraIntegrationService.isConfigured", () => ({ default: jest.fn() }), {
  virtual: true,
});

function flushPromises() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("c-jira-create-modal", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent(props = {}) {
    isConfigured.mockResolvedValue(true);
    const element = createElement("c-jira-create-modal", {
      is: JiraCreateModal,
    });
    Object.assign(element, props);
    document.body.appendChild(element);
    return element;
  }

  function findButtonByLabel(root, label) {
    const buttons = root.querySelectorAll("lightning-button");
    return [...buttons].find((btn) => btn.label === label) || null;
  }

  async function openModal(element) {
    element.open();
    await flushPromises();
    await flushPromises();
  }

  function queryModal(element) {
    return element.shadowRoot.querySelector("section[role='dialog']");
  }

  it("renders the component", async () => {
    const element = createComponent({ recordId: "a00xx0000001" });
    await flushPromises();
    expect(element).not.toBeNull();
  });

  it("checks configuration on connected callback", async () => {
    createComponent({ recordId: "a00xx0000001" });
    await flushPromises();
    expect(isConfigured).toHaveBeenCalled();
  });

  it("opens modal via public open method", async () => {
    const element = createComponent({ recordId: "a00xx0000001" });
    await flushPromises();

    await openModal(element);

    const modal = queryModal(element);
    expect(modal).toBeTruthy();
  });

  it("closes modal via public close method", async () => {
    const element = createComponent({ recordId: "a00xx0000001" });
    await flushPromises();

    await openModal(element);
    element.close();
    await flushPromises();

    const modal = queryModal(element);
    expect(modal).toBeNull();
  });

  it("handles priority change", async () => {
    const element = createComponent({ recordId: "a00xx0000001" });
    await flushPromises();

    await openModal(element);

    const combobox = element.shadowRoot.querySelector("lightning-combobox");
    if (combobox) {
      combobox.dispatchEvent(new CustomEvent("change", { detail: { value: "High" } }));
      await flushPromises();
    }
  });

  it("creates issue successfully and dispatches event", async () => {
    createIssue.mockResolvedValue({ key: "COMP-123", url: "https://jira.test/COMP-123" });
    const element = createComponent({ recordId: "a00xx0000001" });
    await flushPromises();

    await openModal(element);

    const handler = jest.fn();
    element.addEventListener("issuecreated", handler);

    const createBtn = findButtonByLabel(element.shadowRoot, "Create Issue");
    expect(createBtn).toBeTruthy();
    createBtn.click();
    await flushPromises();

    expect(createIssue).toHaveBeenCalledWith({
      gapId: "a00xx0000001",
      priority: null,
    });
    expect(handler).toHaveBeenCalled();
    expect(handler.mock.calls[0][0].detail.issueKey).toBe("COMP-123");
  });

  it("shows error when no recordId is provided", async () => {
    const element = createComponent({ recordId: null });
    await flushPromises();

    await openModal(element);

    const createBtn = findButtonByLabel(element.shadowRoot, "Create Issue");
    expect(createBtn).toBeTruthy();
    createBtn.click();
    await flushPromises();
    expect(createIssue).not.toHaveBeenCalled();
  });

  it("handles createIssue error", async () => {
    createIssue.mockRejectedValue({ body: { message: "Jira API error" } });
    const element = createComponent({ recordId: "a00xx0000001" });
    await flushPromises();

    await openModal(element);

    const createBtn = findButtonByLabel(element.shadowRoot, "Create Issue");
    expect(createBtn).toBeTruthy();
    createBtn.click();
    await flushPromises();

    const errorAlert = element.shadowRoot.querySelector(".slds-alert_error span:last-child");
    expect(errorAlert).not.toBeNull();
    expect(errorAlert.textContent).toBe("Jira API error");
  });

  it("disables create button when not configured", async () => {
    isConfigured.mockResolvedValue(false);
    const element = createElement("c-jira-create-modal", {
      is: JiraCreateModal,
    });
    element.recordId = "a00xx0000001";
    document.body.appendChild(element);
    await flushPromises();

    await openModal(element);

    const createBtn = findButtonByLabel(element.shadowRoot, "Create Issue");
    expect(createBtn).toBeTruthy();
    expect(createBtn.disabled).toBe(true);
  });

  it("shows not configured warning when jira is not set up", async () => {
    isConfigured.mockResolvedValue(false);
    const element = createElement("c-jira-create-modal", {
      is: JiraCreateModal,
    });
    element.recordId = "a00xx0000001";
    document.body.appendChild(element);
    await flushPromises();

    await openModal(element);

    const warning = element.shadowRoot.querySelector(".slds-alert_warning");
    expect(warning).toBeTruthy();
  });

  it("closes modal on cancel button click", async () => {
    const element = createComponent({ recordId: "a00xx0000001" });
    await flushPromises();

    await openModal(element);

    const cancelBtn = findButtonByLabel(element.shadowRoot, "Cancel");
    expect(cancelBtn).toBeTruthy();
    cancelBtn.click();
    await flushPromises();

    const modal = queryModal(element);
    expect(modal).toBeNull();
  });
});
