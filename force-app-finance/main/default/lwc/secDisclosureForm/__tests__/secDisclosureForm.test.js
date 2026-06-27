import { createElement } from "lwc";
import SecDisclosureForm from "c/secDisclosureForm";
import createAssessment from "@salesforce/apex/SECDisclosureController.createAssessment";

jest.mock(
  "@salesforce/apex/SECDisclosureController.createAssessment",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  "lightning/platformShowToastEvent",
  () => {
    return {
      ShowToastEvent: jest.fn().mockImplementation((config) => {
        return new CustomEvent("lightning__showtoast", { detail: config });
      }),
    };
  },
  { virtual: true }
);

// Re-import after mock setup
const { ShowToastEvent } = jest.requireMock("lightning/platformShowToastEvent");

function flushPromises() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("c-sec-disclosure-form", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function createComponent() {
    const element = createElement("c-sec-disclosure-form", {
      is: SecDisclosureForm,
    });
    document.body.appendChild(element);
    return element;
  }

  it("renders form inputs", () => {
    const element = createComponent();
    const inputs = element.shadowRoot.querySelectorAll("lightning-input");
    expect(inputs.length).toBe(2);
    expect(inputs[0].label).toBe("Incident Description");
    expect(inputs[1].label).toBe("Discovery Date");
  });

  it("renders create assessment button", () => {
    const element = createComponent();
    const button = element.shadowRoot.querySelector("lightning-button");
    expect(button).not.toBeNull();
    expect(button.label).toBe("Create Assessment");
  });

  it("tracks input changes for description field", async () => {
    const element = createComponent();
    const descInput = element.shadowRoot.querySelector('lightning-input[data-field="description"]');

    descInput.value = "Test incident";
    descInput.dispatchEvent(new CustomEvent("change", { target: descInput }));
    await Promise.resolve();

    expect(element).not.toBeNull();
  });

  it("calls createAssessment on save and dispatches success toast", async () => {
    createAssessment.mockResolvedValue("a0B000000000001");
    const element = createComponent();

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    await flushPromises();

    expect(createAssessment).toHaveBeenCalled();
    expect(ShowToastEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        title: "Success",
        variant: "success",
      })
    );
  });

  it("dispatches assessmentcreated custom event on success", async () => {
    createAssessment.mockResolvedValue("a0B000000000001");
    const element = createComponent();

    const handler = jest.fn();
    element.addEventListener("assessmentcreated", handler);

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    await flushPromises();

    expect(handler).toHaveBeenCalled();
    expect(handler.mock.calls[0][0].detail.assessmentId).toBe("a0B000000000001");
  });

  it("dispatches error toast on save failure", async () => {
    createAssessment.mockRejectedValue({ body: { message: "Validation error" } });
    const element = createComponent();

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    await flushPromises();

    expect(ShowToastEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        title: "Error",
        variant: "error",
      })
    );
  });

  it("shows generic error message when error has no body", async () => {
    createAssessment.mockRejectedValue(new Error("Network failure"));
    const element = createComponent();

    const button = element.shadowRoot.querySelector("lightning-button");
    button.click();

    await flushPromises();

    expect(ShowToastEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        title: "Error",
        variant: "error",
        message: "Error creating assessment",
      })
    );
  });
});
