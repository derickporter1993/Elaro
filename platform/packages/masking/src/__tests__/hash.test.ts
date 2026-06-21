import { describe, it, expect } from 'vitest';
import { hash } from '../strategies/hash';

const sha = { algorithm: 'sha256' as const };

describe('hash (CSPRNG salt for non-deterministic mode)', () => {
  it('is deterministic when deterministic=true', () => {
    const a = hash('value', { ...sha, deterministic: true });
    const b = hash('value', { ...sha, deterministic: true });
    expect(a).toBe(b);
  });

  it('produces distinct outputs for the same value when non-deterministic', () => {
    const results = new Set<string>();
    for (let i = 0; i < 200; i++) {
      results.add(hash('value', { ...sha, deterministic: false }));
    }
    // Randomness comes from crypto.randomBytes, not Date.now()/Math.random();
    // even rapid successive calls within the same millisecond must differ.
    expect(results.size).toBe(200);
  });

  it('still respects an explicit salt in deterministic mode', () => {
    const salted = hash('value', { ...sha, deterministic: true, salt: 'pepper' });
    const unsalted = hash('value', { ...sha, deterministic: true });
    expect(salted).not.toBe(unsalted);
  });

  it('returns empty string for null/undefined', () => {
    expect(hash(null, { ...sha, deterministic: true })).toBe('');
    expect(hash(undefined, { ...sha, deterministic: true })).toBe('');
  });
});
