# Product Requirements: Clip Sync

**Version:** 1.0 — Draft
**Date:** 2026-08-18
**Status:** POC / Pre-production
**Changelog:** Initial draft

---

## 1. Overview

### What this is

Clip Sync is a hosted clipboard synchronization service with separate applications for Windows 11, macOS, iOS, and Android. It automatically synchronizes clipboard items between a user's online Windows and Mac computers, while all supported clients provide access to the user's persisted clipboard history and can send shared text or photos into that clipboard.

The hosted service supports multiple registered accounts, but each account owns one private, top-level clipboard. Clipboard content is never shared between different users.

### Why we're building it

People who work across several computers need a direct way to move recently copied content between them without manually sending it through another application. Clip Sync provides automatic delivery between online desktop computers and a server-backed history that the account owner can browse from any supported device.

### What success looks like for the POC

The POC is complete when:

- Anyone can register an account and sign in using either a six-digit code sent by email or Google authentication.
- Each account has one private clipboard and cannot access another account's clipboard.
- A resident user-level application on Windows 11 and macOS detects local copy activity and sends the copied item to the backend unless synchronization is paused.
- An item received by the backend is stored in the account's history and delivered to the account's other online Windows and Mac clients.
- An online desktop client places a delivered item into its operating system clipboard.
- Offline clients do not receive missed items automatically after reconnecting, but the account owner can find those items in persisted history and copy them manually.
- Windows, macOS, iOS, and Android clients can display the account's full clipboard history, copy an older item into the local operating system clipboard, and delete a history item.
- Mobile clients do not automatically monitor or update their clipboards.
- Every delivered client provides an operating-system share-to action that can send text or a photo to the backend and onward to online Windows and Mac clients.
- Pausing synchronization on a desktop prevents newly copied sensitive content from being uploaded, stored in history, or sent to another computer.
- The API, PostgreSQL, MongoDB, and all other server-side components run in Docker containers using the approved datastore responsibilities.

---

## 2. Who uses this

Clip Sync is used by an individual account owner who works across one or more Windows, Mac, iOS, or Android devices.

The hosted service can contain many accounts, but users do not collaborate with each other. Each account owner interacts only with the single clipboard and history owned by that account.

On Windows and macOS, the account owner runs a resident user-level application that automatically observes local copy activity while synchronization is active. The user can pause synchronization from the desktop tray or menu integration before copying sensitive information.

On iOS and Android, the account owner uses the application to browse persisted history, manually copy a selected item into the mobile device's clipboard, delete history items, or share text or a photo to Clip Sync. The mobile applications do not monitor the clipboard or receive clipboard items automatically.

There is no administrator user type or cross-account sharing role described for the POC.

---

## 3. Core features

### Account registration and authentication

**What it does:** Allows anyone using the hosted service to create an account and securely access that account's private clipboard.

**How it works:**

1. The user chooses one of two authentication methods.
2. For email-based passwordless authentication, the service sends the user a six-digit numeric code.
3. The user enters the code to complete sign-in.
4. Alternatively, the user signs in with Google using OAuth or OpenID Connect (OIDC), with the exact protocol choice still unresolved.
5. After authentication, the client receives access only to the clipboard owned by that account.

**Rules and constraints:**

- Each account owns exactly one top-level clipboard.
- A clipboard has only one owner.
- There are no personal access tokens.
- There is no clipboard sharing between accounts.
- Device or key revocation is not required for the POC.
- There is no device-count limit for the POC.

### Automatic desktop clipboard synchronization

**What it does:** Sends locally copied desktop content to the backend and places newly received content into other online desktop clipboards.

**How it works:**

1. A resident user-level Clip Sync application runs on Windows 11 or macOS.
2. While synchronization is active, the application detects when the user copies an item.
3. The application sends that item to the backend API.
4. The backend stores the item in the authenticated account's history.
5. The backend pushes the new item only to that account's Windows and Mac clients that are online at that moment.
6. Each receiving desktop client places the item into its local operating system clipboard.

**Rules and constraints:**

- Automatic clipboard monitoring and delivery apply only to Windows and Mac clients.
- The last item received by the backend from one of the account's clients wins for current-buffer propagation.
- No special simultaneous-edit or collision-handling behavior is required.
- A client that is offline when an item arrives does not receive that item automatically after reconnecting.
- A receiving client must not create an endless upload-and-delivery loop; the required loop-prevention behavior remains an open implementation question.
- Clipboard history and content are not persistently stored by the client application. They remain server-backed, apart from an item placed in the operating system's clipboard.

### Pause desktop synchronization

**What it does:** Lets a desktop user temporarily prevent sensitive clipboard content from leaving the computer.

**How it works:**

1. The user opens Clip Sync from the Windows system tray or the corresponding macOS menu integration.
2. The user pauses synchronization.
3. Copy operations performed while paused remain local to that computer.
4. The user resumes synchronization when automatic capture should continue.

**Rules and constraints:**

- Content copied while synchronization is paused must not be uploaded.
- Paused content must not be stored in backend history.
- Paused content must not be propagated to another computer.
- The POC does not describe retroactively uploading items copied during the paused period.

### Persistent clipboard history

**What it does:** Gives the account owner access to clipboard items previously stored by the backend.

**How it works:**

1. An authenticated client requests the history belonging to its account.
2. The application displays the account's full persisted clipboard history.
3. The user selects an earlier item.
4. The client copies the selected item into that device's local operating system clipboard.
5. The user can tap or click the leading content icon to select or deselect one or more history items. A selected icon displays a checkmark.
6. When at least one item is selected, the user can choose Delete selected, review the selected count, and confirm before the items are removed.
7. Each history item identifies the device that created it by the device's current display name.
8. The user can open device management and rename any device owned by the account.

**Rules and constraints:**

- History is scoped to the authenticated account's single clipboard.
- History remains indefinitely unless the user deletes an item.
- Browsing and manually copying history are available on Windows, macOS, iOS, and Android.
- Multi-item selection, confirmation, and deletion are available on Windows, macOS, iOS, and Android.
- Persisted history does not cause automatic catch-up synchronization when an offline client reconnects.
- Clipboard content is stored in MongoDB rather than persisted in the client application.
- Each client registers its operating-system-reported device name. An account-assigned rename is reflected in history on every other device's next refresh.
- Device listing and renaming are restricted to the authenticated account.
- While the Android, iOS, or macOS history screen is visible, it refreshes every 5 seconds for the first 30 seconds, then every 30 seconds. Automatic refresh pauses after 2 minutes and shows a visible paused indicator until the user presses Refresh or pulls down to refresh, which reloads history and restarts the schedule.

### Mobile clipboard access

**What it does:** Lets iOS and Android users view, copy, delete, and share clipboard content without automatic mobile synchronization.

**How it works:**

1. The user signs in to the separate iOS or Android application.
2. The application loads the user's server-backed clipboard history.
3. The user taps an item to place it into the mobile device's local clipboard, or deletes an item from history.
4. The user may also invoke the device's share interface to send text or a photo to Clip Sync.

**Rules and constraints:**

- Mobile applications do not monitor local clipboard changes.
- Mobile applications do not automatically receive an incoming item into the device clipboard.
- Copying from history is an explicit user action.
- The iOS and Android applications are separate delivered applications, not one universal binary containing resources for every supported platform.

### Share to Clip Sync

**What it does:** Lets a user send text or a photo from another application into the account's Clip Sync clipboard.

**How it works:**

1. The user selects text or a photo in another application.
2. The user chooses Clip Sync from the operating system's share interface.
3. Clip Sync sends the shared item to the backend API for the authenticated account.
4. The backend stores the item in clipboard history.
5. The backend pushes the item to the account's Windows and Mac clients that are online at that moment.
6. Those desktop clients place the item into their local operating system clipboards.

**Rules and constraints:**

- Share-to capability is required in every delivered Clip Sync client.
- Shared items are private to the authenticated account.
- Shared items are not automatically delivered into an iOS or Android clipboard.
- Offline desktop clients do not receive the shared item automatically after reconnecting.
- Supported shared content explicitly includes text and photos. Other clipboard content types are unresolved.

### Target-specific client applications

**What it does:** Provides a small application tailored to each supported operating system.

**How it works:**

1. Flutter is used to build the user interface for each application.
2. Each application is compiled into a native application for its target platform.
3. Each delivered application contains only the resources required for its target platform.
4. Shared UI artifacts may be organized in separate packages where that does not cause unrelated platform resources to be shipped.

**Rules and constraints:**

- Do not deploy one universal application containing all resources for all platforms.
- Keep each delivered application as small as practical.
- Windows 11 requires system tray integration.
- macOS requires resident desktop integration, although the exact meaning of the earlier “visible in Finder” requirement needs clarification.
- Reusability is not a POC goal. Do not add speculative abstractions or extension points.

---

## 4. Key user flows

### Register and sign in with an email code

1. The user opens a Clip Sync client.
2. The user chooses email-based passwordless sign-in.
3. The service sends a six-digit numeric code to the user's email address.
4. The user enters the code in the client.
5. The backend authenticates the user and grants access to that account's single private clipboard.
6. The client displays the account's clipboard history.

### Sign in with Google

1. The user opens a Clip Sync client.
2. The user chooses Google sign-in.
3. The client completes the approved Google OAuth or OpenID Connect flow.
4. The backend identifies the user's account.
5. The client receives access to that account's single private clipboard.

### Copy an item between online computers

1. The user copies an item on a Windows or Mac computer while Clip Sync is active.
2. The resident desktop application detects the copy operation.
3. The application sends the item to the backend.
4. The backend stores the item in the account's history.
5. The backend sends the item to the account's other online Windows and Mac clients.
6. Each receiving desktop client places the item into its local clipboard.
7. If multiple items reach the server close together, the last item received becomes the current item propagated to online desktop clients.

### Pause before copying sensitive content

1. The user opens the desktop tray or menu control.
2. The user pauses synchronization.
3. The user copies sensitive content.
4. The content stays on that computer and is neither uploaded nor stored by Clip Sync.
5. The user resumes synchronization when automatic capture is safe again.
6. Clip Sync begins observing later copy operations without uploading content copied during the pause.

### Recover an item from history

1. The user signs in on any supported client.
2. The client loads the account's persisted clipboard history from the backend.
3. The user selects an earlier item.
4. The client places that selected item into the local operating system clipboard.
5. No automatic propagation is implied merely by viewing history; the behavior caused by manually copying a history item on a desktop must follow the final loop-prevention decision.

### Use history after reconnecting an offline client

1. A desktop client is offline when another client sends a new item.
2. The backend stores the item and sends it only to clients that are currently online.
3. The offline client reconnects later.
4. The backend does not automatically place the missed item into that client's clipboard.
5. The user opens history and manually selects the item if it is still needed.

### Share text or a photo to Clip Sync

1. The user selects text or a photo in another application.
2. The user invokes the operating system's share interface and chooses Clip Sync.
3. Clip Sync uploads the item to the account's clipboard.
4. The backend stores the item in history.
5. The backend sends it to the account's currently online Windows and Mac clients.
6. The item is not automatically placed into an iOS or Android clipboard.

### Delete selected history items

1. The user opens clipboard history on a supported client.
2. The user taps or clicks the leading content icon for each item to select. Tapping or clicking it again deselects that item.
3. The client displays the selected count and enables Delete selected.
4. The user chooses Delete selected and confirms the selected count.
5. The client requests deletion of every selected item through the backend.
6. Deleted items no longer appear in the account's persisted clipboard history.

---

## 5. Technical requirements

### Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Runtime | Bun | Preferred runtime for the backend API. |
| Framework | Flutter | Required for each client application's UI. The backend API framework is not specified. |
| Database | PostgreSQL and MongoDB | PostgreSQL is approved for backend security and event handling. MongoDB is approved for text and blob clipboard content. |
| ORM | Drizzle ORM and Mongoose | Drizzle ORM is approved for PostgreSQL. Mongoose is approved for MongoDB. |
| Auth | Six-digit email code; Google OAuth or OpenID Connect | Passwordless email and Google sign-in are required. The exact Google protocol choice and authentication service implementation are unresolved. |
| Payments | Not specified | No payment requirements appear in the brain dumps. |
| Hosting/Deployment | Docker | The API, databases, and all other server-side components must be Dockerized. The hosting provider and runtime environment are not specified. |

### Technical constraints

- The approved datastore split is intentional: PostgreSQL handles backend security and event-handling concerns, while MongoDB stores text and blob clipboard content. This decision comes from the 2026-08-18 07:36 brain dump.
- The backend API should use Bun unless a later product decision changes the preferred runtime. This preference comes from the 2026-08-18 07:36 brain dump.
- All server-side components, including both databases, must run in Docker containers. This requirement comes from the 2026-08-18 06:40 brain dump.
- The hosted backend supports multiple independently registered accounts, while each account owns exactly one private clipboard.
- The backend is the authoritative persistent store for clipboard history. Client applications must not maintain their own persistent clipboard-history store.
- Real-time delivery is online-only. Persistence provides manual historical access, not automatic reconnect catch-up.
- Desktop propagation uses last-item-received-wins behavior and does not require special collision resolution.
- Flutter is used separately for each target application's UI. Do not ship one application containing every platform's resources.
- Windows and macOS require resident user-level behavior in addition to their Flutter UI.
- Pausing desktop synchronization is a privacy boundary: items copied while paused must never reach the API or backend storage.
- The POC should use the smallest direct implementation that satisfies these requirements. Shared abstractions are optional and must not cause speculative functionality or oversized target binaries.

### Data model

The conceptual data model contains the following information:

- The hosted service has multiple accounts.
- Each account owns one and only one top-level clipboard.
- Each account owns its registered Clip Sync devices and may assign each one a display name.
- Each clipboard belongs to one account and contains that account's persisted clipboard-item history.
- A clipboard item contains text or blob content, such as a photo, stored in MongoDB.
- New clipboard items retain the stable source-device UID so history can resolve the device's current display name.
- PostgreSQL supports the account security and backend event-handling responsibilities associated with authenticated access and item propagation.
- An authenticated client acts on the clipboard owned by its account.
- Windows and Mac clients may have an online connection through which the backend delivers newly received items.
- Clipboard items remain in history until their owner deletes them.
- The relationship between PostgreSQL security/event information and MongoDB clipboard content must preserve account isolation, but its concrete identifiers, schema, and API contracts are not yet defined.

---

## 6. Out of scope for the POC

- Sharing a clipboard or clipboard item with another user or account.
- Personal access tokens.
- Automatic clipboard monitoring on iOS or Android.
- Automatic delivery of incoming content into an iOS or Android clipboard.
- Automatically replaying missed clipboard items when an offline client reconnects.
- Special conflict resolution beyond last-item-received-wins behavior.
- A device-count limit.
- Device or key revocation.
- Client-side persistent clipboard history.
- One universal Flutter application or binary that contains resources for every supported platform.
- Speculative reusable architecture, integrations, configuration options, or extension points not needed by the POC.
- Payment behavior, because no payment requirement has been defined.

---

## 7. Open questions

- **Google authentication protocol:** Should Google sign-in use OAuth alone or OpenID Connect, which adds a standard identity layer on top of OAuth? The choice affects the authentication flow and backend identity validation.
- **Email authentication implementation:** Which email delivery service sends the six-digit code, and what are the code's expiration, retry, and reuse rules? These details are required to build and validate passwordless sign-in.
- **Authentication state on clients:** Does the statement that nothing is stored on clients apply only to clipboard content and history, or also to login-session material? Clients need an approved way to remain authenticated without weakening account security.
- **Backend API framework:** Bun is the preferred runtime, but no API framework has been selected. The implementation cannot be finalized until the Bun-compatible API approach is chosen.
- **Real-time delivery transport:** The mechanism used to push items to online Windows and Mac clients is not specified. This decision affects how the server determines that a client is online and delivers events.
- **Desktop loop prevention:** How should a desktop client distinguish a remotely delivered clipboard update from a new local copy so it does not upload the same item repeatedly? This behavior is necessary for stable automatic synchronization.
- **Originating-client delivery:** Should the backend exclude the client that uploaded an item from real-time delivery, or may it echo the item back to that client? The answer affects event routing and loop prevention.
- **Supported clipboard content:** Text and photos are explicitly supported, but it is unclear whether other clipboard formats must be handled. Size limits and accepted image formats are also unspecified.
- **Share-to platform integration:** The required operating-system integration and user experience for share-to behavior have not been defined for each of Windows, macOS, iOS, and Android.
- **macOS application presentation:** The initial description says the macOS application is “visible in Finder,” while a later clarification requires desktop tray/menu integration. The expected Finder presence and menu-bar behavior need a precise definition.
- **Backend hosting target:** Server-side components must be Dockerized, but the hosting provider, server layout, public network configuration, and deployment environments are not specified.
- **History ordering and display:** The history is described as complete and indefinite, but its ordering and UI presentation have not been explicitly defined.
- **Deletion behavior:** The user can delete a history item, but the required confirmation behavior and treatment of any related backend event information are not specified.

---

## 8. Assumptions

- The later clarification of “single-user” supersedes the narrower initial wording: Clip Sync is a multi-account hosted service, but each clipboard is private to one account owner.
- “Nothing is stored on the client” refers to Clip Sync-managed persistent clipboard content and history. An operating system necessarily holds the current clipboard value after the user copies or receives an item.
- A client's history view always shows only the authenticated account's clipboard history.
- “Online client” means a Windows or Mac client that is currently able to receive a server-pushed item; the concrete connection mechanism remains unresolved.
- Last-item-received-wins ordering is based on the order in which the backend receives clipboard items.
- Content copied while desktop synchronization is paused is intentionally omitted rather than queued for upload after synchronization resumes.
- Mobile users can manually copy a history item into the local clipboard, but the mobile application performs no background clipboard monitoring or incoming automatic delivery.
- A share-to action creates a persisted history item and triggers online desktop propagation in the same way as other newly received server items.
- The separate Windows, macOS, iOS, and Android deliverables may share development artifacts, but each delivered application contains only the resources needed for its target.
