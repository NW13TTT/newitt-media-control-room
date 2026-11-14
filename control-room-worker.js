import { uploadWebsitePhoto, websitePhoto } from "./media-upload-worker.mjs";

export default {
  async fetch(request, env) {
    const path = new URL(request.url).pathname;
    const photo = /^\/api\/media\/photos\/([^/]+)$/.exec(path);
    if (path === "/api/media/photos" || photo) {
      try {
        return photo ? await websitePhoto(request, env, photo[1])
          : await uploadWebsitePhoto(request, env);
      } catch {
        return Response.json({ error: "Photo request failed. Please retry." }, {
          status: 503,
          headers: { "Cache-Control": "no-store" },
        });
      }
    }
    const response = await env.ASSETS.fetch(request);
    if (response.status !== 404 || request.method !== "GET") return response;

    const acceptsHtml = request.headers.get("accept")?.includes("text/html");
    return acceptsHtml
      ? env.ASSETS.fetch(new Request(new URL("/index.html", request.url), request))
      : response;
  },
};
