# newitt_media_control_room

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Media staging and release checks

Enable R2 on the Cloudflare account that owns the Control Room Worker and provision the private `newitt-control-room-media-staging` bucket. Configure the staging Worker with the staging Supabase URL and publishable key, apply the photo lookup migration to the staging database, and set the staging public content function's `CONTROL_ROOM_MEDIA_ORIGIN` to the staging Worker URL. Use a staging Supabase project with two test tenants and an isolated copy of the website publishing integration. Keep customer records and existing production buckets out of this test.

Set the staging client configuration in `config/media-staging.json` and allow the staging password reset callback in Supabase. Build with `tool/deploy_control_room.sh --media-staging-build`. Validate the bundle with `wrangler deploy --dry-run --env media-staging --config wrangler.control-room.jsonc` before deploying the staging Worker. Check sign-in, password reset, session persistence and both directions of tenant isolation. Upload and preview JPEG, PNG, HEIC and HEIF on iPhone Safari and the Home Screen app. Publish, replace, remove and restore test content. Compare both test websites after each action. Remove test media and verify legacy Supabase media still renders. Test staff booking creation, edits, cancellation and release of capacity using test events.

## Deferred SumUp verification

When sandbox access is available, confirm the sandbox merchant and credentials through the existing secure configuration. Run a genuine hosted sandbox checkout, verify payment status directly with SumUp, and confirm the webhook and Control Room booking and capacity updates. Exercise failed, cancelled and expired payments, duplicate notifications and concurrent attempts to take the final place. Keep existing booking and payment records intact throughout staging and leave live payment activation for a separate release decision.
