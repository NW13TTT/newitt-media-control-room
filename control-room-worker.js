import { uploadWebsitePhoto } from "./media-upload-worker.mjs";

export default {
  async fetch(request, env) {
    if (new URL(request.url).pathname === "/api/media/photos") {
      try {
        return await uploadWebsitePhoto(request, env);
      } catch {
        return Response.json({ error: "Photo upload failed. Please retry." }, {
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