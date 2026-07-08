import { describe, it, expect, beforeEach } from "vitest";

import { redact, partialRedact } from "../strategies/redact";
import { hash, hashWithFormatHint } from "../strategies/hash";
import { fake, fakeDeterministic } from "../strategies/fake";
import { fpeEncrypt, fpeDecrypt, registerKey, generateKey } from "../strategies/fpe";
import {
  tokenize,
  detokenize,
  initVault,
  isToken,
  getVaultStats,
  clearVault,
} from "../strategies/tokenize";

describe("redact", () => {
  it("returns the configured replacement", () => {
    expect(redact("4111111111111111", { replacement: "****" })).toBe("****");
  });

  it("defaults to [REDACTED] when no replacement is provided", () => {
    expect(redact("secret", {})).toBe("[REDACTED]");
  });

  it("returns an empty string for null or undefined input", () => {
    expect(redact(null, { replacement: "x" })).toBe("");
    expect(redact(undefined, { replacement: "x" })).toBe("");
  });
});

describe("partialRedact", () => {
  it("keeps the last N characters visible", () => {
    expect(partialRedact("4111111111111111", { keepLast: 4 })).toBe("************1111");
  });

  it("keeps the first N characters visible", () => {
    expect(partialRedact("password", { keepFirst: 2 })).toBe("pa******");
  });

  it("supports a custom mask character", () => {
    expect(partialRedact("abcd", { keepFirst: 1, maskChar: "#" })).toBe("a###");
  });

  it("returns the original value when keep counts cover the whole string", () => {
    expect(partialRedact("ab", { keepFirst: 1, keepLast: 1 })).toBe("ab");
  });

  it("returns an empty string for empty, null, or undefined input", () => {
    expect(partialRedact("", { keepFirst: 2 })).toBe("");
    expect(partialRedact(null, { keepFirst: 2 })).toBe("");
    expect(partialRedact(undefined, { keepFirst: 2 })).toBe("");
  });
});

describe("hash", () => {
  it("is deterministic for the same input in deterministic mode (sha256)", () => {
    const a = hash("patient@example.com", { algorithm: "sha256", deterministic: true });
    const b = hash("patient@example.com", { algorithm: "sha256", deterministic: true });
    expect(a).toBe(b);
    expect(a).toMatch(/^[0-9a-f]{16}$/);
  });

  it("produces different output for different inputs", () => {
    const a = hash("alice", { algorithm: "sha256", deterministic: true });
    const b = hash("bob", { algorithm: "sha256", deterministic: true });
    expect(a).not.toBe(b);
  });

  it("changes output when a salt is applied", () => {
    const unsalted = hash("value", { algorithm: "sha256", deterministic: true });
    const salted = hash("value", { algorithm: "sha256", deterministic: true, salt: "pepper" });
    expect(salted).not.toBe(unsalted);
  });

  it("supports the murmur3 algorithm with an 8-char hex digest", () => {
    const a = hash("value", { algorithm: "murmur3", deterministic: true });
    const b = hash("value", { algorithm: "murmur3", deterministic: true });
    expect(a).toBe(b);
    expect(a).toMatch(/^[0-9a-f]{8}$/);
  });

  it("returns an empty string for null or undefined input", () => {
    expect(hash(null, { algorithm: "sha256", deterministic: true })).toBe("");
    expect(hash(undefined, { algorithm: "sha256", deterministic: true })).toBe("");
  });
});

describe("hashWithFormatHint", () => {
  it("preserves an email-like shape", () => {
    const result = hashWithFormatHint("a@b.com", {
      algorithm: "sha256",
      deterministic: true,
      formatHint: "email",
    });
    expect(result).toMatch(/^[0-9a-f]{16}@masked\.example\.com$/);
  });

  it("preserves a phone-like shape", () => {
    const result = hashWithFormatHint("5551234567", {
      algorithm: "sha256",
      deterministic: true,
      formatHint: "phone",
    });
    expect(result).toMatch(/^555-[0-9a-f]{3}-[0-9a-f]{4}$/);
  });

  it("falls back to the raw hash without a format hint", () => {
    const result = hashWithFormatHint("value", { algorithm: "sha256", deterministic: true });
    expect(result).toMatch(/^[0-9a-f]{16}$/);
  });

  it("returns an empty string for null input", () => {
    expect(hashWithFormatHint(null, { algorithm: "sha256", deterministic: true })).toBe("");
  });
});

describe("fake", () => {
  it("is deterministic for the same input value", () => {
    const a = fakeDeterministic("seed-value", { generator: "name" });
    const b = fakeDeterministic("seed-value", { generator: "name" });
    expect(a).toBe(b);
    expect(a.length).toBeGreaterThan(0);
  });

  it("generates an email-shaped value", () => {
    const result = fake("x", { generator: "email", deterministic: true });
    expect(result).toContain("@");
  });

  it("generates an SSN-shaped value", () => {
    const result = fake("x", { generator: "ssn", deterministic: true });
    expect(result).toMatch(/^\d{3}-\d{2}-\d{4}$/);
  });

  it("still returns a value when the input is null", () => {
    const result = fake(null, { generator: "text" });
    expect(typeof result).toBe("string");
    expect(result.length).toBeGreaterThan(0);
  });
});

describe("fpe", () => {
  const keyId = "unit-test-key";

  beforeEach(() => {
    registerKey(keyId, Buffer.alloc(32, 7));
  });

  it("round-trips a value with format preservation", () => {
    const original = "Abc-1234";
    const encrypted = fpeEncrypt(original, { keyId, preserveFormat: true });
    expect(encrypted).not.toBe(original);
    expect(encrypted).toHaveLength(original.length);
    // Non-alphanumeric characters are preserved in place.
    expect(encrypted[3]).toBe("-");
    expect(fpeDecrypt(encrypted, { keyId, preserveFormat: true })).toBe(original);
  });

  it("round-trips a value without format preservation", () => {
    const original = "sensitive-value";
    const encrypted = fpeEncrypt(original, { keyId, preserveFormat: false });
    expect(encrypted).not.toBe(original);
    expect(fpeDecrypt(encrypted, { keyId, preserveFormat: false })).toBe(original);
  });

  it("works with a passphrase-generated key", () => {
    generateKey("generated-key", "correct horse battery staple");
    const encrypted = fpeEncrypt("hello", { keyId: "generated-key", preserveFormat: false });
    expect(fpeDecrypt(encrypted, { keyId: "generated-key", preserveFormat: false })).toBe("hello");
  });

  it("throws when the key is not registered", () => {
    expect(() => fpeEncrypt("value", { keyId: "missing", preserveFormat: true })).toThrow(
      /FPE key not found/
    );
  });

  it("returns an empty string for empty or nullish input", () => {
    expect(fpeEncrypt("", { keyId, preserveFormat: true })).toBe("");
    expect(fpeEncrypt(null, { keyId, preserveFormat: true })).toBe("");
  });
});

describe("tokenize", () => {
  const vaultRef = "unit-test-vault";

  beforeEach(() => {
    initVault(vaultRef);
    clearVault(vaultRef);
  });

  it("throws when the vault is not initialized", () => {
    expect(() => tokenize("value", { vaultRef: "never-initialized" })).toThrow(
      /Token vault not initialized/
    );
  });

  it("produces a recognizable token and detokenizes back to the original", () => {
    const token = tokenize("john.doe@example.com", { vaultRef });
    expect(isToken(token)).toBe(true);
    expect(detokenize(token, { vaultRef })).toBe("john.doe@example.com");
  });

  it("returns the same token for the same value (referential consistency)", () => {
    const first = tokenize("repeat", { vaultRef });
    const second = tokenize("repeat", { vaultRef });
    expect(first).toBe(second);
    expect(getVaultStats(vaultRef).tokenCount).toBe(1);
  });

  it("returns null when detokenizing an unknown token", () => {
    expect(detokenize("TOK_UNKNOWNUNKNOWNUNKNOWN00", { vaultRef })).toBeNull();
  });

  it("reports vault stats and initialization state", () => {
    tokenize("a", { vaultRef });
    tokenize("b", { vaultRef });
    const stats = getVaultStats(vaultRef);
    expect(stats.initialized).toBe(true);
    expect(stats.tokenCount).toBe(2);
    expect(getVaultStats("does-not-exist").initialized).toBe(false);
  });

  it("returns an empty string for null input", () => {
    expect(tokenize(null, { vaultRef })).toBe("");
  });
});

describe("isToken", () => {
  it("recognizes valid token format only", () => {
    expect(isToken("TOK_ABCDEFGHIJKLMNOPQRSTUVWX")).toBe(true);
    expect(isToken("not-a-token")).toBe(false);
    expect(isToken("TOK_short")).toBe(false);
  });
});
