import { describe, it, expect, beforeAll } from 'vitest';
import { randomBytes } from 'crypto';
import { fpeEncrypt, fpeDecrypt, registerKey } from '../strategies/fpe';

const KEY_ID = 'test-key';

beforeAll(() => {
  registerKey(KEY_ID, randomBytes(32));
});

describe('fpe AES-256-GCM path (preserveFormat=false)', () => {
  const opts = { keyId: KEY_ID, preserveFormat: false };

  it('round-trips via authenticated encryption', () => {
    const value = 'secret@example.com';
    const enc = fpeEncrypt(value, opts);
    expect(enc).not.toBe(value);
    expect(fpeDecrypt(enc, opts)).toBe(value);
  });

  it('throws for unknown key', () => {
    expect(() => fpeEncrypt('x', { keyId: 'missing', preserveFormat: false })).toThrow(
      /key not found/i
    );
  });
});

describe('fpe format-preserving obfuscation (preserveFormat=true)', () => {
  const opts = { keyId: KEY_ID, preserveFormat: true };

  it('throws by default without explicit opt-in (encrypt)', () => {
    expect(() => fpeEncrypt('abc123', opts)).toThrow(/NIST SP 800-38G/);
  });

  it('throws by default without explicit opt-in (decrypt)', () => {
    expect(() => fpeDecrypt('abc123', opts)).toThrow(/allowInsecureObfuscation/);
  });

  it('round-trips when explicitly opted in', () => {
    const value = 'Abc-123';
    const enc = fpeEncrypt(value, opts, { allowInsecureObfuscation: true });
    expect(enc).not.toBe(value);
    // Non-alphanumeric characters are preserved (format-preserving).
    expect(enc).toMatch(/^[A-Za-z]{3}-[0-9]{3}$/);
    const dec = fpeDecrypt(enc, opts, { allowInsecureObfuscation: true });
    expect(dec).toBe(value);
  });
});
