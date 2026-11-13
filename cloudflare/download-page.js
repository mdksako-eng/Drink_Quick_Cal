// The one piece of code this Worker runs: serving the installation file from ITS OWN address.
//
// Why it exists: the APK is 82 MB and Cloudflare's per-file limit for static assets is 25 MiB, so
// it cannot simply sit in `download-page/`. It is published elsewhere, and without this route a
// shop tapping Download would see that other address — its owner's account name, and a repository
// anyone could browse — in the phone's URL bar and download list.
//
// With this route the shop downloads from this domain and nothing else is visible.
//
// It costs nothing to run: Cloudflare serves a static asset whenever one matches, so this script
// is reached only for paths no asset matched — i.e. only for the single path below. The page
// itself stays as cheap and fast as an assets-only Worker.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === '/app-release.apk') {
      const upstream = await fetch(env.APK_UPSTREAM, { method: request.method });

      if (!upstream.ok) {
        // The file lives elsewhere, so it can be unreachable on its own. Say so plainly rather
        // than handing the shop a broken download — the page's own version check is unaffected.
        return new Response(
          'The installation file is temporarily unavailable. Please try again in a few minutes.',
          { status: 503, headers: { 'content-type': 'text/plain; charset=utf-8' } },
        );
      }

      // Streamed, not buffered: the body is piped straight through, so 82 MB never sits in the
      // Worker's memory and its CPU time stays at zero. A Worker that is still streaming a
      // response body stays alive, which is why a large file is fine here.
      const headers = new Headers({
        'content-type': 'application/vnd.android.package-archive',
        'content-disposition': 'attachment; filename="app-release.apk"',
      });
      const length = upstream.headers.get('content-length');
      if (length) headers.set('content-length', length);

      return new Response(request.method === 'HEAD' ? null : upstream.body, {
        status: 200,
        headers,
      });
    }

    // Everything else: the static assets, exactly as before.
    return env.ASSETS.fetch(request);
  },
};
