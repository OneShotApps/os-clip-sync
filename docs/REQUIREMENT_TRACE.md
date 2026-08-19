# Requirement trace

This is the implementation audit for `docs/concepts/REQUIREMENTS.md` version 1.0.

| Requirement | Implementation evidence |
|---|---|
| Public registration and six-digit email sign-in | Hono email request/verify routes, keyed code hashes, SMTP sender, ten-minute/single-use/five-attempt rules, Mailpit integration test. |
| Google sign-in | Native client OIDC token acquisition and API signature/issuer/audience/verified-email validation. |
| One private clipboard per account | Transactional PostgreSQL account/identifier/clipboard creation, one-active-clipboard unique key, token-derived owner lookups, cross-account integration tests. |
| Windows resident automatic synchronization | Separate Windows Flutter target, polling/fingerprint loop prevention, WebSocket receive, tray pause/show/quit, close-to-tray behavior. |
| macOS resident automatic synchronization | Separate macOS Flutter target, polling/fingerprint loop prevention, WebSocket receive, menu-bar pause/show/quit, application remains resident after window close. |
| Online-only delivery and no reconnect replay | In-memory owner-scoped WebSocket hub, source-client exclusion, no queue, integration test reconnects and confirms no missed item is pushed. |
| Last server-received item wins | Create route persists each accepted item and broadcasts immediately in request completion order; no conflict layer is present. |
| Pause privacy boundary | Desktop controller stops polling while paused and baselines the current clipboard on resume, so paused content is never uploaded later. |
| Server-backed indefinite history | MongoDB text/photo documents have no automatic expiry, newest-first pagination, owner-scoped detail, and soft deletion. Clients store no history database. |
| Device names and account-owned renaming | OS-backed device-name provider, stable client UID registration, account-scoped PostgreSQL device registry, source UID on new MongoDB items, dynamically resolved history labels, and rename controls in all four apps. |
| Browse, manual copy, and confirmed multi-item deletion on every target | Shared controller plus target-specific Windows/macOS/iOS/Android selection state, checked leading icons, selected counts, confirmation prompts, and delete actions; photo detail is loaded only when copied. |
| Adaptive visible-history refresh on iOS and macOS | Shared `HistoryRefreshScheduler`, target lifecycle/window visibility hooks, manual restart controls, and target-specific paused indicators. |
| No automatic mobile monitoring or incoming clipboard writes | iOS and Android instantiate no desktop sync controller or WebSocket and modify the clipboard only after a user taps Copy. |
| Share text/photo from Android | `ACTION_SEND` text/image filters plus `share_handler` intake. |
| Share text/photo from iOS | Native Share Extension, shared App Group, repeatable Xcode target configuration, and `share_handler` intake. |
| Share text/photo from macOS | Native `NSServices` provider for text/image/file URLs and a Flutter method channel. |
| Share text/photo from Windows | MSIX full-trust Flutter app plus UWP Share Target for text, bitmap, and image files using package local state and protocol activation. |
| Supported content and limits | UTF-8 text up to 256 KiB; PNG/JPEG/WebP photos up to 10 MiB; MIME allowlist and byte-signature validation. |
| Separate target deliverables | Four self-contained Flutter application folders, each generated only for its own native platform, with one small private shared package. |
| Bun API and approved datastore split | Bun 1.3.14/Hono API; Drizzle/PostgreSQL for authentication and delivery events; Mongoose/MongoDB for content. |
| Complete Docker server environments | Local, development, and production Compose definitions; API Dockerfile; PostgreSQL, MongoDB, health checks, dependencies, persistent volumes, startup configuration validation. Local adds Mailpit. |
| Single EC2 Compose deployment | Production runbook covers immutable tags, secrets, TLS/WebSocket proxying, health validation, backups, troubleshooting, rolling corrective releases, and safe stop behavior. |
| Junior-readable operation and maintenance | Root/app/package READMEs, architecture/data decisions, OpenAPI 3.1 contract, YAML persisted schemas, deployment and validation runbooks, focused modules, and JSDoc on shared backend boundaries. |

The unresolved product questions from the draft requirements are closed conservatively in `docs/architecture/DECISIONS.md`. Device naming and renaming are the only approved device-management behavior; no sharing, administration, payments, device revocation, mobile monitoring, reconnect replay, or client-side history store was added.
