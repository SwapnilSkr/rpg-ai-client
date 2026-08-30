#!/usr/bin/env bun
/**
 * Upload a signed .aab to a Google Play track and roll it out.
 *
 * Play's web uploader is the only route the browser can drive, and it needs a
 * human at a file picker. This is the same operation over the Play Developer
 * API, so CI (or an agent) can ship a build unattended.
 *
 *   bun run scripts/play-upload.ts --track alpha --aab build/app/outputs/bundle/release/app-release.aab
 *
 * Credentials come from a service-account JSON key, never from a flag:
 *   PLAY_SERVICE_ACCOUNT_JSON=~/.everlore-play-publisher.json
 *
 * The service account needs "Release apps to testing tracks" on the app. It
 * deliberately does NOT have production release rights — pointing --track at
 * production will fail with 403 rather than publish to everyone by accident.
 */

const PKG = process.env.PLAY_PACKAGE_NAME || 'com.everloreapp'
const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3'
const UPLOAD = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3'

function arg(name: string, fallback?: string): string {
  const i = process.argv.indexOf(`--${name}`)
  const v = i >= 0 ? process.argv[i + 1] : undefined
  if (v === undefined && fallback === undefined) {
    throw new Error(`missing required --${name}`)
  }
  return v ?? fallback!
}

function expandHome(p: string): string {
  return p.startsWith('~') ? p.replace('~', process.env.HOME || '') : p
}

/** Mint an access token from the service-account key (RS256 JWT bearer flow). */
async function accessToken(keyPath: string): Promise<string> {
  const key = JSON.parse(await Bun.file(keyPath).text())
  const now = Math.floor(Date.now() / 1000)
  const claims = {
    iss: key.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }
  const b64 = (o: unknown) =>
    Buffer.from(JSON.stringify(o)).toString('base64url')
  const signingInput = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64(claims)}`

  // The key arrives as a PKCS#8 PEM; strip the armour before importing.
  const pem = key.private_key
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '')
  const der = Uint8Array.from(Buffer.from(pem, 'base64'))
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signingInput),
  )
  const jwt = `${signingInput}.${Buffer.from(sig).toString('base64url')}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const body = await res.json()
  if (!res.ok) throw new Error(`token exchange failed: ${JSON.stringify(body)}`)
  return body.access_token
}

async function call(
  token: string,
  url: string,
  init: RequestInit = {},
): Promise<any> {
  const res = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(init.body instanceof Uint8Array
        ? { 'Content-Type': 'application/octet-stream' }
        : init.body
          ? { 'Content-Type': 'application/json' }
          : {}),
      ...(init.headers || {}),
    },
  })
  const text = await res.text()
  const body = text ? JSON.parse(text) : {}
  if (!res.ok) {
    throw new Error(`${init.method || 'GET'} ${url} -> ${res.status}\n${text}`)
  }
  return body
}

const main = async () => {
  const keyPath = expandHome(
    process.env.PLAY_SERVICE_ACCOUNT_JSON || '~/.everlore-play-publisher.json',
  )
  const aabPath = arg('aab', 'build/app/outputs/bundle/release/app-release.aab')
  const track = arg('track', 'alpha')
  const notes = arg('notes', '')
  const status = arg('status', 'completed')

  const aab = await Bun.file(aabPath).arrayBuffer()
  console.log(`bundle  ${aabPath} (${(aab.byteLength / 1e6).toFixed(1)} MB)`)

  const token = await accessToken(keyPath)
  console.log('auth    ok')

  const edit = await call(token, `${API}/applications/${PKG}/edits`, {
    method: 'POST',
  })
  console.log(`edit    ${edit.id}`)

  const tracks = await call(
    token,
    `${API}/applications/${PKG}/edits/${edit.id}/tracks`,
  )
  const names = (tracks.tracks || []).map((t: any) => t.track)
  console.log(`tracks  ${names.join(', ') || '(none)'}`)
  if (names.length && !names.includes(track)) {
    throw new Error(`track "${track}" not found; available: ${names.join(', ')}`)
  }

  const bundle = await call(
    token,
    `${UPLOAD}/applications/${PKG}/edits/${edit.id}/bundles?uploadType=media`,
    { method: 'POST', body: new Uint8Array(aab) },
  )
  console.log(`upload  versionCode ${bundle.versionCode}`)

  const release: Record<string, unknown> = {
    versionCodes: [String(bundle.versionCode)],
    status,
  }
  if (notes) release.releaseNotes = [{ language: 'en-US', text: notes }]

  await call(
    token,
    `${API}/applications/${PKG}/edits/${edit.id}/tracks/${track}`,
    { method: 'PUT', body: JSON.stringify({ track, releases: [release] }) },
  )
  console.log(`track   ${track} <- ${bundle.versionCode} (${status})`)

  const done = await call(
    token,
    `${API}/applications/${PKG}/edits/${edit.id}:commit`,
    { method: 'POST' },
  )
  console.log(`commit  ${done.id} committed`)
}

main().catch((e) => {
  console.error(`\nFAILED: ${e.message}`)
  process.exit(1)
})
