/**
 * pkg.hanzo.ai — Cloudflare Worker
 *
 * Serves Hanzo Datastore packages from our own artifact store.
 *
 *   /datastore/tgz/{channel}/{package}-{version}-{arch}.tgz
 *   /datastore/deb/pool/main/{package}-{version}_{arch}.deb
 *
 * It used to fetch these from upstream's package host and rename the file on the
 * way through, so `datastore-server` resolved to an upstream binary served under
 * our host with our `x-served-by`. That is worse than serving nothing: it hands
 * someone another project's build believing it is ours, and it makes our package
 * channel a live dependency on a third party's release schedule and uptime.
 *
 * So the upstream base and the name map are gone. This serves what WE build, and
 * says so plainly when we have not built it yet — a 503 naming the artifact that
 * does exist beats a 200 carrying the wrong bytes.
 *
 * WHAT WE PUBLISH TODAY: the container image, `ghcr.io/hanzoai/datastore` (see
 * hanzo.yml). There is no apt/tgz lane yet — hanzo.yml says so where it explains
 * why the image builds from source rather than from the .deb path. When that lane
 * lands, point PKG_BASE at it and these routes start answering.
 */

/// Where our own built packages live, once a lane publishes them. Set as a
/// Worker environment variable rather than baked in, so standing one up does not
/// need a code change. Empty means "we do not publish these yet", which is the
/// honest state today.
const PKG_BASE_VAR = 'PKG_BASE';

/// What we DO publish, named in the 503 so the reader has somewhere to go.
const IMAGE = 'ghcr.io/hanzoai/datastore';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    if (path === '/ping' || path === '/') {
      return new Response('pkg.hanzo.ai\n', {
        headers: { 'content-type': 'text/plain' },
      });
    }

    const match = path.match(/^\/datastore\/(tgz|deb)\/(.+)$/);
    if (!match) {
      return new Response('Not Found\n', { status: 404 });
    }

    const base = (env && env[PKG_BASE_VAR]) || '';
    if (!base) {
      return new Response(
        `No package lane yet.\n\n` +
          `Hanzo Datastore publishes a container image and not (yet) apt or tgz\n` +
          `packages, so there is nothing correct to serve here:\n\n` +
          `    docker pull ${IMAGE}\n\n` +
          `This endpoint used to proxy another project's packages under our name.\n` +
          `It does not any more.\n`,
        { status: 503, headers: { 'content-type': 'text/plain' } },
      );
    }

    const [, kind, subpath] = match;
    return serve(`${base.replace(/\/+$/, '')}/${kind}/${subpath}`, request);
  },
};

async function serve(target, request) {
  const resp = await fetch(target, {
    method: request.method,
    headers: { 'User-Agent': 'pkg.hanzo.ai/1.0' },
  });

  const headers = new Headers(resp.headers);
  headers.set('x-served-by', 'pkg.hanzo.ai');
  headers.delete('server');

  return new Response(resp.body, {
    status: resp.status,
    statusText: resp.statusText,
    headers,
  });
}
