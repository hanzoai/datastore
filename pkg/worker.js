/**
 * pkg.hanzo.ai — Cloudflare Worker
 *
 * Proxies and rebrands upstream datastore packages.
 * Routes:
 *   /datastore/tgz/{channel}/{package}-{version}-{arch}.tgz
 *     → packages.datastore.com/tgz/{channel}/datastore-{component}-{version}-{arch}.tgz
 *
 *   /datastore/deb/pool/main/{package}-{version}_{arch}.deb
 *     → packages.datastore.com/deb/pool/main/c/datastore/datastore-{component}-{version}_{arch}.deb
 */

const UPSTREAM_BASE = 'https://packages.datastore.com';

// Map our package names to upstream
const PACKAGE_MAP = {
  'datastore-client': 'datastore-client',
  'datastore-server': 'datastore-server',
  'datastore-common-static': 'datastore-common-static',
  'datastore-keeper': 'datastore-keeper',
};

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Health check
    if (path === '/ping' || path === '/') {
      return new Response('pkg.hanzo.ai\n', {
        headers: { 'content-type': 'text/plain' },
      });
    }

    // TGZ packages: /datastore/tgz/{channel}/{package}-{version}-{arch}.tgz
    const tgzMatch = path.match(/^\/datastore\/tgz\/(.+)$/);
    if (tgzMatch) {
      let subpath = tgzMatch[1];
      // Replace our package names with upstream
      for (const [ours, upstream] of Object.entries(PACKAGE_MAP)) {
        subpath = subpath.replace(ours, upstream);
      }
      const upstreamUrl = `${UPSTREAM_BASE}/tgz/${subpath}`;
      return proxyUpstream(upstreamUrl, request);
    }

    // DEB packages: /datastore/deb/pool/main/{package}...
    const debMatch = path.match(/^\/datastore\/deb\/(.+)$/);
    if (debMatch) {
      let subpath = debMatch[1];
      // Replace our package names with upstream
      for (const [ours, upstream] of Object.entries(PACKAGE_MAP)) {
        subpath = subpath.replace(ours, upstream);
      }
      // Fix the path structure for deb (upstream uses /c/datastore/ prefix)
      if (!subpath.includes('/c/datastore/')) {
        subpath = subpath.replace('pool/main/', 'pool/main/c/datastore/');
      }
      const upstreamUrl = `${UPSTREAM_BASE}/deb/${subpath}`;
      return proxyUpstream(upstreamUrl, request);
    }

    return new Response('Not Found\n', { status: 404 });
  },
};

async function proxyUpstream(upstreamUrl, request) {
  const resp = await fetch(upstreamUrl, {
    method: request.method,
    headers: {
      'User-Agent': 'pkg.hanzo.ai/1.0',
    },
  });

  // Clone response with our headers
  const headers = new Headers(resp.headers);
  headers.set('x-served-by', 'pkg.hanzo.ai');
  headers.delete('server');

  return new Response(resp.body, {
    status: resp.status,
    statusText: resp.statusText,
    headers,
  });
}
