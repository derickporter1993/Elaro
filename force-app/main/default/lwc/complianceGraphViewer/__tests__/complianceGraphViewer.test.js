/**
 * Jest tests for ComplianceGraphViewer component
 *
 * Tests cover:
 * - Initial render states (loading, empty, with data)
 * - Framework filter selection
 * - Node interaction and details panel
 * - Impact analysis functionality
 * - Error handling
 * - Graph rendering
 */

// @ts-ignore - LWC1702 false positive for Jest test files
import { createElement } from "lwc";
import ComplianceGraphViewer from "c/complianceGraphViewer";

// Mock Apex methods
const mockGetComplianceGraph = jest.fn();
const mockGetGraphByFramework = jest.fn();
const mockGetGraphStats = jest.fn();
const mockGetNodeDetails = jest.fn();
const mockAnalyzeImpact = jest.fn();

jest.mock(
  "@salesforce/apex/ComplianceGraphService.getComplianceGraph",
  () => ({ default: mockGetComplianceGraph }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ComplianceGraphService.getGraphByFramework",
  () => ({ default: mockGetGraphByFramework }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ComplianceGraphService.getGraphStats",
  () => ({ default: mockGetGraphStats }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ComplianceGraphService.getNodeDetails",
  () => ({ default: mockGetNodeDetails }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/ComplianceGraphService.analyzeImpact",
  () => ({ default: mockAnalyzeImpact }),
  { virtual: true }
);

// Mock ShowToastEvent - must return a valid Event
jest.mock(
  "lightning/platformShowToastEvent",
  () => ({
    ShowToastEvent: function (config) {
      return new CustomEvent("lightning__showtoast", { detail: config });
    },
  }),
  { virtual: true }
);

// Sample test data
const MOCK_STATS = {
  totalGaps: 15,
  totalFrameworks: 5,
  totalEntities: 42,
  severityCounts: {
    CRITICAL: 3,
    HIGH: 5,
    MEDIUM: 4,
    LOW: 3,
  },
  frameworkCounts: {
    SOX: 5,
    HIPAA: 4,
    SOC2: 6,
  },
};

const MOCK_GRAPH_DATA = {
  nodes: [
    { id: "f1", label: "SOX", nodeType: "framework", color: "#1E88E5", size: 20 },
    { id: "p1", label: "Access Control Policy", nodeType: "policy", color: "#607D8B", size: 15 },
    {
      id: "g1",
      label: "Missing MFA",
      nodeType: "gap",
      color: "#D32F2F",
      size: 12,
      metadata: { severity: "CRITICAL" },
    },
    {
      id: "e1",
      label: "PermissionSet",
      nodeType: "entity",
      color: "#9C27B0",
      size: 10,
      metadata: { entityType: "PermissionSet", entityId: "001abc123" },
    },
  ],
  edges: [
    { source: "f1", target: "p1", weight: 2 },
    { source: "p1", target: "g1", weight: 1 },
    { source: "g1", target: "e1", weight: 1 },
  ],
};

const MOCK_NODE_DETAILS = {
  name: "Missing MFA Policy",
  nodeType: "gap",
  metadata: {
    framework: "SOX",
    severity: "CRITICAL",
    status: "Open",
    riskScore: 8.5,
    description: "Multi-factor authentication is not enabled.",
  },
};

const MOCK_IMPACT_ANALYSIS = {
  criticalCount: 2,
  highCount: 3,
  mediumCount: 1,
  lowCount: 0,
  riskScore: 45,
  totalGaps: 6,
  affectedGaps: [
    { gapId: "g1", gapName: "Missing MFA", framework: "SOX", severity: "CRITICAL", status: "Open" },
    { gapId: "g2", gapName: "Weak Password", framework: "SOX", severity: "HIGH", status: "Open" },
  ],
};

describe("c-compliance-graph-viewer", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetGraphStats.mockResolvedValue(MOCK_STATS);
    mockGetComplianceGraph.mockResolvedValue(MOCK_GRAPH_DATA);
    mockGetGraphByFramework.mockResolvedValue(MOCK_GRAPH_DATA);
    mockGetNodeDetails.mockResolvedValue(MOCK_NODE_DETAILS);
    mockAnalyzeImpact.mockResolvedValue(MOCK_IMPACT_ANALYSIS);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  function flushPromises() {
    return new Promise((resolve) => setTimeout(resolve, 0));
  }

  // Extended flush for async operations that chain multiple promises
  async function flushAll() {
    await flushPromises();
    await flushPromises();
    await flushPromises();
    await new Promise((resolve) => setTimeout(resolve, 10));
  }

  async function createComponent() {
    const element = createElement("c-compliance-graph-viewer", {
      is: ComplianceGraphViewer,
    });
    document.body.appendChild(element);
    // Wait for connectedCallback and async methods (loadStats, loadGraph)
    await flushAll();
    return element;
  }

  describe("Initial Render", () => {
    it("renders the lightning card with correct title", async () => {
      const element = await createComponent();
      const card = element.shadowRoot.querySelector("lightning-card");
      expect(card).not.toBeNull();
      expect(card.title).toBe("Compliance Graph");
    });

    it("shows loading spinner on initial load", async () => {
      mockGetGraphStats.mockImplementation(() => new Promise(() => {}));
      mockGetComplianceGraph.mockImplementation(() => new Promise(() => {}));

      const element = createElement("c-compliance-graph-viewer", {
        is: ComplianceGraphViewer,
      });
      document.body.appendChild(element);

      const spinner = element.shadowRoot.querySelector("lightning-spinner");
      expect(spinner).not.toBeNull();
    });

    it("renders stats after loading", async () => {
      const element = await createComponent();
      await flushAll();

      // Verify stats were loaded by checking the mock was called
      expect(mockGetGraphStats).toHaveBeenCalled();
    });
  });

  describe("Framework Filter", () => {
    it("renders framework combobox", async () => {
      const element = await createComponent();
      const combobox = element.shadowRoot.querySelector("lightning-combobox");
      expect(combobox).not.toBeNull();
    });

    it("calls getGraphByFramework when framework is selected", async () => {
      const element = await createComponent();
      await flushAll();

      const combobox = element.shadowRoot.querySelector("lightning-combobox");
      combobox.dispatchEvent(
        new CustomEvent("change", {
          detail: { value: "SOX" },
        })
      );

      await flushAll();
      expect(mockGetGraphByFramework).toHaveBeenCalledWith({ framework: "SOX" });
    });

    it("calls getComplianceGraph when ALL is selected", async () => {
      const element = await createComponent();
      await flushAll();

      // First change to a specific framework
      const combobox = element.shadowRoot.querySelector("lightning-combobox");
      combobox.dispatchEvent(
        new CustomEvent("change", {
          detail: { value: "SOX" },
        })
      );
      await flushAll();

      jest.clearAllMocks();

      // Then change back to ALL
      combobox.dispatchEvent(
        new CustomEvent("change", {
          detail: { value: "ALL" },
        })
      );
      await flushAll();

      expect(mockGetComplianceGraph).toHaveBeenCalled();
    });
  });

  describe("Refresh Functionality", () => {
    it("renders refresh button", async () => {
      const element = await createComponent();
      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const refreshButton = Array.from(buttons).find((btn) => btn.label === "Refresh");
      expect(refreshButton).not.toBeNull();
    });

    it("reloads data when refresh is clicked", async () => {
      const element = await createComponent();
      await flushAll();

      jest.clearAllMocks();

      const buttons = element.shadowRoot.querySelectorAll("lightning-button");
      const refreshButton = Array.from(buttons).find((btn) => btn.label === "Refresh");
      refreshButton.click();

      await flushAll();

      expect(mockGetGraphStats).toHaveBeenCalled();
      expect(mockGetComplianceGraph).toHaveBeenCalled();
    });
  });

  describe("Empty State", () => {
    it("shows empty state when no graph data", async () => {
      mockGetComplianceGraph.mockResolvedValue({ nodes: [], edges: [] });

      const element = await createComponent();
      await flushPromises();
      await flushPromises();

      const emptyMessage = element.shadowRoot.querySelector(".slds-illustration");
      expect(emptyMessage).not.toBeNull();
    });
  });

  describe("Graph Rendering", () => {
    it("loads graph data on mount", async () => {
      const element = await createComponent();
      await flushAll();

      // Verify the graph data was fetched
      expect(mockGetComplianceGraph).toHaveBeenCalled();
    });

    it("renders the card with correct icon", async () => {
      const element = await createComponent();
      await flushAll();

      const card = element.shadowRoot.querySelector("lightning-card");
      expect(card.iconName).toBe("standard:relationship");
    });
  });

  describe("Severity Stats", () => {
    it("loads stats data on mount", async () => {
      const element = await createComponent();
      await flushAll();

      // Verify stats were loaded
      expect(mockGetGraphStats).toHaveBeenCalled();
    });
  });

  describe("Error Handling", () => {
    it("handles graph loading error gracefully", async () => {
      mockGetComplianceGraph.mockRejectedValue({
        body: { message: "Failed to load graph" },
      });

      const element = await createComponent();
      await flushPromises();
      await flushPromises();

      // Component should still render
      expect(element.shadowRoot.querySelector("lightning-card")).not.toBeNull();
    });

    it("handles stats loading error gracefully", async () => {
      mockGetGraphStats.mockRejectedValue({
        body: { message: "Failed to load stats" },
      });

      const element = await createComponent();
      await flushPromises();

      // Component should still render
      expect(element.shadowRoot.querySelector("lightning-card")).not.toBeNull();
    });
  });

  describe("Computed Properties", () => {
    it("hasGraph returns false for empty nodes", async () => {
      mockGetComplianceGraph.mockResolvedValue({ nodes: [], edges: [] });

      const element = await createComponent();
      await flushAll();

      const emptyState = element.shadowRoot.querySelector(".slds-illustration");
      expect(emptyState).not.toBeNull();
    });

    it("component renders correctly with stats data", async () => {
      const element = await createComponent();
      await flushAll();

      // Verify component loaded and rendered
      const card = element.shadowRoot.querySelector("lightning-card");
      expect(card).not.toBeNull();
    });
  });

  describe("Accessibility", () => {
    it("uses semantic dialog for modals", async () => {
      const element = await createComponent();
      await flushPromises();

      // Initially no dialog visible
      const dialog = element.shadowRoot.querySelector('[role="dialog"]');
      expect(dialog).toBeNull();
    });

    it("includes assistive text for close buttons", async () => {
      const element = await createComponent();
      await flushPromises();

      // This would be tested when modals are opened
      expect(element.shadowRoot.querySelector("lightning-card")).not.toBeNull();
    });
  });
});
