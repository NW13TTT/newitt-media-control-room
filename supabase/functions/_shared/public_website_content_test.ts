import { assertEquals } from "jsr:@std/assert@1";

import { isWebsiteMediaPath, parsePublicWebsiteContentRequest, publicWebsiteContentResponse } from "./public_website_content.ts";

Deno.test("public content allows only configured tenant domains", () => {
  assertEquals(
    parsePublicWebsiteContentRequest({ domain: "newittmedia.co.uk" }),
    "newittmedia.co.uk",
  );
  assertEquals(
    parsePublicWebsiteContentRequest({ domain: "essexparanormal.com" }),
    "essexparanormal.com",
  );
  assertEquals(
    parsePublicWebsiteContentRequest({ domain: "unknown.example" }),
    null,
  );
});

Deno.test("public content response preserves the requested website identity", () => {
  const response = publicWebsiteContentResponse({
    website: {
      name: "Essex Paranormal",
      domain: "essexparanormal.com",
      website_settings: {},
    },
    content: [],
    pages: [],
    socialLinks: [],
  });

  assertEquals(response.website, {
    name: "Essex Paranormal",
    domain: "essexparanormal.com",
    settings: {},
  });
});

Deno.test("published media signing stays inside the media row's website and tenant", () => {
  const tenant = "essex-tenant";
  const website = "essex-website";
  assertEquals(isWebsiteMediaPath("essex-tenant/essex-website/guildhall.mp4", tenant, website), true);
  for (const path of [
    "other-tenant/essex-website/private.mp4",
    "essex-tenant/other-website/private.mp4",
    "essex-tenant/essex-website/../other-website/private.mp4",
    "essex-tenant/essex-website/%2e%2e/private.mp4",
    "essex-tenant/essex-website/",
  ]) {
    assertEquals(isWebsiteMediaPath(path, tenant, website), false);
  }
});
