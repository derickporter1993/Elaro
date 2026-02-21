/**
 * Jest tests for focusManager utility module
 *
 * Tests cover:
 * - Focusable element detection
 * - Focus manipulation (first, last)
 * - Focus trapping
 * - Focus store (save/restore)
 * - Roving tabindex navigation
 * - Screen reader announcements
 */

import {
  getFocusableElements,
  focusFirstElement,
  focusLastElement,
  trapFocus,
  createFocusStore,
  handleRovingTabindex,
  announceToScreenReader,
} from "../focusManager";

function buildDOM(container, elements) {
  elements.forEach(({ tag, attrs, text }) => {
    const el = document.createElement(tag);
    if (attrs) {
      Object.entries(attrs).forEach(([key, value]) => {
        el.setAttribute(key, value);
      });
    }
    if (text) {
      el.textContent = text;
    }
    container.appendChild(el);
  });
}

describe("focusManager", () => {
  let container;

  beforeEach(() => {
    // Create a test container
    container = document.createElement("div");
    document.body.appendChild(container);
  });

  afterEach(() => {
    // Clean up
    if (container && container.parentNode) {
      container.parentNode.removeChild(container);
    }
    // Remove screen reader region if created
    const liveRegion = document.getElementById("sr-announcements");
    if (liveRegion && liveRegion.parentNode) {
      liveRegion.parentNode.removeChild(liveRegion);
    }
  });

  describe("getFocusableElements", () => {
    it("returns empty array for null container", () => {
      const elements = getFocusableElements(null);
      expect(elements).toEqual([]);
    });

    it("returns empty array for empty container", () => {
      const elements = getFocusableElements(container);
      expect(elements).toEqual([]);
    });

    it("finds focusable elements", () => {
      buildDOM(container, [
        { tag: "button", text: "Button 1" },
        { tag: "input", attrs: { type: "text" } },
        { tag: "a", attrs: { href: "#" }, text: "Link" },
        { tag: "div", attrs: { tabindex: "0" }, text: "Focusable div" },
      ]);

      const elements = getFocusableElements(container);
      expect(elements.length).toBe(4);
      expect(elements[0].tagName).toBe("BUTTON");
      expect(elements[1].tagName).toBe("INPUT");
      expect(elements[2].tagName).toBe("A");
      expect(elements[3].tagName).toBe("DIV");
    });

    it("excludes disabled elements", () => {
      buildDOM(container, [
        { tag: "button", text: "Enabled" },
        { tag: "button", attrs: { disabled: "" }, text: "Disabled" },
        { tag: "input", attrs: { type: "text" } },
        { tag: "input", attrs: { type: "text", disabled: "" } },
      ]);

      const elements = getFocusableElements(container);
      expect(elements.length).toBe(2);
      expect(elements.every((el) => !el.hasAttribute("disabled"))).toBe(true);
    });

    it("excludes elements with tabindex=-1", () => {
      buildDOM(container, [
        { tag: "button", attrs: { tabindex: "0" }, text: "Focusable" },
        { tag: "button", attrs: { tabindex: "-1" }, text: "Not focusable" },
      ]);

      const elements = getFocusableElements(container);
      expect(elements.length).toBe(1);
      expect(elements[0].getAttribute("tabindex")).toBe("0");
    });

    it("excludes hidden elements", () => {
      buildDOM(container, [
        { tag: "button", attrs: { style: "display: none;" }, text: "Hidden" },
        {
          tag: "button",
          attrs: { style: "visibility: hidden;" },
          text: "Invisible",
        },
        { tag: "button", text: "Visible" },
      ]);

      const elements = getFocusableElements(container);
      expect(elements.length).toBe(1);
      expect(elements[0].textContent).toBe("Visible");
    });
  });

  describe("focusFirstElement", () => {
    it("returns false for null container", () => {
      const result = focusFirstElement(null);
      expect(result).toBe(false);
    });

    it("returns false for empty container", () => {
      const result = focusFirstElement(container);
      expect(result).toBe(false);
    });

    it("focuses first element and returns true", () => {
      buildDOM(container, [
        { tag: "button", text: "First" },
        { tag: "button", text: "Second" },
      ]);

      const result = focusFirstElement(container);
      expect(result).toBe(true);
      expect(document.activeElement.textContent).toBe("First");
    });
  });

  describe("focusLastElement", () => {
    it("returns false for null container", () => {
      const result = focusLastElement(null);
      expect(result).toBe(false);
    });

    it("returns false for empty container", () => {
      const result = focusLastElement(container);
      expect(result).toBe(false);
    });

    it("focuses last element and returns true", () => {
      buildDOM(container, [
        { tag: "button", text: "First" },
        { tag: "button", text: "Last" },
      ]);

      const result = focusLastElement(container);
      expect(result).toBe(true);
      expect(document.activeElement.textContent).toBe("Last");
    });
  });

  describe("trapFocus", () => {
    it("returns no-op function for null container", () => {
      const cleanup = trapFocus(null);
      expect(typeof cleanup).toBe("function");
      expect(() => cleanup()).not.toThrow();
    });

    it("traps focus within container", () => {
      buildDOM(container, [
        { tag: "button", text: "First" },
        { tag: "button", text: "Middle" },
        { tag: "button", text: "Last" },
      ]);

      const focusable = Array.from(container.querySelectorAll("button"));
      focusable[0].focus();

      const cleanup = trapFocus(container);

      // Simulate Tab from last element (should wrap to first)
      const lastButton = focusable[2];
      lastButton.focus();

      const tabEvent = new KeyboardEvent("keydown", {
        key: "Tab",
        bubbles: true,
      });
      lastButton.dispatchEvent(tabEvent);

      // Focus should wrap to first
      expect(document.activeElement).toBe(focusable[0]);

      cleanup();
    });

    it("handles Shift+Tab to wrap backwards", () => {
      buildDOM(container, [
        { tag: "button", text: "First" },
        { tag: "button", text: "Last" },
      ]);

      const focusable = Array.from(container.querySelectorAll("button"));
      focusable[0].focus();

      const cleanup = trapFocus(container);

      // Shift+Tab from first should wrap to last
      const firstButton = focusable[0];
      const shiftTabEvent = new KeyboardEvent("keydown", {
        key: "Tab",
        shiftKey: true,
        bubbles: true,
      });
      firstButton.dispatchEvent(shiftTabEvent);

      expect(document.activeElement).toBe(focusable[1]);

      cleanup();
    });

    it("cleans up event listener", () => {
      buildDOM(container, [{ tag: "button", text: "Test" }]);

      const cleanup = trapFocus(container);
      cleanup();

      // After cleanup, Tab should not be trapped
      const button = container.querySelector("button");
      button.focus();

      const tabEvent = new KeyboardEvent("keydown", {
        key: "Tab",
        bubbles: true,
      });
      expect(() => button.dispatchEvent(tabEvent)).not.toThrow();
    });
  });

  describe("createFocusStore", () => {
    it("returns object with save and restore methods", () => {
      const store = createFocusStore();
      expect(store).toHaveProperty("save");
      expect(store).toHaveProperty("restore");
      expect(store).toHaveProperty("clear");
      expect(store).toHaveProperty("getSaved");
      expect(typeof store.save).toBe("function");
      expect(typeof store.restore).toBe("function");
    });

    it("saves and restores focus", (done) => {
      buildDOM(container, [{ tag: "button", text: "Test Button" }]);
      const button = container.querySelector("button");
      button.focus();

      const store = createFocusStore();
      store.save();

      // Change focus
      document.body.focus();

      // Restore (async with setTimeout)
      store.restore();

      setTimeout(() => {
        expect(document.activeElement).toBe(button);
        done();
      }, 10);
    });

    it("clear removes saved element", () => {
      buildDOM(container, [{ tag: "button", text: "Test" }]);
      const button = container.querySelector("button");
      button.focus();

      const store = createFocusStore();
      store.save();
      store.clear();

      expect(store.getSaved()).toBeNull();
    });

    it("getSaved returns saved element", () => {
      buildDOM(container, [{ tag: "button", text: "Test" }]);
      const button = container.querySelector("button");
      button.focus();

      const store = createFocusStore();
      store.save();

      expect(store.getSaved()).toBe(button);
    });
  });

  describe("handleRovingTabindex", () => {
    it("handles ArrowRight navigation", () => {
      buildDOM(container, [
        { tag: "button", attrs: { tabindex: "0" }, text: "First" },
        { tag: "button", attrs: { tabindex: "-1" }, text: "Second" },
        { tag: "button", attrs: { tabindex: "-1" }, text: "Third" },
      ]);

      const elements = Array.from(container.querySelectorAll("button"));
      elements[0].focus();

      const event = new KeyboardEvent("keydown", {
        key: "ArrowRight",
        bubbles: true,
        target: elements[0],
      });
      event.preventDefault = jest.fn();

      handleRovingTabindex(elements, event, { vertical: false, wrap: false });

      expect(event.preventDefault).toHaveBeenCalled();
      expect(elements[1].getAttribute("tabindex")).toBe("0");
      expect(elements[0].getAttribute("tabindex")).toBe("-1");
      expect(document.activeElement).toBe(elements[1]);
    });

    it("handles ArrowLeft navigation", () => {
      buildDOM(container, [
        { tag: "button", attrs: { tabindex: "-1" }, text: "First" },
        { tag: "button", attrs: { tabindex: "0" }, text: "Second" },
      ]);

      const elements = Array.from(container.querySelectorAll("button"));
      elements[1].focus();

      const event = new KeyboardEvent("keydown", {
        key: "ArrowLeft",
        bubbles: true,
        target: elements[1],
      });
      event.preventDefault = jest.fn();

      handleRovingTabindex(elements, event, { vertical: false });

      expect(event.preventDefault).toHaveBeenCalled();
      expect(elements[0].getAttribute("tabindex")).toBe("0");
      expect(document.activeElement).toBe(elements[0]);
    });

    it("wraps around at ends when wrap is true", () => {
      buildDOM(container, [
        { tag: "button", attrs: { tabindex: "0" }, text: "First" },
        { tag: "button", attrs: { tabindex: "-1" }, text: "Last" },
      ]);

      const elements = Array.from(container.querySelectorAll("button"));
      elements[0].focus();

      const event = new KeyboardEvent("keydown", {
        key: "ArrowRight",
        bubbles: true,
        target: elements[0],
      });
      event.preventDefault = jest.fn();

      handleRovingTabindex(elements, event, { vertical: false, wrap: true });

      expect(document.activeElement).toBe(elements[1]);
    });

    it("handles Home key", () => {
      buildDOM(container, [
        { tag: "button", attrs: { tabindex: "-1" }, text: "First" },
        { tag: "button", attrs: { tabindex: "0" }, text: "Second" },
      ]);

      const elements = Array.from(container.querySelectorAll("button"));
      elements[1].focus();

      const event = new KeyboardEvent("keydown", {
        key: "Home",
        bubbles: true,
        target: elements[1],
      });
      event.preventDefault = jest.fn();

      handleRovingTabindex(elements, event);

      expect(elements[0].getAttribute("tabindex")).toBe("0");
      expect(document.activeElement).toBe(elements[0]);
    });

    it("handles End key", () => {
      buildDOM(container, [
        { tag: "button", attrs: { tabindex: "0" }, text: "First" },
        { tag: "button", attrs: { tabindex: "-1" }, text: "Last" },
      ]);

      const elements = Array.from(container.querySelectorAll("button"));
      elements[0].focus();

      const event = new KeyboardEvent("keydown", {
        key: "End",
        bubbles: true,
        target: elements[0],
      });
      event.preventDefault = jest.fn();

      handleRovingTabindex(elements, event);

      expect(elements[1].getAttribute("tabindex")).toBe("0");
      expect(document.activeElement).toBe(elements[1]);
    });
  });

  describe("announceToScreenReader", () => {
    it("creates aria-live region if it doesn't exist", () => {
      expect(document.getElementById("sr-announcements")).toBeNull();

      announceToScreenReader("Test message");

      const liveRegion = document.getElementById("sr-announcements");
      expect(liveRegion).not.toBeNull();
      expect(liveRegion.getAttribute("aria-live")).toBe("polite");
      expect(liveRegion.getAttribute("aria-atomic")).toBe("true");
    });

    it("uses existing aria-live region", () => {
      announceToScreenReader("First message");
      const firstRegion = document.getElementById("sr-announcements");

      announceToScreenReader("Second message");
      const secondRegion = document.getElementById("sr-announcements");

      expect(firstRegion).toBe(secondRegion);
    });

    it("sets message text", (done) => {
      announceToScreenReader("Test announcement");

      setTimeout(() => {
        const liveRegion = document.getElementById("sr-announcements");
        expect(liveRegion.textContent).toBe("Test announcement");
        done();
      }, 150);
    });

    it("respects priority parameter", () => {
      announceToScreenReader("Urgent message", "assertive");

      const liveRegion = document.getElementById("sr-announcements");
      expect(liveRegion.getAttribute("aria-live")).toBe("assertive");
    });
  });
});
