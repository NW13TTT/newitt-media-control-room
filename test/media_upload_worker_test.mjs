import assert from "node:assert/strict";
import test from "node:test";
import { uploadWebsitePhoto, websitePhoto } from "../media-upload-worker.mjs";

const id = "651ef99c-2169-48d4-8c54-cf9223d856f0";
const tenant = "46257e26-0079-4241-8100-5feb8a51b053";

test("validates tenant and photo before writing, and cleans up rejected metadata", async () => {
  let mode = "foreign";
  const writes = [];
  const deletes = [];
  const oldFetch = globalThis.fetch;
  globalThis.fetch = async (url, options) => {
    switch (url.pathname) {
      case "/auth/v1/user": return Response.json({ id });
      case "/rest/v1/rpc/current_tenant_id":
        assert.equal(options.method, "POST");
        assert.deepEqual(JSON.parse(options.body), {});
        return Response.json(tenant);
      case "/rest/v1/websites": return Response.json([{ id, tenant_id: mode === "foreign" ? id : tenant }]);
      case "/rest/v1/media":
        assert.equal(JSON.parse(options.body).title, "Moira Furnace.jpg");
        return new Response(null, { status: mode === "denied" ? 403 : 201 });
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
  const upload = (bytes, includeLength = true) => uploadWebsitePhoto(new Request("https://worker.example/api/media/photos", {
    method: "POST", headers: { Authorization: "Bearer test", "X-Website-Id": id, "X-Photo-Name": "Moira%20Furnace.jpg", ...(includeLength ? { "Content-Length": bytes.length } : {}) },
    body: new Uint8Array(bytes),
  }), env);
  try {
    assert.equal((await upload([255, 216, 255])).status, 403);
    mode = "allowed";
    assert.equal((await upload([1, 2, 3])).status, 415);
    assert.equal(writes.length, 0);
    assert.equal((await upload([255, 216, 255])).status, 201);
    assert.ok(writes[0].startsWith(tenant + "/" + id + "/"));
    const heif = brand => Buffer.from("\0\0\0\x18ftyp" + brand + "\0\0\0\0" + brand);
    for (const photo of [
      [137, 80, 78, 71, 13, 10, 26, 10], heif("heic"), heif("mif1"),
    ]) {
      assert.equal((await upload(photo, false)).status, 201);
    }
    mode = "denied";
    assert.equal((await upload([255, 216, 255])).status, 403);
    assert.deepEqual(deletes, [writes.at(-1)]);
  } finally {
    globalThis.fetch = oldFetch;
  }
});

test("previews private photos, serves only published photos and scopes deletion", async () => {
  const path = tenant + "/" + id + "/" + id + ".webp";
  const row = {
    storage_path: path, tenant_id: tenant, website_id: id,
    metadata: { storage_provider: "r2" },
  };
  const oldFetch = globalThis.fetch;
  const events = [];
  globalThis.fetch = async (url, options) => {
    const token = options.headers.Authorization;
    if (url.pathname.endsWith("/get_published_r2_photo")) {
      const query = JSON.parse(options.body);
      return Response.json(query.requested_domain === "essexparanormal.com" ? row : null);
    }
    if (url.pathname.endsWith("/current_tenant_id")) {
      return Response.json(token === "Bearer support" ? id : tenant);
    }
    assert.equal(url.pathname, "/rest/v1/media");
    if (options.method === "DELETE") {
      assert.equal(url.searchParams.get("storage_path"), "eq." + path);
      events.push("delete row");
      return Response.json([{ id }]);
    }
    return Response.json(token === "Bearer foreign" ? [] : [row]);
  };
  const env = {
    SUPABASE_URL: "https://database.example",
    SUPABASE_PUBLISHABLE_KEY: "test-key",
    WEBSITE_MEDIA: {
      get: async key => {
        assert.equal(key, path);
        return { body: "webp" };
      },
      delete: async key => {
        assert.equal(key, path);
        events.push("delete object");
      },
    },
  };
  const call = (method, token, domain) => websitePhoto(new Request(
    "https://worker.example/api/media/photos/" + id + (domain ? "?domain=" + domain : ""),
    { method, headers: token ? { Authorization: "Bearer " + token } : {} },
  ), env, id);
  try {
    assert.equal((await call("GET")).status, 401);
    assert.equal((await call("GET", "foreign")).status, 404);
    assert.equal(await (await call("GET", "customer")).text(), "webp");
    assert.equal((await call("GET", null, "newittmedia.co.uk")).status, 404);
    assert.equal((await call("GET", null, "essexparanormal.com")).status, 200);
    assert.equal((await call("DELETE", null, "essexparanormal.com")).status, 405);
    assert.equal((await call("DELETE", "support")).status, 404);
    assert.deepEqual(events, []);
    assert.equal((await call("DELETE", "customer")).status, 204);
    assert.deepEqual(events, ["delete object", "delete row"]);
  } finally {
    globalThis.fetch = oldFetch;
  }
});
