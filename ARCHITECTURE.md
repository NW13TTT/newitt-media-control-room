# NEWITT Media Control Room Architecture

## Purpose

The Control Room is a Flutter client backed by Supabase. The client presents role-aware workflows for customers and Master Admins. Supabase RLS, database functions, triggers, and Edge Functions remain the authority for tenant isolation and privileged operations.

## Application Layers

```text
lib/
  app/
    app.dart                         MaterialApp shell
    theme/app_theme.dart              central application theme
    routing/
      control_room_navigation.dart    role-aware navigation metadata
      control_room_navigation_view.dart desktop/mobile navigation widgets
      control_room_router.dart         protected screen selection
  auth/                               session, roles, permissions, auth screens
  backend/
    control_room_repository.dart      typed repository contract and records
    website_repository.dart           website repository contract
    supabase/                          Supabase implementations/configuration
  dashboard/                          dashboard presentation and summaries
  control_room/                       website, media, social, support/admin views
  websites/                           website model and development data
  analytics/                          aggregate operational analytics
  security/                           security and audit presentation
  content_safety/                     content safety workflows
  ai_control/                         AI UI and local permission policy
  help/                               static guides and contextual help
```

Feature screens depend on repository interfaces and typed records. Supabase adapters implement those interfaces. UI code does not contain service-role credentials or privileged database operations.

## Startup And Navigation

`main.dart` initializes Supabase configuration, creates the authentication controller, and starts `NewittApp`. `ControlRoomHome` owns only the selected section, website loading, repository factory resolution, and responsive shell composition.

Navigation labels and icons are defined in `ControlRoomNavigation`. `ControlRoomSidebar` and `ControlRoomMobileNavigation` render the same role-aware item list. `ControlRoomRouter` maps selected indices to screens and performs the existing client-side permission guard before rendering administrative views. Backend authorization remains authoritative even when a navigation item is hidden.

## Theme

`AppTheme.dark` centralizes the Material 3 theme, scaffold color, seed color, font, and Material 3 configuration. Feature-specific visual values remain local where they describe a component rather than global application configuration.

## Data And Security Boundaries

- `ControlRoomRepository` is the application-facing contract for typed operational data and commands.
- `SupabaseControlRoomRepository` performs authenticated Supabase queries and writes.
- `WebsiteRepository` isolates website listing from the control-room feature contract.
- `SupabaseAuthenticationService` derives the application session from Supabase Auth and profile/website queries.
- RLS scopes tenant reads and writes in the database; customer website ownership policies are enforced server-side.
- Audit log writes remain append-protected by the database. The Security and Audit Log screens consume only safe, RLS-authorized event fields.
- Content safety, lifecycle, approval, GitHub, and Cloudflare controls remain in their existing database policies, functions, and Edge Functions.
- Privileged credentials and provider tokens remain server-side in Supabase Edge Function configuration.

No Phase 24 database migrations or production data changes were made.

## State And Error Handling

The application uses Flutter widget state and `FutureBuilder` for feature-local asynchronous reads. Existing loading, empty, unavailable, retry, and safe human-readable error states remain in the owning screens. Authentication and Supabase adapters translate provider failures into safe user-facing messages; raw credentials, headers, and database internals are not displayed.

A future feature should keep network access in a repository/service boundary, expose an immutable typed record, and keep presentation states in the screen or a focused feature widget.

## Testing

The current widget suite covers authentication, navigation, support, content safety, commercial agreements, temporary websites, infrastructure views, analytics, AI permissions, and security/audit behavior. Navigation metadata now has focused unit tests for customer and Master Admin visibility.

Run:

```sh
dart format .
flutter analyze
flutter test
```

The test suite uses repository fakes for deterministic UI tests. Real tenant isolation is verified by Supabase policies and catalog checks, not by a Flutter fake.

## Multi-Platform And Responsive Layout

The application remains one Flutter codebase. `ControlRoomBreakpoints` defines the shared window classes: phone below 600 logical pixels, tablet from 600 to 999, and desktop at 1000 or wider. `ResponsiveContent` applies viewport-safe gutters and a 1240 logical-pixel content maximum. Screens use `LayoutBuilder` for local changes such as stacking cards, wrapping filters, and moving action buttons below explanatory text.

The desktop sidebar and mobile `NavigationBar` are two presentations of the same role-filtered navigation metadata. The mobile More sheet is height-bounded and scrollable, so Master Admin entries remain reachable on small phones. Customer navigation never includes GitHub, Cloudflare, Security, Audit Log, or Platform Admin.

The supported code paths retain the existing macOS, iOS, Android, Windows, Linux, and web Flutter project folders. No platform-specific business logic was added. File selection continues through `file_picker`; Supabase and repository code remain platform-neutral.

Representative Dashboard and Websites widget tests run at 360x800, 768x1024, and 1440x900. Recommended validation commands are:

```sh
dart format .
flutter analyze
flutter test
flutter build macos --release
flutter build ios --release
flutter build apk --release
flutter build appbundle --release
flutter build windows --release
flutter build linux --release
flutter build web
```

The local environment currently has macOS and Xcode available. Android SDK is unavailable, and Windows/Linux release builds require their corresponding host operating systems. A macOS release build, an iOS release build with `--no-codesign`, and a web build were verified. A signed iOS deployment was not claimed because signing and distribution configuration were outside this environment. Android builds must be run with an Android SDK; Windows and Linux builds must be run on their supported host platforms. Web compilation passed, although no Chrome runtime device was available for browser interaction testing.

## Phase 26 Testing And Hardening

The automated suite covers authentication preview and sign-out, role-derived navigation, AI permission boundaries, support customer/admin flows, Content Safety, commercial agreements, temporary websites, GitHub and Cloudflare metadata views, aggregate analytics, Security/Audit Log behavior, repository failure states, and responsive Dashboard/Websites layouts. Responsive tests exercise 320x568, 360x800, 768x1024, 1440x900, and 2560x1400 logical-pixel surfaces.

Phase 26 found and fixed two narrow Dashboard overflows: the operational status badge and AI Control heading used horizontal rows that exceeded a 320-pixel viewport. They now wrap safely. Repository failure coverage confirms internal exception text is not rendered to users.

Flutter tests use deterministic repository fakes and do not impersonate two real authenticated tenants. Deployed Supabase verification is performed separately with read-only catalog queries. The current catalog confirms RLS on tenant and infrastructure tables, the Phase 23 media/social/content ownership expressions, SELECT-only audit access, and lifecycle plus Content Safety publication gates. No production records are created by tests.

## Dependencies

The application intentionally keeps dependencies small. `supabase_flutter` provides the authenticated backend client and `file_picker` supports media selection. The unused generated `cupertino_icons` dependency was removed during Phase 24 after confirming there were no code references.

## Future Work

New features should be added under a feature folder with focused screens, widgets, models, and services only when those boundaries remove real coupling. The existing repository records remain together for compatibility; they can be split into feature model files incrementally when a feature change requires it. Avoid introducing a state-management framework or moving privileged behavior into Flutter without a concrete architectural need.

## Phase 27 Final Visual Polish

The visual system remains a dark Material 3 Control Room with NEWITT cyan accents. `AppTheme` centralizes panel, border, muted-text, field, button, navigation, snackbar, divider, and tooltip defaults. Existing feature cards retain their established visual language while inheriting more consistent interaction states and touch sizing.

The shell uses the shared responsive frame and role-aware navigation metadata. The sidebar, mobile NavigationBar, More sheet, account affordance, loading/error states, and feature page frames remain presentation-only; authentication, repository access, RLS, audit protection, and Content Safety gates are unchanged.

The repository asset audit found platform app icons but no declared NEWITT Media photography, Essex Paranormal logos, tenant image library, or custom font assets. No unapproved imagery, fake logos, or downloaded stock assets were introduced. Branding therefore remains the existing text-based NEWITT MEDIA lockup and authenticated site/organisation names, keeping tenant identity separation intact.

Final polish validation covered 51 Flutter tests; customer account management and content/media editor coverage bring the current suite to 53 passing tests. Responsive surfaces range from 320x568 through 2560x1400, with analyzer cleanliness and available macOS, unsigned iOS, and web builds verified. A non-fatal missed-tap warning remains in the legacy widget suite; it does not affect production behavior or test success.

## Customer Account And Invitation Management

Customer users are linked to an existing `customer_accounts` row through the server-created `profiles` row. The Flutter repository calls the deployed `customer-account-management` Edge Function for Master Admin operations; it does not call Supabase Auth admin APIs directly.

The function verifies the caller's authenticated user and `MASTER_ADMIN` profile, verifies the selected existing customer account, and scopes all customer-user profile queries to that tenant. Invitation uses Supabase Auth `inviteUserByEmail`. The invited customer receives the email and chooses their own password. The app has no password field in customer-user management models or dialogs, and audit metadata contains no authentication secrets.

The function exposes only safe account fields: email, display name, role, `INVITED`/`ACTIVE`/`DISABLED` status, creation time, and last sign-in time. Disabling uses Supabase Auth's server-side ban duration; enabling removes that ban. Customer users cannot access the management route, alter their tenant or role, or select a tenant client-side.

Production email delivery requires Supabase Auth email/SMTP configuration and a correctly configured Site URL/redirect flow. Those values are managed in Supabase configuration and are not stored in Flutter, migrations, source, tests, or documentation. The existing password reset service remains the customer-facing recovery path.

## Content And Media Editor

The practical editor extends the existing tenant-scoped `media`, `website_content`, and `website_pages` foundations. Media uploads continue through the existing `website-media` bucket and `MediaUploadRequest`; files are selected in batches, uploaded under the authenticated tenant/website path, and now show per-file progress. Metadata remains editable for title, caption, category, date, location, type, and featured state.

Page sections are stored as validated JSON objects inside the existing `website_content.content` document. The editor supports headings, lightweight rich text with heading/bullet/bold/italic markers, Media Library images, galleries, videos, external video URL references, buttons/links, investigation/location cards, and featured-content cards. Media sections store an existing media ID, so selecting a library item reuses the upload rather than duplicating it. Preview renders section types as safe UI records; it does not execute arbitrary HTML or JavaScript.

The existing draft, preview, Content Safety, approval, and publish controls remain the workflow boundary. No new storage bucket, media table, page-section table, migration, or public-media policy was introduced. The deployed media RLS and `website-media` storage policies remain authoritative. External video links are currently represented in page-section JSON only; the media table is intentionally not overloaded with external URLs because its deletion and storage semantics are for owned files.

## Customer-Specific Configuration

`WebsiteConfiguration` provides one generic configuration shape for tenant websites. The current defaults keep NEWITT Media and Essex Paranormal separate: each has its own brand label, tagline, content areas, contact areas, and social-platform list. These defaults are used for development/preview and as fallbacks; persisted per-website overrides live in the additive `websites.website_settings` JSONB column. No tenant records or website rows were seeded by this phase.

The deployed `contact_enquiries` foundation stores private name, email, message, area, status, and internal notes under the authenticated website tenant. The `submit-contact-enquiry` Edge Function resolves the tenant from the submitted domain, validates the configured area list, and inserts through the server role. It returns only a generic received status. Control Room reads remain RLS-scoped.

## Staging Public Contact Security

The staging contact endpoint is intentionally designed to become public only after a controlled deployment that preserves its current JWT setting until review is complete. It accepts the five contact fields plus a Cloudflare Turnstile token, rejects all browser-supplied internal fields, and resolves `newittmedia.co.uk` to its tenant and website server-side. `NEWITT_CONTACT_ALLOWED_ORIGINS` must list explicit HTTPS staging and production origins; wildcard CORS is not permitted.

The read-only `public-website-content` endpoint follows the same origin discipline through `NEWITT_PUBLIC_CONTENT_ALLOWED_ORIGINS`. It accepts only `{ domain: "newittmedia.co.uk" }`, resolves the tenant and website server-side, and serves only published, visible pages; published content; HTTPS social links; and a small whitelist of public presentation settings. It never returns raw website settings, tenant or website IDs, profiles, enquiries, internal notes, audit data, bookings, payments, credentials, or service-role information. The static public site treats unavailable or invalid responses as optional enhancements and preserves its local content.

Before persistence, the function verifies the token with `TURNSTILE_SECRET_KEY` and requires its hostname to match `TURNSTILE_EXPECTED_HOSTNAME`. A `CONTACT_RATE_LIMIT_SALT` produces a non-reversible client-key hash from the trusted proxy client signal. The private `contact_submission_rate_limits` table and service-role-only RPC enforce a bounded per-website limit, configured by `CONTACT_RATE_LIMIT_MAX` and `CONTACT_RATE_LIMIT_WINDOW_SECONDS`.

`contact_enquiry_notifications` is a tenant- and website-scoped, one-to-one outbox record created in the same transaction as the authoritative enquiry. It records only a recipient secret key, never a recipient address. When configured, `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, and the `NEWITT_CONTACT_RECIPIENT_*` secrets are read only by the Edge Function. Delivery is marked `SENT` only after the provider accepts it; failure leaves the enquiry intact and marks the outbox record `FAILED` for an idempotent token-protected retry. No secret values belong in source control, browser code, migrations, logs, or public responses.

Staging deployment requires `NEWITT_CONTACT_ALLOWED_ORIGINS`, `NEWITT_PUBLIC_CONTENT_ALLOWED_ORIGINS`, `TURNSTILE_SECRET_KEY`, `TURNSTILE_EXPECTED_HOSTNAME`, `CONTACT_RATE_LIMIT_SALT`, `CONTACT_RATE_LIMIT_MAX`, and `CONTACT_RATE_LIMIT_WINDOW_SECONDS`, plus non-production Resend sender/recipient secrets. Production requires a separate security review, production Turnstile hostname/origin settings, rate-limit monitoring, and a deliberate decision on public endpoint authentication and anti-abuse controls.

The Support screen now links to the tenant-scoped Contact Enquiries manager. Authorised users can search, filter by status, inspect private enquiry details, change status, and save internal notes. The public submission function never returns those fields.

The existing `provision-customer` Edge Function now optionally creates the first website and `website_settings` record in the same server-side provisioning flow before sending the Supabase Auth invitation. Website name/domain are validated server-side, and rollback removes the newly created tenant if invitation or profile creation fails. This supports future customers without source-code changes.

The deployed `public-website-content` Edge Function resolves a website by domain server-side and returns only public website settings, published website pages, published website content, and website social links. It rejects unknown domains and websites that are not APPROVED or PUBLISHED. It does not accept a tenant ID and does not return profiles, bookings, enquiries, internal notes, audit data, payment credentials, or draft content.

Typed investigation, location, event, booking, podcast, case-file, evidence, and payment tables are intentionally deferred because none exist in the current deployed schema. PayPal and SumUp remain future server-side integrations. The current generic page-section, media, social-link, support, and contact-enquiry foundations are the safe extension points for those features.

At the time of this foundation pass, the linked project had no production website rows for `newittmedia.co.uk` or `essexparanormal.com`. No such rows were fabricated. An authorised Master Admin must provision the real tenant/website records, configure domains and settings, and connect the public website frontends to the deployed functions before either domain is live.

## Existing Website Onboarding And Feature Mapping

Customer provisioning now asks whether a website already exists. The choice is persisted in `website_settings` as either `PRESERVE_IMPROVE_EXISTING` with `EXISTING` status or `CREATE_NEW` with `NOT_STARTED` status. Existing mode is informational and protective; it never pushes files, deletes pages, replaces assets, or changes a live repository.

`website_feature_inventory` is a tenant-scoped mapping table for evidence-based feature onboarding. Each website feature records an evidence status (`EXISTING`, `AVAILABLE`, `NEEDS_REVIEW`, `DISABLED`, or `PLANNED`), whether it is connected, whether it is enabled, and optional evidence/notes. The Website Management screen exposes the mapping UI. Saving a feature mapping does not create the feature, publish it, or alter the existing website.

The inventory intentionally does not claim that a feature exists merely because the Control Room supports it. The current project has no secure GitHub repository inspection authorization or public website crawler, so real repository detection for `newittmedia.co.uk` and `essexparanormal.com` remains `NEEDS_REVIEW` until an authorized, non-destructive inspection source is connected. No GitHub credentials were added.

## Essex Paranormal Existing-Site Onboarding

The verified existing Essex Paranormal source is `NW13TTT/Essex-Paranormal` on `main`, with `backup-current-site` retained as a separate backup branch. It is independently deployed as the `essex-paranormal` Cloudflare Worker for `essexparanormal.com`; it is not a NEWITT Media website repository or tenant. The Control Room's distinct `WebsiteConfiguration.essexParanormal` mapping is limited to `essexparanormal.com`, while `newittmedia.co.uk` remains mapped only to NEWITT Media.

An authorised Master Admin must use the existing customer provisioning workflow to create the real Essex Paranormal customer account and its `essexparanormal.com` website record. Selecting "Yes - preserve and improve existing website" persists `websiteStatus: EXISTING` and `managementMode: PRESERVE_IMPROVE_EXISTING` inside that website's tenant-owned settings. This records onboarding intent only: it does not inspect, overwrite, publish, deploy, or replace the website. No real tenant, website, GitHub, Cloudflare, feature-inventory, or public-content record is seeded by source code.

The verified source inventory is evidence-only. Homepage, navigation, branding, hero, about, contact form, investigations, locations, evidence presentation, and gallery placeholders are `EXISTING`. Social links remain `NEEDS_REVIEW` because their targets are placeholders. Case-file records, real gallery media, videos, bookings, payments, and media-library integration are `NEEDS_REVIEW` or `PLANNED`; none are connected by this foundation. After the authenticated website record exists, a scoped Master Admin may save these evidence statuses to `website_feature_inventory`. The inventory update never changes the existing public website.

The public NEWITT Media endpoints intentionally reject `essexparanormal.com` during the current staged rollout. Essex public content or contact integration requires a separately reviewed domain/origin policy and the real Essex tenant/website record. Browser input must remain domain-only; server-side lookup and the existing website-tenant consistency controls must resolve scope before any private data can be read or written.
