#!/usr/bin/env node

import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { BlockList, isIP } from 'node:net';
import { extname, join, normalize, resolve, sep } from 'node:path';

const root = resolve('build/web');
const host = process.env.MIRIAGO_PREVIEW_HOST ?? '127.0.0.1';
const port = Number.parseInt(process.env.MIRIAGO_PREVIEW_PORT ?? '8791', 10);
const anitabiFilePattern = /^g(?:\d+)?\.json$/;

const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.webp': 'image/webp',
};

function text(response, statusCode, body) {
  response.writeHead(statusCode, {
    'content-type': 'text/plain; charset=utf-8',
    'cache-control': 'no-store',
  });
  response.end(body);
}

function safeStaticPath(pathname) {
  const decoded = decodeURIComponent(pathname);
  const candidate = normalize(join(root, decoded === '/' ? 'index.html' : decoded));
  if (candidate !== root && !candidate.startsWith(`${root}${sep}`)) {
    return null;
  }
  return candidate;
}

async function serveStatic(request, response) {
  const url = new URL(request.url ?? '/', `http://${host}:${port}`);
  let filePath = safeStaticPath(url.pathname);
  if (filePath == null) {
    text(response, 403, 'Forbidden');
    return;
  }

  let fileStat;
  try {
    fileStat = await stat(filePath);
    if (fileStat.isDirectory()) {
      filePath = join(filePath, 'index.html');
      fileStat = await stat(filePath);
    }
  } catch (_) {
    filePath = join(root, 'index.html');
    try {
      fileStat = await stat(filePath);
    } catch (_) {
      text(response, 404, 'Missing build/web. Run flutter build web first.');
      return;
    }
  }

  response.writeHead(200, {
    'content-type': contentTypes[extname(filePath)] ?? 'application/octet-stream',
    'content-length': fileStat.size,
    'cache-control': 'no-store',
  });
  createReadStream(filePath).pipe(response);
}

function safeAnitabiVersion(version) {
  if (!version) {
    return '';
  }
  return /^[A-Za-z0-9_-]+$/.test(version) ? version : '';
}

const reservedAddresses = new BlockList();
for (const [address, prefix] of [
  ['0.0.0.0', 8], ['10.0.0.0', 8], ['100.64.0.0', 10], ['127.0.0.0', 8],
  ['169.254.0.0', 16], ['172.16.0.0', 12], ['192.0.0.0', 24],
  ['192.168.0.0', 16], ['198.18.0.0', 15], ['224.0.0.0', 4],
  ['240.0.0.0', 4],
]) {
  reservedAddresses.addSubnet(address, prefix, 'ipv4');
}
for (const [address, prefix] of [
  // ::/96 covers :: and ::1; IPv4-mapped and NAT64 forms are refused
  // outright rather than unpacked.
  ['::', 96], ['::ffff:0:0', 96], ['64:ff9b::', 96], ['64:ff9b:1::', 48],
  ['fc00::', 7],
  ['fe80::', 10], ['fec0::', 10], ['ff00::', 8],
]) {
  reservedAddresses.addSubnet(address, prefix, 'ipv6');
}

// WHATWG URL already turns numeric IPv4 spellings (2130706433, 0x7f.1)
// into dotted decimal and brackets IPv6 hosts. Names are not resolved.
function isLocalOrPrivateHost(hostname) {
  const host = hostname.toLowerCase().replace(/^\[|\]$/g, '').replace(/\.+$/, '');
  if (host === '' || host === 'localhost' ||
      ['.localhost', '.local', '.home.arpa', '.internal', '.lan']
        .some((suffix) => host.endsWith(suffix))) {
    return true;
  }
  const family = isIP(host);
  if (family === 4) {
    return reservedAddresses.check(host, 'ipv4');
  }
  if (family === 6) {
    return reservedAddresses.check(host, 'ipv6');
  }
  return false;
}

function safePublicHttpsBaseUrl(value) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.username || url.password ||
        url.search || url.hash || isLocalOrPrivateHost(url.hostname)) {
      return null;
    }
    return value.replace(/\/+$/, '');
  } catch (_) {
    return null;
  }
}

const maxAnitabiStaticBytes = 16 * 1024 * 1024;

async function fetchAnitabiStatic(fileName, version, upstreamValue) {
  const query = version ? `?v=${encodeURIComponent(version)}` : '';
  const baseUrl = safePublicHttpsBaseUrl(upstreamValue);
  if (baseUrl == null) {
    return null;
  }
  const response = await fetch(`${baseUrl}/${fileName}${query}`, {
    headers: {'user-agent': 'MiriaGo local web preview'},
    // A redirect could lead into the local network; Anitabi does not use
    // them for static files.
    redirect: 'error',
    signal: AbortSignal.timeout(120_000),
  });
  if (!response.ok) {
    return null;
  }
  const declared = Number(response.headers.get('content-length') ?? 0);
  if (declared > maxAnitabiStaticBytes || response.body == null) {
    return null;
  }
  // Count while reading: a chunked response has no declared length.
  const chunks = [];
  let received = 0;
  for await (const chunk of response.body) {
    received += chunk.length;
    if (received > maxAnitabiStaticBytes) {
      await response.body.cancel().catch(() => {});
      return null;
    }
    chunks.push(chunk);
  }
  const body = Buffer.concat(chunks);
  const start = body.subarray(0, 64).toString('utf8').trimStart();
  // Only JSON is passed on: an upstream error or landing page must never be
  // served from the preview's own origin.
  if (body.length > maxAnitabiStaticBytes ||
      !(start.startsWith('[') || start.startsWith('{'))) {
    return null;
  }
  return body;
}

async function serveAnitabiStatic(url, response) {
  const fileName = decodeURIComponent(url.pathname.split('/').pop() ?? '');
  const version = safeAnitabiVersion(url.searchParams.get('v') ?? '');
  const upstream = url.searchParams.get('upstream') ?? 'https://www.anitabi.cn/d';
  if (!anitabiFilePattern.test(fileName)) {
    text(response, 400, 'Invalid Anitabi static file name.');
    return;
  }

  try {
    const body = await fetchAnitabiStatic(fileName, version, upstream);
    if (body == null) {
      text(response, 502, `Unable to fetch Anitabi static file: ${fileName}`);
      return;
    }

    response.writeHead(200, {
      'content-type': 'application/json; charset=utf-8',
      'x-content-type-options': 'nosniff',
      'cache-control': 'no-store',
      'access-control-allow-origin': '*',
    });
    response.end(body);
  } catch (error) {
    text(response, 502, `Anitabi proxy error: ${error}`);
  }
}

const server = createServer((request, response) => {
  const url = new URL(request.url ?? '/', `http://${host}:${port}`);
  if (url.pathname.startsWith('/__anitabi_static__/')) {
    void serveAnitabiStatic(url, response);
    return;
  }
  void serveStatic(request, response);
});

server.listen(port, host, () => {
  console.log(`MiriaGo preview: http://${host}:${port}/`);
  console.log(`Anitabi proxy: http://${host}:${port}/__anitabi_static__/g.json`);
});
