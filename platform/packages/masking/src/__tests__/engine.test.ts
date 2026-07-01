import { describe, it, expect } from "vitest";
import type { MaskingPolicy, MaskingRule } from "@platform/types";

import { MaskingEngine, calculateEffectivenessScore, type FieldInfo } from "../engine";
import { POLICY_TEMPLATES } from "../index";

function makePolicy(rules: MaskingRule[]): MaskingPolicy {
  return {
    id: "policy-1",
    workspaceId: "ws-1",
    name: "Test Policy",
    version: 1,
    rules,
    isDefault: false,
    createdAt: new Date("2026-01-01"),
    updatedAt: new Date("2026-01-01"),
  };
}

describe("MaskingEngine.maskField", () => {
  it("applies a matching pattern rule", () => {
    const engine = new MaskingEngine(
      makePolicy([
        {
          id: "ssn",
          matcher: { type: "pattern", fieldNameRegex: ".*SSN.*" },
          strategy: { type: "redact", replacement: "XXX-XX-XXXX" },
          priority: 0,
        },
      ])
    );

    const { masked, strategyUsed } = engine.maskField("123-45-6789", {
      sobject: "Contact",
      field: "SSN__c",
    });

    expect(masked).toBe("XXX-XX-XXXX");
    expect(strategyUsed).toBe("redact");
  });

  it("returns the original value when no rule matches", () => {
    const engine = new MaskingEngine(makePolicy([]));
    const { masked, strategyUsed } = engine.maskField("keep-me", {
      sobject: "Contact",
      field: "Nickname__c",
    });

    expect(masked).toBe("keep-me");
    expect(strategyUsed).toBeNull();
  });

  it("supports exact field matchers", () => {
    const engine = new MaskingEngine(
      makePolicy([
        {
          id: "exact",
          matcher: { type: "exact", sobject: "Account", field: "Secret__c" },
          strategy: { type: "redact", replacement: "***" },
          priority: 0,
        },
      ])
    );

    expect(engine.maskField("v", { sobject: "Account", field: "Secret__c" }).strategyUsed).toBe(
      "redact"
    );
    expect(
      engine.maskField("v", { sobject: "Contact", field: "Secret__c" }).strategyUsed
    ).toBeNull();
  });

  it("supports classification matchers", () => {
    const engine = new MaskingEngine(
      makePolicy([
        {
          id: "pii",
          matcher: { type: "classification", tag: "pii" },
          strategy: { type: "redact", replacement: "***" },
          priority: 0,
        },
      ])
    );

    const info: FieldInfo = { sobject: "Contact", field: "Any__c", classification: ["pii"] };
    expect(engine.maskField("v", info).strategyUsed).toBe("redact");
  });

  it("uses an email format hint for email data-type fields with a hash strategy", () => {
    const engine = new MaskingEngine(
      makePolicy([
        {
          id: "email",
          matcher: { type: "data_type", sfType: "email" },
          strategy: { type: "hash", algorithm: "sha256", deterministic: true },
          priority: 0,
        },
      ])
    );

    const { masked } = engine.maskField("a@b.com", {
      sobject: "Contact",
      field: "Email",
      dataType: "email",
    });
    expect(String(masked)).toMatch(/@masked\.example\.com$/);
  });

  it("honors rule priority (lowest number wins)", () => {
    const engine = new MaskingEngine(
      makePolicy([
        {
          id: "low-priority",
          matcher: { type: "pattern", fieldNameRegex: ".*Data.*" },
          strategy: { type: "redact", replacement: "[LOW]" },
          priority: 5,
        },
        {
          id: "high-priority",
          matcher: { type: "pattern", fieldNameRegex: ".*Data.*" },
          strategy: { type: "redact", replacement: "[HIGH]" },
          priority: 0,
        },
      ])
    );

    expect(engine.maskField("x", { sobject: "Account", field: "Data__c" }).masked).toBe("[HIGH]");
  });

  it("only applies a rule when its conditions are satisfied", () => {
    const engine = new MaskingEngine(
      makePolicy([
        {
          id: "conditional",
          matcher: { type: "pattern", fieldNameRegex: ".*Amount.*" },
          strategy: { type: "redact", replacement: "***" },
          priority: 0,
          conditions: [{ field: "Country__c", operator: "equals", value: "US" }],
        },
      ])
    );

    expect(
      engine.maskField("100", { sobject: "Deal", field: "Amount__c" }, { Country__c: "US" })
        .strategyUsed
    ).toBe("redact");
    expect(
      engine.maskField("100", { sobject: "Deal", field: "Amount__c" }, { Country__c: "CA" })
        .strategyUsed
    ).toBeNull();
  });
});

describe("MaskingEngine record helpers", () => {
  const engine = () =>
    new MaskingEngine(
      makePolicy([
        {
          id: "email",
          matcher: { type: "pattern", fieldNameRegex: ".*Email.*" },
          strategy: { type: "redact", replacement: "hidden@example.com" },
          priority: 0,
        },
      ])
    );

  it("masks matching fields in a record and reports which were masked", () => {
    const { maskedRecord, maskedFields } = engine().maskRecord(
      "Contact",
      { Email: "real@corp.com", Name: "Jane" },
      new Map()
    );

    expect(maskedRecord.Email).toBe("hidden@example.com");
    expect(maskedRecord.Name).toBe("Jane");
    expect(maskedFields).toEqual(["Email"]);
  });

  it("aggregates counts and a per-field summary across a batch", () => {
    const { maskedRecords, maskedFieldsCount, fieldMaskingSummary } = engine().maskRecords(
      "Contact",
      [
        { Email: "a@corp.com", Name: "A" },
        { Email: "b@corp.com", Name: "B" },
      ],
      new Map()
    );

    expect(maskedRecords).toHaveLength(2);
    expect(maskedFieldsCount).toBe(2);
    expect(fieldMaskingSummary.get("Email")).toBe(2);
  });

  it("generates a preview that skips Id and can hide originals", () => {
    const previewHidden = engine().generatePreview(
      "Contact",
      [{ Id: "003", Email: "real@corp.com" }],
      new Map()
    );
    const field = previewHidden.sampleRecords[0]?.fields[0];
    expect(field?.name).toBe("Email");
    expect(field?.original).toBeUndefined();
    expect(field?.masked).toBe("hidden@example.com");

    const previewShown = engine().generatePreview(
      "Contact",
      [{ Id: "003", Email: "real@corp.com" }],
      new Map(),
      true
    );
    expect(previewShown.sampleRecords[0]?.fields[0]?.original).toBe("real@corp.com");
  });
});

describe("calculateEffectivenessScore", () => {
  it("scores 100 when there are no PII fields", () => {
    const result = calculateEffectivenessScore(makePolicy([]), []);
    expect(result.score).toBe(100);
    expect(result.gaps).toHaveLength(0);
  });

  it("reports masked coverage and gaps with suggested strategies", () => {
    const policy = makePolicy([
      {
        id: "email",
        matcher: { type: "pattern", fieldNameRegex: ".*Email.*" },
        strategy: { type: "fake", generator: "email" },
        priority: 0,
      },
    ]);

    const piiFields: FieldInfo[] = [
      { sobject: "Contact", field: "Email" },
      { sobject: "Contact", field: "SSN__c" },
    ];

    const result = calculateEffectivenessScore(policy, piiFields);
    expect(result.piiFieldsIdentified).toBe(2);
    expect(result.piiFieldsMasked).toBe(1);
    expect(result.score).toBe(50);
    expect(result.gaps).toHaveLength(1);
    expect(result.gaps[0]?.field).toBe("SSN__c");
    expect(result.gaps[0]?.suggestedStrategy).toBe("redact");
  });
});

describe("POLICY_TEMPLATES", () => {
  it("exposes the expected built-in templates", () => {
    expect(Object.keys(POLICY_TEMPLATES)).toEqual([
      "PII_STANDARD",
      "PCI_DSS",
      "HIPAA",
      "DETERMINISTIC",
    ]);
  });

  it("PII_STANDARD redacts SSN with a fixed mask", () => {
    const ssnRule = POLICY_TEMPLATES.PII_STANDARD.rules.find((r) => r.id === "ssn");
    expect(ssnRule?.strategy).toMatchObject({ type: "redact", replacement: "XXX-XX-XXXX" });
  });

  it("drives the engine end-to-end using a template's rules", () => {
    const engine = new MaskingEngine(
      makePolicy(POLICY_TEMPLATES.PCI_DSS.rules as unknown as MaskingRule[])
    );
    const { masked, strategyUsed } = engine.maskField("4111111111111111", {
      sobject: "Payment__c",
      field: "Card_Number__c",
    });
    expect(strategyUsed).toBe("redact");
    expect(masked).toBe("**** **** **** ****");
  });
});
