import { createCipheriv, createDecipheriv, randomBytes, scryptSync } from 'crypto';
import type { FpeStrategy } from '@platform/types';

/**
 * Format-Preserving Encryption (FPE) strategy
 *
 * Two transforms are available:
 * - The non-format-preserving path uses authenticated AES-256-GCM and is
 *   cryptographically sound.
 * - The format-preserving path is a simple character-shift transform. It is
 *   NOT a real Format-Preserving Encryption cipher (NOT NIST SP 800-38G FF1/
 *   FF3-1) and provides only weak obfuscation. It is gated behind an explicit
 *   opt-in flag and throws by default so it is never shipped silently.
 *
 * For genuine format-preserving encryption, integrate a vetted FF1/FF3-1
 * library (e.g. node-fpe or ff3-1) instead of the obfuscation path below.
 *
 * Key management:
 * - keyId references a key stored in the secrets vault
 * - Keys should be rotated periodically
 * - Decryption is possible for authorized users
 */

/**
 * Error message returned when the non-certified format-preserving obfuscation
 * is used without explicit opt-in.
 */
const INSECURE_FPE_ERROR =
  'Format-preserving obfuscation is NOT a NIST SP 800-38G FPE cipher and is ' +
  'cryptographically weak. To use it you must explicitly opt in by passing ' +
  '`allowInsecureObfuscation: true`. For real format-preserving encryption, ' +
  'integrate a vetted FF1/FF3-1 library (e.g. node-fpe or ff3-1).';

// Simulated key store (in production, use KMS/Vault)
const keyStore = new Map<string, Buffer>();

export function registerKey(keyId: string, key: Buffer): void {
  keyStore.set(keyId, key);
}

export function generateKey(keyId: string, passphrase: string): void {
  const salt = randomBytes(16);
  const key = scryptSync(passphrase, salt, 32);
  keyStore.set(keyId, key);
}

/**
 * Options that gate the non-certified format-preserving obfuscation path.
 *
 * Setting `allowInsecureObfuscation` to `true` is an explicit acknowledgement
 * that the format-preserving transform is weak obfuscation, NOT real FPE.
 */
export interface FpeObfuscationOptions {
  allowInsecureObfuscation?: boolean;
}

/**
 * Format-preserving encrypt
 *
 * With `preserveFormat: false` (the default-safe path) this uses authenticated
 * AES-256-GCM. With `preserveFormat: true` it uses a weak, non-certified
 * format-preserving obfuscation that must be explicitly enabled via
 * `extra.allowInsecureObfuscation`; otherwise it throws.
 */
export function fpeEncrypt(
  value: string | null | undefined,
  options: Omit<FpeStrategy, 'type'>,
  extra: FpeObfuscationOptions = {}
): string {
  if (value === null || value === undefined || value.length === 0) {
    return '';
  }

  const key = keyStore.get(options.keyId);
  if (!key) {
    throw new Error(`FPE key not found: ${options.keyId}`);
  }

  if (options.preserveFormat) {
    if (!extra.allowInsecureObfuscation) {
      throw new Error(INSECURE_FPE_ERROR);
    }
    return formatPreservingObfuscate(value, key);
  }

  // Non-format-preserving path: authenticated AES-256-GCM.
  return simpleEncrypt(value, key);
}

/**
 * Format-preserving decrypt (for authorized users)
 *
 * Mirrors {@link fpeEncrypt}: the format-preserving path requires
 * `extra.allowInsecureObfuscation` and throws by default.
 */
export function fpeDecrypt(
  encryptedValue: string,
  options: Omit<FpeStrategy, 'type'>,
  extra: FpeObfuscationOptions = {}
): string {
  const key = keyStore.get(options.keyId);
  if (!key) {
    throw new Error(`FPE key not found: ${options.keyId}`);
  }

  if (options.preserveFormat) {
    if (!extra.allowInsecureObfuscation) {
      throw new Error(INSECURE_FPE_ERROR);
    }
    return formatPreservingDeobfuscate(encryptedValue, key);
  }

  return simpleDecrypt(encryptedValue, key);
}

/**
 * Simple AES encryption (base64 output)
 */
function simpleEncrypt(value: string, key: Buffer): string {
  const iv = randomBytes(16);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return Buffer.concat([iv, authTag, encrypted]).toString('base64');
}

function simpleDecrypt(encrypted: string, key: Buffer): string {
  const buffer = Buffer.from(encrypted, 'base64');
  const iv = buffer.subarray(0, 16);
  const authTag = buffer.subarray(16, 32);
  const encryptedText = buffer.subarray(32);
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(authTag);
  return decipher.update(encryptedText) + decipher.final('utf8');
}

/**
 * Format-preserving obfuscation (NOT NIST SP 800-38G FPE).
 *
 * WARNING: This is a simple per-character shift, not a real FPE cipher. It is
 * cryptographically weak and is only reachable behind the
 * `allowInsecureObfuscation` opt-in. For production-grade format-preserving
 * encryption use FF1 or FF3-1 (e.g. `node-fpe` or `ff3-1`).
 */
function formatPreservingObfuscate(value: string, key: Buffer): string {
  const result: string[] = [];

  for (let i = 0; i < value.length; i++) {
    const char = value[i];
    if (!char) continue;

    if (/[a-z]/.test(char)) {
      result.push(encryptChar(char, key, i, 'a', 26));
    } else if (/[A-Z]/.test(char)) {
      result.push(encryptChar(char, key, i, 'A', 26));
    } else if (/[0-9]/.test(char)) {
      result.push(encryptChar(char, key, i, '0', 10));
    } else {
      // Preserve non-alphanumeric characters
      result.push(char);
    }
  }

  return result.join('');
}

/**
 * Inverse of {@link formatPreservingObfuscate} (NOT NIST SP 800-38G FPE).
 */
function formatPreservingDeobfuscate(encrypted: string, key: Buffer): string {
  const result: string[] = [];

  for (let i = 0; i < encrypted.length; i++) {
    const char = encrypted[i];
    if (!char) continue;

    if (/[a-z]/.test(char)) {
      result.push(decryptChar(char, key, i, 'a', 26));
    } else if (/[A-Z]/.test(char)) {
      result.push(decryptChar(char, key, i, 'A', 26));
    } else if (/[0-9]/.test(char)) {
      result.push(decryptChar(char, key, i, '0', 10));
    } else {
      result.push(char);
    }
  }

  return result.join('');
}

function encryptChar(
  char: string,
  key: Buffer,
  position: number,
  base: string,
  range: number
): string {
  const offset = char.charCodeAt(0) - base.charCodeAt(0);
  const keyByte = key[position % key.length] ?? 0;
  const encrypted = (offset + keyByte) % range;
  return String.fromCharCode(base.charCodeAt(0) + encrypted);
}

function decryptChar(
  char: string,
  key: Buffer,
  position: number,
  base: string,
  range: number
): string {
  const offset = char.charCodeAt(0) - base.charCodeAt(0);
  const keyByte = key[position % key.length] ?? 0;
  // JS `%` keeps the sign of the dividend, so for key bytes larger than
  // `offset + range` a plain modulo would go negative and fall outside the
  // alphabet. Normalise to a non-negative residue so decrypt inverts encrypt.
  const decrypted = (((offset - keyByte) % range) + range) % range;
  return String.fromCharCode(base.charCodeAt(0) + decrypted);
}
