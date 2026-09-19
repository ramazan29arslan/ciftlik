#!/usr/bin/env node
// Yama notlarini Firestore'daki appUpdates/{platform} belgesine yazar.
//
// Kullanim:  node scripts/update-notes.mjs <patchNumber> [platform] [baslik]
// Notlar stdin'den satir satir okunur.
//
// Kimlik dogrulama: serviceAccount.json (gitignore'da). Harici paket yok —
// JWT, Node'un kendi crypto modulu ile imzalanir.

import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';

const KEY_PATH = new URL('../serviceAccount.json', import.meta.url);
const SCOPE = 'https://www.googleapis.com/auth/datastore';

const [, , patchArg, platformArg = 'ios', ...titleParts] = process.argv;

const patchNumber = Number.parseInt(patchArg ?? '', 10);
if (!Number.isInteger(patchNumber)) {
  console.error('Gecerli bir yama numarasi verin. Ornek: node scripts/update-notes.mjs 2 ios');
  process.exit(1);
}

let key;
try {
  key = JSON.parse(readFileSync(KEY_PATH, 'utf8'));
} catch {
  console.error(
    'serviceAccount.json bulunamadi.\n' +
      'Firebase Console -> Project Settings -> Service Accounts -> Generate new private key\n' +
      'Inen dosyayi proje kokune serviceAccount.json adiyla kaydedin.',
  );
  process.exit(1);
}

const notes = readFileSync(0, 'utf8')
  .split('\n')
  .map((l) => l.trim())
  .filter(Boolean);

if (notes.length === 0) {
  console.error('Not bulunamadi (stdin bos). Son yamadan bu yana commit yok mu?');
  process.exit(1);
}

const title = titleParts.join(' ').trim() || `Guncelleme #${patchNumber}`;

const b64url = (buf) =>
  Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

async function accessToken() {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = b64url(
    JSON.stringify({
      iss: key.client_email,
      scope: SCOPE,
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );
  const signer = createSign('RSA-SHA256');
  signer.update(`${header}.${claim}`);
  const assertion = `${header}.${claim}.${b64url(signer.sign(key.private_key))}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) throw new Error(`Token alinamadi (${res.status}): ${await res.text()}`);
  return (await res.json()).access_token;
}

const token = await accessToken();

const url =
  `https://firestore.googleapis.com/v1/projects/${key.project_id}` +
  `/databases/(default)/documents/appUpdates/${platformArg}` +
  '?updateMask.fieldPaths=patchNumber' +
  '&updateMask.fieldPaths=title' +
  '&updateMask.fieldPaths=notes' +
  '&updateMask.fieldPaths=publishedAt';

const res = await fetch(url, {
  method: 'PATCH',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    fields: {
      patchNumber: { integerValue: String(patchNumber) },
      title: { stringValue: title },
      notes: { arrayValue: { values: notes.map((n) => ({ stringValue: n })) } },
      publishedAt: { timestampValue: new Date().toISOString() },
    },
  }),
});

if (!res.ok) {
  console.error(`Firestore yazilamadi (${res.status}): ${await res.text()}`);
  process.exit(1);
}

console.log(`Notlar yazildi -> appUpdates/${platformArg}  (yama #${patchNumber})`);
for (const n of notes) console.log(`  - ${n}`);
