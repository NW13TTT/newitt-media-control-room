import { assertEquals } from "jsr:@std/assert@1";

import { parsePublicWebsiteContentRequest, publicWebsiteContentResponse } from "./public_website_content.ts";

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