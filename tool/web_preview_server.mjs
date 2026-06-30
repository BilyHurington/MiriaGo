#!/usr/bin/env node

import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { createServer } from 'node:http';
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

async function fetchAnitabiStatic(fileName, version) {
  const query = version ? `?v=${encodeURIComponent(version)}` : '';
  for (const baseUrl of ['https://www.anitabi.cn/d', 'https://anitabi.cn/d']) {
    const response = await fetch(`${baseUrl}/${fileName}${query}`, {
      headers: {'user-agent': 'MiriaGo local web preview'},
    });
    if (response.ok) {
      return response;
    }
  }
  return null;
}

async function serveAnitabiStatic(url, response) {
  const fileName = decodeURIComponent(url.pathname.split('/').pop() ?? '');
  const version = safeAnitabiVersion(url.searchParams.get('v') ?? '');
  if (!anitabiFilePattern.test(fileName)) {
    text(response, 400, 'Invalid Anitabi static file name.');
    return;
  }

  try {
    const upstream = await fetchAnitabiStatic(fileName, version);
    if (upstream == null) {
      text(response, 502, `Unable to fetch Anitabi static file: ${fileName}`);
      return;
    }

    response.writeHead(200, {
      'content-type': upstream.headers.get('content-type') ?? 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'access-control-allow-origin': '*',
    });
    response.end(Buffer.from(await upstream.arrayBuffer()));
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
