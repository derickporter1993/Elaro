import { describe, it, expect } from "vitest";
import { redact, partialRedact } from "./strategies/redact";
import { hash } from "./strategies/hash";
import { MaskingEngine, POLICY_TEMPLATES } from "./index";
import type { MaskingPolicy } from "@platform/types";

// Minimal MaskingPolicy that satisfies all required fields for testing
function makePolicy(overrides: Partial<MaskingPolicy> = {}): MaskingPolicy {
  return {
    id: "test-policy-id",
    workspaceId: "test-workspace",
    name: "Test Policy",
    version: 1,
    isDefault: false,
    rules: [],
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

describe("redact strategy", () => {
  it("replaces value with default placeholder", () => {
    expect(redact("sensitive@example.com", {})).toBe("[REDACTED]");
  });

  it("uses a custom replacement string", () => {
    expect(redact("secret", { replacement: "***" })).toBe("***");
  });

  it("returns empty string for null input", () => {
    expect(redact(null, {})).toBe("");
  });

  it("returns empty string for undefined input", () => {
    expect(redact(undefined, {})).toBe("");
  });
});

describe("partialRedact strategy", () => {
  it("keeps first N characters visible", () => {
    const result = partialRedact("john@example.com", { keepFirst: 4, maskChar: "*" });
    expect(result.startsWith("john")).toBe(true);
  });

  it("keeps last N characters visible", () => {
    const result = partialRedact("4111111111111234", { keepLast: 4, maskChar: "*" });
    expect(result.endsWith("1234")).toBe(true);
  });

  it("returns empty string for null input", () => {
    expect(partialRedact(null, {})).toBe("");
  });
});

describe("hash strategy", () => {
  it("produces a non-empty string for a given input", () => {
    const result = hash("test@example.com", { algorithm: "sha256", deterministic: true });
    expect(result).toBeTruthy();
    expect(typeof result).toBe("string");
  });

  it("is deterministic — same input yields same output", () => {
    const a = hash("user@elaro.io", { algorithm: "sha256", deterministic: true });
    const b = hash("user@elaro.io", { algorithm: "sha256", deterministic: true });
    expect(a).toBe(b);
  });

  it("returns different hashes for different inputs", () => {
    const a = hash("alice@example.com", { algorithm: "sha256", deterministic: true });
    const b = hash("bob@example.com", { algorithm: "sha256", deterministic: true });
    expect(a).not.toBe(b);
  });

  it("returns empty string for null input", () => {
    expect(hash(null, { algorithm: "sha256", deterministic: true })).toBe("");
  });
});

describe("POLICY_TEMPLATES", () => {
  it("exports PII_STANDARD template with rules", () => {
    expect(POLICY_TEMPLATES.PII_STANDARD).toBeDefined();
    expect(POLICY_TEMPLATES.PII_STANDARD.rules.length).toBeGreaterThan(0);
  });

  it("exports PCI_DSS template with rules", () => {
    expect(POLICY_TEMPLATES.PCI_DSS).toBeDefined();
    expect(POLICY_TEMPLATES.PCI_DSS.rules.length).toBeGreaterThan(0);
  });

  it("exports HIPAA template with rules", () => {
    expect(POLICY_TEMPLATES.HIPAA).toBeDefined();
    expect(POLICY_TEMPLATES.HIPAA.rules.length).toBeGreaterThan(0);
  });
});

describe("MaskingEngine", () => {
  it("can be instantiated with a policy", () => {
    const engine = new MaskingEngine(makePolicy());
    expect(engine).toBeDefined();
  });

  it("returns original field value unchanged when no rules match", () => {
    const engine = new MaskingEngine(makePolicy());
    const { masked, strategyUsed } = engine.maskField("open data", { sobject: "Account", field: "Name" });
    expect(masked).toBe("open data");
    expect(strategyUsed).toBeNull();
  });

  it("redacts Email fields when using PII_STANDARD policy", () => {
    const engine = new MaskingEngine(
      makePolicy({ rules: [...POLICY_TEMPLATES.PII_STANDARD.rules] as MaskingPolicy["rules"] })
    );
    const { masked, strategyUsed } = engine.maskField("user@example.com", {
      sobject: "Contact",
      field: "Email",
    });
    expect(strategyUsed).toBe("fake");
    expect(masked).not.toBe("user@example.com");
  });

  it("masks an entire record, tracking masked fields", () => {
    const engine = new MaskingEngine(
      makePolicy({ rules: [...POLICY_TEMPLATES.PII_STANDARD.rules] as MaskingPolicy["rules"] })
    );
    const record = { Id: "003abc", Email: "alice@test.com", Name: "Alice Smith" };
    const fieldInfos = new Map([
      ["Email", { sobject: "Contact", field: "Email" }],
      ["Name", { sobject: "Contact", field: "Name" }],
    ]);
    const { maskedRecord, maskedFields } = engine.maskRecord("Contact", record, fieldInfos);
    expect(maskedRecord["Id"]).toBe("003abc");
    expect(maskedFields.length).toBeGreaterThan(0);
  });
});
