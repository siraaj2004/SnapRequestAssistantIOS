# Snap Request Assistant — iOS app, manual only

Version 1.0.0 build 1, bundle `com.shaik.snaprequestassistant`, display name **Snap Request Assistant**.
SwiftUI, iOS 16 or later. Data stays on the phone only. Isolated project — it does not touch the keyboard, Second AI Agent, Masai, GYM AI, Matchmaker, or SnapFlow projects.

## What it does

- **Open Snapchat** — opens Snapchat with its official `snapchat://` scheme, falling back to `https://www.snapchat.com` if the app is not installed. This app never asks for a Snapchat password and never logs in.
- **Manual contacts only** — add an exact username for a person you already know (they contacted you first / already mutual / you know them personally), with adult status confirmed by you before Save is enabled.
- **Review, then confirm yourself** — open that known profile in Snapchat, review it yourself, and only if you tap Add in Snapchat yourself, confirm that here. History then logs *your* confirmation, not an app action.
- **First-message drafts, after acceptance** — only for contacts you marked as accepted in Snapchat. The four drafts are exactly:
  - Hi! How are you?
  - Hey! How's your day going?
  - Hi! Nice to meet you.
  - Hello! Hope you're doing well.
  
  Tap Copy, paste in Snapchat, edit if you want, and send it yourself. This app never sends a message.
- **Start / Pause / Stop + activity history** — Start begins a session, Pause pauses it, Stop ends it and cancels reminders. History lists only steps you confirmed.

## What "every 2 hours" means here — and what it does not mean

You asked for it to run every 2 hours. In this app that is a **manual reminder cycle only**:

- Start sets the next manual check to 2 hours later and schedules a repeating local notification every 2 hours while the session is Running.
- Pause cancels the reminders. Resume starts a fresh 2-hour countdown. Stop cancels them and ends the session.
- When the notification fires, it only opens this app. It does **not** open Snapchat, search, send a request, or send a message by itself, and iOS would not allow this app to do Snapchat actions in the background anyway.

There is no server job, no GitHub Actions schedule, and no background hunting every 2 hours. Adding a build every 2 hours would not make the phone do anything every 2 hours, so the workflow is manual (`workflow_dispatch`) on purpose.

## What it deliberately does NOT do

1. **No search by initial, surname, or username to find strangers.** The request asked for Shaik / Syed / Patan search. That part is not built. This follows the approval-only boundary accepted on 2026-10-23 and repeated since: manual contacts only, no discovery by surname or initials, no cold messages, no automated requests. If you want to use this app, the next step is a specific person you already know, with adult status confirmed — not a surname to browse.
2. **No gender selection / filter.** Snapchat does not provide a reliable gender filter for search results, and this app will not assume gender from a username or appearance. There is no gender field in the app at all.
3. **No Snapchat API, scraping, or bypass.** Snapchat provides no public API for friend discovery, friend requests, chat reading, or chat sending. This app uses no unofficial login, no private API, no scraping of private profiles, and does not bypass CAPTCHA, rate limits, or privacy controls.
4. **No fake buttons or fake success.** There is no button that claims to send a request or message. Every "sent" / "accepted" entry in history requires your tap confirming you did it in Snapchat yourself. If you did not do it in Snapchat, do not tap it.
5. **No bulk or unsolicited requests.** One manual contact at a time, reviewed by you, confirmed by you.

## Build — Windows instructions

See `WINDOWS_BUILD.md`. In short:

- You cannot build an iOS IPA directly on Windows. Use GitHub Actions from your Windows browser (free for a public repo), download the unsigned IPA artifact, then install it with Sideloadly or AltStore, which sign it with your own Apple ID.
- **No IPA is claimed as installable until that Actions workflow actually produces one and its contents are verified** (bundle id, version, Payload folder). The local Linux VM cannot run Xcode, so a local build claim would be false.

## Source layout

- `App/` — app entry + Info.plist + icon
- `Models/SnapRequestModels.swift` — contacts, session (2-hour reminder), drafts, history, Snapchat opening
- `Views/ContentView.swift` — Home (Start/Pause/Stop, Open Snapchat, history), Contacts, Messages, Limits
- `Tests/SnapRequestAssistantTests.swift` — username validation, adult-confirmation gate, drafts, 2-hour interval, no-auto-send-on-add
- `scripts/package-unsigned-ipa.sh` — XcodeGen + unsigned device build + IPA packaging
- `.github/workflows/build.yml` — tests + unsigned IPA, manual run only
