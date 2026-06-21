# Codex Fix Plan — `platform/` TypeScript (masking + CLI)

> **Branch:** `codex/fix-platform-masking` from current `main`
> **Scope:** the `platform/` Turborepo monorepo shipped alongside the managed package. Four issues clustered into one PR-able branch: 3 weak-crypto sites in the **PII-protection library** (the worst possible place to ship weak crypto in a compliance product), 1 CLI command-injection pattern across 3 CLI commands, and a config-echo information disclosure.
> **Severity:** Med-High in aggregate. The masking issues are the most product-damaging because the masking library's job is to de-identify PII/PHI/PCI — predictable tokens, home-rolled FPE, and reversible hashes defeat the product's load-bearing claim.
> **Estimated effort:** ~1 day, single PR. One stop-and-ask: FF1/FF3-1 library choice.
> **Standards aligned:** standards-gates.sh §10-13 (Math.random for secrets, weak-hash-in-PII, home-rolled crypto, interpolated execSync) — if those gates don't exist at HEAD, they're added in this PR.

## P1 — Predictable masking tokens via `Math.random()`

**File:** `platform/packages/masking/src/strategies/tokenize.ts:93`
**Current:**
```ts
function generateToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let token = 'TOK_';
  for (let i = 0; i < 24; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return token;
}
```
**Impact:** `Math.random()` in V8 is xorshift128+, not cryptographically secure. The 24-char `TOK_[A-Z0-9]{24}` token is predictable enough that vault-token enumeration is feasible against the PII vault these tokens index. Undermines the entire tokenization scheme.
**Fix:**
```ts
import { randomInt } from 'crypto';

function generateToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let token = 'TOK_';
  for (let i = 0; i < 24; i++) {
    token += chars.charAt(randomInt(chars.length));
  }
  return token;
}
```
**Acceptance:**
- `grep -n "Math.random" platform/packages/masking/src/strategies/tokenize.ts` → 0 hits
- `isToken(generateToken())` continues to return true (format preserved: `TOK_[A-Z0-9]{24}`)
- Existing tokenize tests still pass; add `shouldUseCryptographicRandomness` that calls `generateToken()` 1000× and asserts the per-position character distribution shows χ² consistent with uniform (catches a regression to a weak PRNG)

## P2 — Home-rolled "Format-Preserving Encryption"

**File:** `platform/packages/masking/src/strategies/fpe.ts:97-...` (`formatPreservingEncrypt` function)
**Current:** a per-character `encryptChar` loop. The file's own comment at line 97 admits the situation:
```
// This is a simplified implementation. For production:
// - Use FF1 or FF3-1 algorithm (NIST SP 800-38G)
// - Consider libraries like `node-fpe` or `ff3`
```
**Impact:** rolling your own char-by-char "cipher" for PII is cryptographically unsafe — it leaks character frequency and adjacent-character correlations. The same file ALSO contains a correct `aes-256-gcm` path with `scryptSync` key derivation; the issue is specifically the home-rolled FPE function.
**Fix — pick one (Codex MUST ask first):**
- **(a) Replace `formatPreservingEncrypt` with a vetted FF1/FF3-1 library.** Add `ff3` (or `node-fpe`) to `platform/packages/masking/package.json`. Implement `formatPreservingEncrypt` as a thin wrapper. ~3 hours.
- **(b) Drop the FPE label entirely.** Route the `fpe` strategy in `index.ts` to the existing `aes-256-gcm` path. Remove `formatPreservingEncrypt`/`encryptChar` and the FPE strategy export. Update `MaskingProfile` types. ~1 hour, but breaks any consumer relying on format preservation.
**Stop and ask:** which? If downstream code or product positioning advertises NIST FF1/FF3 format preservation, must be (a). If FPE was speculative, (b) is cleaner.
**Acceptance:**
- the literal comment `simplified implementation` is gone from `fpe.ts`
- `grep -n "encryptChar\|formatPreservingEncrypt" platform/packages/masking/src/strategies/fpe.ts` → 0 hits (Option b) or 1 hit (Option a wrapping the library)
- existing `aes-256-gcm` path is untouched

## P3 — `murmur3` for PII hashing + weak fallback salt

**File:** `platform/packages/masking/src/strategies/hash.ts:2,18-26`; `platform/packages/masking/src/index.ts:180`
**Current:**
```ts
// hash.ts
import murmurhash from 'murmurhash';
...
const input = options.deterministic
    ? value
    : `${value}-${Date.now()}-${Math.random()}`;     // weak salt
const salted = options.salt ? `${input}${options.salt}` : input;
if (options.algorithm === 'murmur3') {
    const hashValue = murmurhash.v3(salted);          // non-cryptographic; reversible for low-entropy PII
    return hashValue.toString(16).padStart(8, '0');
}
```
And in `index.ts:180`, the "consistent" profile actively chooses `algorithm: 'murmur3'`.
**Impact:**
- MurmurHash3 is a hash for hashtables, not cryptography. For low-entropy PII (SSN = 10^9 possibilities, fits in a 32-bit hash with collisions), a precomputed rainbow table reverses it trivially.
- The non-deterministic fallback salt is `Date.now() + Math.random()` — both predictable in V8.
**Fix:**
1. **`hash.ts`:** remove the `murmur3` branch entirely. Drop the `murmurhash` import. The `algorithm` enum should only accept cryptographic hashes (`sha256` / `sha512`).
2. **`hash.ts`:** replace the fallback salt with crypto-random bytes:
   ```ts
   import { randomBytes } from 'crypto';
   const salt = options.salt ?? randomBytes(16).toString('hex');
   const salted = `${value}${salt}`;
   const hashBuffer = createHash('sha256').update(salted).digest('hex');
   ```
3. **`index.ts:180`:** the "consistent" profile must change `algorithm: 'murmur3'` → `algorithm: 'sha256'`.
4. **`package.json`:** remove `murmurhash` from `dependencies` if it has no other consumer.
**Acceptance:**
- `grep -rn "murmur" platform/packages/masking/` → 0 hits
- `grep -rn "Math\.random\|Date\.now\(\) *\+.*Math" platform/packages/masking/src/strategies/hash.ts` → 0 hits
- existing sha256 path tests still pass; new `shouldRejectMurmur3` test verifies that passing `algorithm: 'murmur3'` throws or returns sha256

## P4 — CLI command injection via interpolated `execSync`

**Files:** `platform/packages/cli/src/commands/org.ts:138`, `:222`; `platform/packages/cli/src/commands/status.ts:30` (and possibly `test.ts`, `deploy.ts` flag interpolation — verify)
**Current:**
```ts
execSync(`sf org delete scratch -o ${options.targetOrg} ${promptFlag}`, ...) // org.ts:222
execSync(`sf org open ${orgFlag}`, ...)                                       // org.ts:138
execSync(`sf org display ${orgFlag} --json`, ...)                              // status.ts:30
```
**Impact:** mitigated by being a local dev CLI (the injector is the developer), but real if ever driven by CI/automation/an untrusted config. A `targetOrg` of `"x; rm -rf ~"` executes the second command. The codebase has a safe precedent at `org.ts:109` using the `spawn("sf", [...args])` array form — just be consistent.
**Fix:** replace all `execSync(\`sf ... ${var}\`)` with one of:
- **Preferred:** `spawn("sf", ["org", "delete", "scratch", "-o", options.targetOrg, ...])` — no shell, no interpolation, var is a literal argument
- **If `execSync` must stay** (for the inline `output = ...` pattern): validate `targetOrg` against `/^[A-Za-z0-9._@-]+$/` and throw on mismatch *before* interpolation
**Acceptance:**
- `bash scripts/standards-gates.sh --report` shows §13 (interpolated execSync) clears for `org.ts` and `status.ts`
- a new `org.test.ts` test passes `targetOrg = "x; echo pwned"` and asserts the CLI rejects it OR (with spawn-array form) that no shell expansion occurs

## P5 — Config values echoed to terminal (likely-secret leak)

**File:** `platform/packages/cli/src/commands/config.ts:126`
**Current:**
```ts
console.log(chalk.green(`Set ${key} = ${value}`));
```
**Impact:** the `slack` config key is typically a webhook URL embedding a per-org secret token. Echoing it back to the terminal exposes it to shell history, screen recordings, shared terminals.
**Fix:** mask values for sensitive keys:
```ts
const SENSITIVE_KEYS = new Set(['slack', 'email', 'webhook', 'token', 'apiKey']);
const displayValue = SENSITIVE_KEYS.has(key) ? '***' : value;
console.log(chalk.green(`Set ${key} = ${displayValue}`));
```
**Acceptance:** setting `slack` no longer prints the URL; non-sensitive keys still display their value for normal config UX

## §6 — Standards-gates additions (this PR commits them too)

If `scripts/standards-gates.sh` exists, add the following gates 10-13 (skip if already present). If the file doesn't exist, this PR establishes it. Each gate scans **all** packageDirectories + `platform/packages/*/src`:

```bash
# Gate 10: Math.random() for tokens/secrets/salts in masking
grep -rnE "Math\.random\(\)" platform/packages/*/src 2>/dev/null \
  | grep -iE "token|salt|secret|key|nonce|iv|password" \
  | hit "no Math.random() for tokens/secrets/salts" "Use crypto.randomBytes/randomInt."

# Gate 11: weak hash in masking/PII paths
grep -rnE "murmur|md5|sha1[^0-9]" platform/packages/masking/src 2>/dev/null \
  | grep -viE "//|sha1[0-9]" \
  | hit "no weak hash (murmur/md5/sha1) in masking" "Use sha256+ for PII hashing."

# Gate 12: home-rolled crypto
grep -rniE "simplified implementation|for production:|home-?rolled" platform/packages/masking/src 2>/dev/null \
  | hit "no home-rolled/placeholder crypto in masking" "Use a vetted library."

# Gate 13: shell interpolation
grep -rnE "(execSync|exec)\(\s*\`[^\`]*\\\$\{" platform/packages/cli/src 2>/dev/null \
  | hit "no shell command from interpolated variables" "Use spawn([args]) or validate first."
```

## Verification (CI-equivalent, local)

```bash
cd platform && npm install && npm run build && npm test
cd ..
bash scripts/standards-gates.sh --report   # gates 10-13 should clear for the fixed sites
npm run test:unit                            # Apex/LWC suite unaffected — should stay 900/900
```

## What this PR explicitly does NOT touch

- `fake.ts`, `redact.ts` — not security-critical, not in scope
- `aes-256-gcm` path in `fpe.ts` — already correct, do not modify
- `sha256` branch in `hash.ts` — already correct, only the `murmur3` branch is removed
- `WolframLanguageEvaluator` or any other external integration not in the masking lib

## Stop-and-ask triggers

1. **P2 (FPE):** Option (a) library or Option (b) drop the strategy — needs user input before implementation. Default is (a) if any external docs claim FPE compliance.
2. **P3 (murmur3):** if `murmurhash` is consumed elsewhere in `platform/` (verify with `grep -rn murmur platform/`), removing it from masking's `package.json` may need a workspace-level decision.
3. **P4 (execSync):** if `test.ts` and `deploy.ts` also interpolate user-supplied flags, this scope expands by ~2 hours. Codex should report the additional sites before deciding the PR shape.
