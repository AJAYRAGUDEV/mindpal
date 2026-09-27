import {
  randomBytes,
  scryptSync,
  timingSafeEqual,
  createHash,
} from 'node:crypto';

/**
 * Passwords and sessions, using only node:crypto.
 *
 * scrypt rather than bcrypt because it is in the standard library and needs
 * no native module. It is a memory-hard KDF, which is the property that
 * matters: it makes a stolen table expensive to attack in bulk.
 *
 * Three rules this file exists to keep:
 *   1. The password is never stored, logged, or returned. Only the hash.
 *   2. Comparison is timing-safe. A plain === on a hash leaks, one byte at a
 *      time, how much of a guess was right.
 *   3. The session token is never stored either — only its SHA-256. A stolen
 *      database therefore yields no usable sessions.
 */

const KEY_LENGTH = 64;
const SESSION_DAYS = 14;

/** Returns { hash, salt }, both hex. */
export function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  const hash = scryptSync(password, salt, KEY_LENGTH).toString('hex');
  return { hash, salt };
}

/** Timing-safe check of a candidate password against a stored hash. */
export function verifyPassword(password, hash, salt) {
  if (typeof password !== 'string' || typeof hash !== 'string') return false;

  let candidate;
  try {
    candidate = scryptSync(password, salt, KEY_LENGTH);
  } catch {
    return false;
  }

  const stored = Buffer.from(hash, 'hex');
  // timingSafeEqual throws on a length mismatch, which would itself be a
  // signal; check the length first and treat a mismatch as a plain failure.
  if (stored.length !== candidate.length) return false;
  return timingSafeEqual(stored, candidate);
}

/**
 * A new session token.
 *
 * Returns the raw token, which is handed to the browser exactly once and
 * never written down here, plus the hash, which is what the database keeps.
 */
export function createSessionToken() {
  const token = randomBytes(32).toString('base64url');
  return { token, tokenHash: hashToken(token) };
}

export const hashToken = (token) =>
  createHash('sha256').update(token).digest('hex');

export function sessionExpiry(from = new Date()) {
  const expiry = new Date(from);
  expiry.setDate(expiry.getDate() + SESSION_DAYS);
  return expiry.toISOString();
}

/**
 * A short code a patient reads aloud to a caregiver.
 *
 * Six characters from an alphabet with no 0/O, 1/I/L, 5/S or 8/B, because
 * this is going to be read off a phone screen by someone with poor eyesight
 * and typed by someone in a hurry. 27^6 is about 387 million, and the code
 * expires in minutes and dies on first use, so guessing is not the risk
 * mistyping is.
 */
const CODE_ALPHABET = 'ACDEFGHJKMNPQRTUVWXYZ234679';

export function createLinkCode() {
  const bytes = randomBytes(6);
  let code = '';
  for (const byte of bytes) code += CODE_ALPHABET[byte % CODE_ALPHABET.length];
  return code;
}

export function codeExpiry(minutes = 15, from = new Date()) {
  return new Date(from.getTime() + minutes * 60_000).toISOString();
}

/** A device's own identifier, generated once by the patient's app. */
export const createDeviceKey = () => randomBytes(24).toString('base64url');

/**
 * Minimum password rules. Deliberately modest: length is what matters, and a
 * rule nobody can satisfy just produces "Password1!" on a sticky note.
 */
export function passwordProblem(password) {
  if (typeof password !== 'string' || password.length < 10) {
    return 'Please use a password of at least 10 characters.';
  }
  if (password.length > 200) return 'That password is too long.';
  return null;
}

export function emailProblem(email) {
  if (typeof email !== 'string' || email.trim().length === 0) {
    return 'Please enter an email address.';
  }
  const trimmed = email.trim();
  if (trimmed.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed)) {
    return 'Please enter a valid email address.';
  }
  return null;
}
