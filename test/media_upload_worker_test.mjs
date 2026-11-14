import assert from "node:assert/strict";
import test from "node:test";
import { uploadWebsitePhoto } from "../media-upload-worker.mjs";

const id = "651ef99c-2169-48d4-8c54-cf9223d856f0";
const tenant = "46257e26-0079-4241-8100-5feb8a51b053";

test("validates tenant and photo before writing, and cleans up rejected metadata", async () => {
  let mode = "foreign";
  const writes = [];
  const deletes = [];
  const oldFetch = globalThis.fetch;
  globalThis.fetch = async url => {
    switch (url.pathname) {
      case "/auth/v1/user": return Response.json({ id });
      case "/rest/v1/rpc/current_tenant_id": return Response.json(tenant);
      case "/rest/v1/websites": return Response.json([{ id, tenant_id: mode === "foreign" ? id : tenant }]);
      case "/rest/v1/media": return new Response(null, { status: mode === "denied" ? 403 : 201 });
      default: throw new Error(url.pathname);
    }
  };
  const env = {
    SUPABASE_URL: "https://database.example",
    SUPABASE_PUBLISHABLE_KEY: "test-key",
    WEBSITE_MEDIA: {
      put: async path => writes.push(path),
      delete: async path => deletes.push(path),
    },
    IMAGES: { input: () => ({ output: async () => ({ response: () => new Response("webp fixture") }) }) },
  };
  const upload = bytes => uploadWebsitePhoto(new Request("https://worker.example/api/media/photos", {
    method: "POST", headers: { Authorization: "Bearer test", "X-Website-Id": id, "Content-Length": bytes.length },
    body: new Uint8Array(bytes),
  }), env);
  try {
    assert.equal((await upload([255, 216, 255])).status, 403);
    mode = "allowed";
    assert.equal((await upload([1, 2, 3])).status, 415);
    assert.equal(writes.length, 0);
    assert.equal((await upload([255, 216, 255])).status, 201);
    assert.ok(writes[0].startsWith(tenant + "/" + id + "/"));
    mode = "denied";
    assert.equal((await upload([255, 216, 255])).status, 403);
    assert.deepEqual(deletes, [writes[1]]);
  } finally {
    globalThis.fetch = oldFetch;
  }
});
