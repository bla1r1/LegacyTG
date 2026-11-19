# LegacyTG — instructions for Claude

## Project in one sentence
Telegram client for iOS 6.0–12.5.7 on old hardware. Objective-C UI over TDLib (`libtdjson.dylib`), armv7 and arm64.

## Key files
- `src/Features/<Area>/` — screens by area: Chat, ChatList, Profile, Groups, Stories, Settings, Calls, Auth, Dev, …
- `src/Core/Client/TGClient*.m` — TDLib bridge and all request logic
- `src/Core/Client/TGClient.h` — umbrella: imports TGClientTypes.h, TGClientNotifications.h and one header per duty (TGClient+Messages.h, TGClient+Stickers.h, ...)
- `src/Core/Style/TGStyle.h` — all sizes and metrics (no magic numbers anywhere else)
- `TGTheme+Colours` — all colours
- `src/App/` — app entry: main, AppDelegate, URL routing, dev bench
- `src/Media/` — decoders (WebP, WebM sticker video)
- `scripts/i18n_match.py` — check a UI string or a file against the downloaded official Telegram pack (`--coverage` for the whole tree)
- `scripts/lint_tokens.sh` — fails on any hardcoded point size or colour in a screen
- `scripts/lint_fields.sh` — every TDLib field the app is handed and never reads has a line in `scripts/tdlib_fields.txt`: `todo <screen>` (official shows it, we drop it), `skip` with a reason, or `open` (not looked at). Fails on an unlisted field and on a listed one the app now reads; `--update` adds new fields as open. Drawing a todo field means deleting its line
- `src/Core/Support/TGLocalization.h` — `TGLocalized(@"English")` for UI copy; official Telegram language packs supply the translations, English is the fallback. Counts use `TGLocalizedPlural(@"%d chat", @"%d chats", count)` so the pack's one/few/many forms apply. UIKit chrome and alerts are localised centrally; message bodies are not.
- `scripts/split_source.py` — mechanical `classes` / `sections` split; dry run by default, `--apply` updates Makefiles, docs line references
- `make -j8 -f tests/Makefile test` — host test suite (currently 1950 client and 229 call tests); one object per source, so a change rebuilds only what it touches
- `scripts/linux_setup.sh` + `python3 scripts/linux_test.py [File.m …]` — host tests on Linux over a GNUstep build in `build/gnustep`; `scripts/linux_check.sh` type-checks changed files for armv7/arm64. Known Linux-only differences: `docs/status/checks.md` § Host tests on Linux
- `scripts/devrun.sh` — build, install, launch, log, screenshot on device; `--screenoff` / `--screenon` dark or wake the panel
- `scripts/bench.sh --swap --only chat --prof --udid <UDID>` — frame and CPU bench of the chat on the device in ~65 s; `--swap` puts only the new binary in (no SpringBoard restart), `FOCUS=name scripts/bench_report.py` splits a hot function
- `scripts/shots.sh OUT name=route,...` — open itglegacy:// routes and shoot each named step; `scripts/shotdiff.py BEFORE AFTER` compares two runs pixel by pixel below the status bar. Deep screens open with `itglegacy://screen/<gift|fileinfo/ID|forward|privacy/KEY|stickereditor|photos/USERID>` and `settings/sessions`; `itglegacy://focus` gives the first field the keyboard so `type/` can reach it
- `scripts/screen.sh` — `off` / `on` / `status` for the bench phone's backlight and lock screen. `itglegacy://stand/on` also remembers the choice in `TGStandScreenOff`, so the panel goes dark again after every launch; `stand/off` clears it
- `make -j8 DEV=1` — dev build (`-j` is safe: every IPA stages in its own folder): dev mode (three taps on Chats), fixture chats, bench, automation URLs, ghost mode. All under `#if TG_DEV`; `devrun.sh` builds this into `build/armv7/app-dev`. `scripts/check_release.sh` fails if any of it reaches a build without the flag
- `scripts/setup.sh` — fresh Mac to working checkout: Homebrew tools, TDLib, dependencies, host tests, emulator
- `scripts/release.sh` — publish the Info.plist version: build_all, emulator smoke, deb, then on a yes the tag, push, GitHub Release (notes `build: N` + the CHANGELOG section, read by the update bot) and the Cydia repo; `--dry-run` publishes nothing. The Telegram channel post is the user's, from `build/ipa/telegram-post.txt`
- `scripts/emu.sh` — iPhone 4 / iOS 6.1.3 emulator in `~/lt-emu`: `setup` once, then `test` builds ipa-armv7, installs, opens LegacyTG, prints AUTH STATE / connection lines; shots and syslog in `~/lt-emu/out`. armv7 and iOS 6 only, never a device substitute; never kill a running session (`prepare` recovers a dirty device)
- `scripts/build_ffmpeg.sh` — FFmpeg for the Vintage software video player, into `build/armv7/ffmpeg`
- `scripts/build_tlottie.sh` — tlottie (official Lottie renderer, Rust) as static libraries for armv7, arm64 and the host tests; needs nightly Rust with rust-src. `make` runs it when `third_party/tlottie` changes

## Architecture rules
- UIKit stays in Objective-C. No C++ in `.h` files consumed by ViewControllers.
- Views never import `TGClient.h`. They ask the domain stores in `src/Core`
  (`TGStickerStore`, `TGMediaStore`); a store's header is the list of what
  the view may ask.
- Theme colours come from `TGTheme+Colours`. The exception is
  `TGStylePalette.h`: roles that never change with the theme (link,
  code-block) and the decorative icon-tile hues. They are declared once,
  in `TGStyle.m`, and stay out of the theme on purpose.
- Heavy processing (TDLib events, layout, audio) moves to C/C++. `.mm` files are thin adapters.
- No `NSNumber`/`NSDictionary` allocation inside TDLib update loops or cell layout.
- TDLib receive loop never calls `dispatch_async(main_queue)` per raw event — batch and coalesce.
- Internal cache ceiling on 32-bit: 16 MB. LRU eviction only.
- No mastodons: a source file over 1800 lines is split by responsibility. The
  main type stays in its feature folder; its parts go to a thematic subfolder
  (`Chat/Actions`, `Chat/Composer`, `Core/Client/Chats`, …). `scripts/lint_size.sh`
  fails on any file over the limit; there is no baseline.

## Matching the official client
- A new screen, row or action is built where official Telegram has it, so it is never moved twice: the same entry point (which screen, which row, which bar button or context menu), the same presentation (push, modal sheet, context menu, action sheet), the same section and row order, the same navigation bar buttons, the same confirmation alert. Read the official source for that screen before writing ours.
- Text uses the official English from the language pack, word for word, so it translates: `scripts/i18n_match.py "text"` before inventing wording. Counts go through `TGLocalizedPlural`; no sentences glued from pieces.
- No "tools" screens or extra menus that collect actions official places elsewhere. A developer tool goes behind `TG_DEV`.
- Look, not layout, is ours: iOS 6 skeuomorphic chrome, `TGStyle` and `TGTheme` tokens, no live blur, masks or shadows on scrolling layers. Where an official effect cannot run on the A4, keep its position and drop the effect.
- Existing screens change only from a fix list the user has approved in the conversation, not on a general "make it like Telegram". Fix lists and audits are working notes and stay out of the repository; what changed is recorded in the area's file under `docs/status/`. The call screen keeps its current design on purpose.

## Testing — mandatory
- **Compile ≠ done.** A feature is done when it works on a real device, matches official Telegram behaviour, and has a passing regression test.
- Every fix ships with the test that **failed before the fix**.
- UI changes must be verified on at least one real device (4S or earlier for armv7, 5s+ for arm64).
- Device checks use `scripts/devrun.sh`. Log lines from TDLib (`updateNewMessage`, `updateFile`, `updateConnectionState`) are the ground truth.
- Components that can't be host-tested (UIKit lifecycle) → note the reason next to the checklist zone, fall back to devrun. Never just skip.

## Writing style — for docs and comments
- Write like a developer, not a product manager. No "comprehensive", "robust", "seamlessly", "cutting-edge", "leverage".
- No bullet-point soups for things that fit in a sentence.
- No "Executive Summary". No meta-sections explaining what the document is about.
- Numbers over vague words: "≤ 1 s", "16 MB", "12 ms" — not "quickly", "lightweight", "extensive".
- Comments explain *why*, not *what* the code does.

## Commit style
`fix(chat): …` / `feat(capabilities): …` — zone first. Bug IDs (`B1`–`Bn`) in the body when a bug closes. No bare "fix" or "some fixes".

## Device tiers (capability gating)
| Tier | Devices |
|---|---|
| Vintage | iPhone 3GS/4, iPod touch 4 — 256–512 MB, armv7, ≤ iOS 7 |
| Legacy | iPhone 4S/5/5c, iPod touch 5 — armv7, ≤ iOS 10 |
| Modern | iPhone 5s/6/6+, iPod touch 6 — first 64-bit, ≤ iOS 12.5 |
| Full | iPhone 6s+ — 2 GB+ |

Features gate by tier, not by iOS version. `Settings > This device` explains every missing button.
