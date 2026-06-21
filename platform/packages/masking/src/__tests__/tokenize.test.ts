import { describe, it, expect, beforeEach } from 'vitest';
import { tokenize, detokenize, initVault, isToken, clearVault } from '../strategies/tokenize';

const VAULT = 'test-vault';
const opts = { vaultRef: VAULT };

describe('tokenize (CSPRNG token generation)', () => {
  beforeEach(() => {
    initVault(VAULT);
    clearVault(VAULT);
  });

  it('produces tokens that match the documented format', () => {
    const token = tokenize('sensitive-value', opts);
    expect(token).toMatch(/^TOK_[A-Z0-9]{24}$/);
    expect(isToken(token)).toBe(true);
  });

  it('only uses the allowed charset', () => {
    const allowed = new Set('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.split(''));
    for (let i = 0; i < 50; i++) {
      const body = tokenize(`value-${i}`, opts).slice('TOK_'.length);
      for (const ch of body) {
        expect(allowed.has(ch)).toBe(true);
      }
    }
  });

  it('generates non-repeating tokens across calls for distinct values', () => {
    const tokens = new Set<string>();
    for (let i = 0; i < 500; i++) {
      tokens.add(tokenize(`unique-${i}`, opts));
    }
    // CSPRNG with 36^24 space => collisions astronomically unlikely.
    expect(tokens.size).toBe(500);
  });

  it('is stable for the same input (vault re-use)', () => {
    const a = tokenize('same', opts);
    const b = tokenize('same', opts);
    expect(a).toBe(b);
  });

  it('round-trips via detokenize', () => {
    const token = tokenize('round-trip', opts);
    expect(detokenize(token, opts)).toBe('round-trip');
  });
});
