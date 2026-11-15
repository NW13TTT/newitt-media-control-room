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

## Supabase media staging

Build with `tool/deploy_control_room.sh --media-staging-build` using a staging Supabase project. Apply the storage quota migration there first. Verify direct Storage API uploads respect quota and file limits, including simultaneous uploads. Then verify native iPhone Safari HEIC/HEIF conversion, private previews, publishing, unpublishing and deletion with two test tenants. Verify existing Supabase media paths still resolve.

The migration proposes 400 MB per customer, 800 MB across the website-media bucket and 50 MiB per file. Administrators can change the private budget and tenant overrides after checking the organisation's storage usage. Production and staging Worker configurations require only the existing asset binding.

## Deferred SumUp verification

When sandbox access is available, confirm the sandbox merchant and credentials through the existing secure configuration. Run a genuine hosted sandbox checkout, verify payment status directly with SumUp, and confirm the webhook and Control Room booking and capacity updates. Exercise failed, cancelled and expired payments, duplicate notifications and concurrent attempts to take the final place. Keep existing booking and payment records intact throughout staging and leave live payment activation for a separate release decision.
