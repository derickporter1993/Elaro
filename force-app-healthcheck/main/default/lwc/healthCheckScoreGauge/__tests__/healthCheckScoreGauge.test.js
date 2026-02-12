import { createElement } from "lwc";
import HealthCheckScoreGauge from "c/healthCheckScoreGauge";

jest.mock("@salesforce/label/c.HC_ScoreExcellent", () => ({ default: "Excellent" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.HC_ScoreGood", () => ({ default: "Good" }), { virtual: true });
jest.mock("@salesforce/label/c.HC_ScoreNeedsWork", () => ({ default: "Needs Work" }), {
  virtual: true,
});
jest.mock("@salesforce/label/c.HC_ScoreCritical", () => ({ default: "Critical" }), {
  virtual: true,
});

describe("c-health-check-score-gauge", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function createComponent(score = 0) {
    const element = createElement("c-health-check-score-gauge", {
      is: HealthCheckScoreGauge,
    });
    element.score = score;
    document.body.appendChild(element);
    return element;
  }

  it("renders with default score of 0", () => {
    const element = createComponent(0);
    const scoreText = element.shadowRoot.querySelector(".gauge-score");
    expect(scoreText.textContent).toBe("0");
  });

  it("displays score value", () => {
    const element = createComponent(72);
    const scoreText = element.shadowRoot.querySelector(".gauge-score");
    expect(scoreText.textContent).toBe("72");
  });

  it("shows Critical label for low scores", () => {
    const element = createComponent(25);
    const label = element.shadowRoot.querySelector(".gauge-text");
    expect(label.textContent).toBe("Critical");
  });

  it("shows Needs Work label for medium scores", () => {
    const element = createComponent(55);
    const label = element.shadowRoot.querySelector(".gauge-text");
    expect(label.textContent).toBe("Needs Work");
  });

  it("shows Excellent label for high scores", () => {
    const element = createComponent(85);
    const label = element.shadowRoot.querySelector(".gauge-text");
    expect(label.textContent).toBe("Excellent");
  });

  it("has accessible role and aria-label", () => {
    const element = createComponent(72);
    const container = element.shadowRoot.querySelector('[role="img"]');
    expect(container).not.toBeNull();
    expect(container.getAttribute("aria-label")).toContain("72");
  });

  it("clamps negative scores to 0", () => {
    const element = createComponent(-10);
    const scoreText = element.shadowRoot.querySelector(".gauge-score");
    expect(scoreText.textContent).toBe("0");
  });

  it("clamps scores above 100", () => {
    const element = createComponent(150);
    const scoreText = element.shadowRoot.querySelector(".gauge-score");
    expect(scoreText.textContent).toBe("100");
  });

  it("renders SVG elements", () => {
    const element = createComponent(50);
    const circles = element.shadowRoot.querySelectorAll("circle");
    expect(circles.length).toBe(2);
  });
});
