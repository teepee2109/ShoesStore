import { createHmac, timingSafeEqual } from 'node:crypto';

const excludedSignatureFields = new Set(['vnp_SecureHash', 'vnp_SecureHashType']);

function normalizeParams(params) {
  const normalized = {};
  for (const [key, value] of Object.entries(params)) {
    if (excludedSignatureFields.has(key) || value === undefined || value === null) continue;
    if (Array.isArray(value) || typeof value === 'object') {
      throw new Error(`Invalid VNPAY parameter: ${key}`);
    }
    normalized[key] = String(value);
  }
  return normalized;
}

export function vnpaySignData(params) {
  const normalized = normalizeParams(params);
  return Object.keys(normalized)
    .sort()
    .map((key) => `${key}=${normalized[key]}`)
    .join('&');
}

export function createVnpaySignature(params, secret) {
  return createHmac('sha512', secret)
    .update(vnpaySignData(params), 'utf8')
    .digest('hex');
}

export function verifyVnpaySignature(params, secret) {
  const provided = String(params.vnp_SecureHash ?? '');
  if (!/^[a-f\d]{128}$/i.test(provided)) return false;
  const expected = Buffer.from(createVnpaySignature(params, secret), 'hex');
  const actual = Buffer.from(provided, 'hex');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

export function buildVnpayUrl(baseUrl, params, secret) {
  const normalized = normalizeParams(params);
  const signature = createVnpaySignature(normalized, secret);
  const url = new URL(baseUrl);
  for (const key of Object.keys(normalized).sort()) {
    url.searchParams.set(key, normalized[key]);
  }
  url.searchParams.set('vnp_SecureHash', signature);
  return url.toString();
}

export function formatVnpayDate(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  return `${values.year}${values.month}${values.day}${values.hour}${values.minute}${values.second}`;
}
