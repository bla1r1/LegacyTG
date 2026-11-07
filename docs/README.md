# Documentation

The documentation is split between the plan, the state of each area, and the
working notes. [ROADMAP.md](ROADMAP.md) says which milestones landed and in
what order; [status/](status/) checks every feature against official Telegram
with a `file:line`; [gaps.md](gaps.md) is the user-facing list of what is still
missing. The remaining files are the design, testing and delivery notes those
three link into.

| Where | What is in it |
|---|---|
| [ROADMAP.md](ROADMAP.md) | Milestones M1–M19 closed, M20–M44 open, with what each needs and which status rows it closes |
| [gaps.md](gaps.md) | Observed gaps, what the user cannot do, the owning milestone and the observation |
| [status/README.md](status/README.md) | Per-area counts and the 15 most-hit gaps |
| [status/chat-list.md](status/chat-list.md) | List engine, rows, badges, folders, archive, stories strip and search |
| [status/chat.md](status/chat.md) | History, bubbles, composer, message actions, search, scheduling and bot controls |
| [status/message-types.md](status/message-types.md) | Every `MessageContent` type and the content features the parity audit names |
| [status/profile.md](status/profile.md) | User, group and channel profiles, media panes and editing |
| [status/groups.md](status/groups.md) | Members, permissions, invite links, topics, group calls and administration |
| [status/channels.md](status/channels.md) | Posting, admin surface, comments, views, signatures and statistics |
| [status/contacts.md](status/contacts.md) | The contact list, adding people and the call list that shares the tab |
| [status/calls.md](status/calls.md) | 1:1 audio, recent calls, group calls and video chats |
| [status/stories.md](status/stories.md) | Strip, viewer, posting, albums, interactions and live stories |
| [status/media.md](status/media.md) | Viewer, players, downloads, attachments and stickers |
| [status/settings.md](status/settings.md) | Every Settings page, the Appearance controls and the shared design tokens |
| [status/privacy-security.md](status/privacy-security.md) | Passcode, two-step, sessions, blocked users, visibility rules, storage and network |
| [status/notifications.md](status/notifications.md) | Scopes, exceptions, sounds, the Active list and push |
| [status/login-accounts.md](status/login-accounts.md) | Every auth step, account slots, sessions and websites |
| [status/bots-payments.md](status/bots-payments.md) | Bots, invoices, Stars, gifts, boosts and the wallet surfaces |
| [DESIGN_SPEC.md](DESIGN_SPEC.md) | The iOS 6 Reimagined design: UIKit chrome, what the app still draws, metrics and colour roles |
| [acceptance_checklist.md](acceptance_checklist.md) | Device checks per feature: what to tap, what to see, how long to wait, what the log says |
| [bug_registry.md](bug_registry.md) | The open bug queue, B1 onwards, with symptom, where to look and status |
| [feature_backlog.md](feature_backlog.md) | TDLib functions the app never names, the coverage scripts and the Tier 0–3 split |
| [calls_notes.md](calls_notes.md) | Why phone↔phone calls are silent and phone↔desktop works, with the protocol versions |
| [calls_v9_spec.md](calls_v9_spec.md) | The tgcalls 9.0.0 wire protocol `TGCall.mm` has to speak, audio only |
| [C_CPP_MIGRATION_PLAN.md](C_CPP_MIGRATION_PLAN.md) | Target hardware, the Objective-C/C++ split and the migration phases |
| [CONTRIBUTING.md](CONTRIBUTING.md) | What "done" means, the failing-test rule and the zone checklist process |
| [howto_push_cert.md](howto_push_cert.md) | Creating the APNs key, certificate and provisioning profile |
| [AUTHORS](AUTHORS) | Copyright holders |
