# Codex Fix Plan — `platform/` TypeScript (2026-06-05 three-target sweep)

> Source: the read-only audit of the `platform/` monorepo (the TypeScript shipped alongside
> the managed package). `ElaroInstallHandler` and the 3 Visualforce PDF pages were also
> audited in the same sweep and came back **clean** — no fixes needed there.
>
> All findings are CONFIRMED with receipts. Enforced going forward by gates 10–13 in
> `scripts/standards-gates.sh`. Branch convention: `codex/fix-platform-masking-crypto`.

## Context — why these matter

Elaro is a court-defensible compliance platform; the `masking` package exists specifically
to de-identify PII/PHI/PCI. Three of its core strategies use weak or home-rolled crypto in
exactly the functions meant to protect sensitive data — re-identification risk for the
product's load-bearing claim. The CLI has a command-injection pattern (lower risk: local
dev tool, but real under CI/automation). None are Blockers, but the masking ones deserve a
real fix.

---

## P1 — Predictable masking tokens (`Math.random()`)

**Finding (Med, CONFIRMED):** `platform/packages/masking/src/strategies/tokenize.ts:90-95`
```ts
function generateToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let token = 'TOK_';
  for (let i = 0; i < 24; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));  // not crypto-secure
  }
  return token;
}
```
**Fix:** generate with `crypto.randomBytes` (or `crypto.randomInt`), preserving the
`TOK_[A-Z0-9]{24}` shape `isToken()` validates:
```ts
import { randomInt } from 'crypto';
function generateToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let token = 'TOK_';
  for (let i = 0; i < 24; i++) token += chars.charAt(randomInt(chars.length));
  return token;
}
```
**Acceptance:** `grep -n "Math.random" tokenize.ts` → 0; existing tokenize tests still pass;
`isToken(generateToken())` stays true.

## P1 — Home-rolled "format-preserving encryption"

**Finding (Med, CONFIRMED):** `platform/packages/masking/src/strategies/fpe.ts:95-...`
(`formatPreservingEncrypt` per-character `encryptChar` loop). The file comment admits:
`"simplified implementation. For production: Use FF1 or FF3-1 (NIST SP 800-38G)... node-fpe or ff3"`.
**Fix (pick one):**
- (a) Replace `formatPreservingEncrypt` with a vetted FF1/FF3-1 library (`node-fpe` / `ff3`).
- (b) If true format preservation isn't required, route the `fpe` strategy to the existing
  `aes-256-gcm` path already in the same file and drop the "FPE" label so reports don't
  claim NIST FPE.
**Stop and ask:** which of (a)/(b) — depends on whether downstream consumers rely on format
preservation. Default to (a) if the strategy is advertised as FPE in compliance output.
**Acceptance:** no `encryptChar` home-rolled cipher remains; the "simplified implementation"
comment is gone; gate 12 clears.

## P1 — Non-crypto hash (murmur3) + weak salt for PII

**Finding (Med, CONFIRMED):** `platform/packages/masking/src/strategies/hash.ts:18-26` and
`index.ts:180` (the "consistent" profile offers `algorithm: 'murmur3'`).
```ts
const input = options.deterministic ? value : `${value}-${Date.now()}-${Math.random()}`; // weak salt
...
if (options.algorithm === 'murmur3') { return murmurhash.v3(salted)... }  // reversible for low-entropy PII
```
**Fix:** remove the `murmur3` branch for any PII path (keep sha256+); replace the
non-deterministic fallback salt with `crypto.randomBytes(16).toString('hex')`. If murmur3 is
needed for non-PII bucketing/sharding, isolate it behind a clearly non-PII API.
**Acceptance:** gate 11 clears; PII profiles (`pci`, `phi`) only reference sha256+.

## P2 — CLI command injection via interpolated `execSync`

**Finding (Low-Med, CONFIRMED):** `platform/packages/cli/src/commands/org.ts:138,222`,
`status.ts:30` (also `test.ts`, `deploy.ts` flag interpolation).
```ts
execSync(`sf org delete scratch -o ${options.targetOrg} ${promptFlag}`, ...) // targetOrg unsanitized
```
Mitigated by being a local dev CLI (the injector is the developer), but real if driven by CI
or untrusted config. `org.ts:109` already uses the safe `spawn("sf", [...args])` form — be
consistent.
**Fix:** validate org identifiers against `^[A-Za-z0-9._@-]+$` before interpolation, or switch
these calls to `spawn("sf", ["org","delete","scratch","-o", targetOrg, ...])` (no shell).
**Acceptance:** gate 13 clears; a targetOrg of `x; echo pwned` is rejected, not executed.

## P3 — Config values echoed to terminal (possible secret)

**Finding (Low, CONFIRMED):** `platform/packages/cli/src/commands/config.ts:126`
```ts
console.log(chalk.green(`Set ${key} = ${value}`)); // `slack` key is typically a webhook URL w/ secret
```
**Fix:** for sensitive keys (`slack`, `email`, any future token/url key), echo a masked value
(`Set slack = ***`).
**Acceptance:** setting `slack` does not print the URL.

---

## Verified clean (no action)

- No hardcoded secrets, no `eval`/`new Function` anywhere in `platform/`.
- JWT signing: RS256 with a PEM-validated key (`auth/jwt.ts:36,84-86`); key not logged or
  persisted.
- OAuth tokens held in memory; no insecure `writeFileSync`/`localStorage` persistence.
- `masking/fpe.ts` also contains a correct `aes-256-gcm` + `scryptSync` path (the issue is
  only the separate home-rolled `formatPreservingEncrypt`).

## Build / verify

`platform/` is a Turborepo: `cd platform && npm install && npm run build && npm test`. After
fixes, `bash scripts/standards-gates.sh --report` should show gates 10–13 clean.
