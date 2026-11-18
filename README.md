# LegacyTG

Read this in other languages: [Русский](README_RU.md)

Telegram client for iOS 6.0–12.5.7 on old hardware: an Objective-C UIKit
interface over [TDLib](https://github.com/tdlib/td). The armv7 build loads
TDLib at runtime as `libtdjson.dylib`; the arm64 build links it in.

Text comes from the official Telegram language packs, which TDLib downloads,
and English is the fallback. Colours come from official Telegram theme files
(`.tgios-theme`, `.attheme`), light or dark; Night Blue is built in.

## Supported devices

Features are switched on by device tier, not by iOS version. Settings > This
Device explains every missing button.

| Tier | Devices |
|---|---|
| Vintage | iPhone 3GS/4, iPod touch 4: 256–512 MB, armv7, iOS ≤ 7 |
| Legacy | iPhone 4S/5/5c, iPod touch 5: armv7, iOS ≤ 10 |
| Modern | iPhone 5s/6/6 Plus, iPod touch 6: first 64-bit, iOS ≤ 12.5 |
| Full | iPhone 6s and later: 2 GB+ |

iPads install the app and run the portrait iPhone layout.

From 1.3 there is one download. `LegacyTG.ipa` (38 MB) carries the
armv7 and arm64 app, so the same file installs on every device from iOS 6.0
to 12.5.7. On a jailbroken device, add `https://bla1r1.github.io/LegacyTG` as
a Cydia source and install LegacyTG from it; the package holds the same build.
Every release lists the file's SHA-256.

## Setup

Register an app at https://my.telegram.org → API development tools, then:

```bash
cp vendor/include/tg_config.h.example vendor/include/tg_config.h
```

and fill in `TG_API_ID` and `TG_API_HASH`. The file is git-ignored.

## Building

Requirements: Xcode with the iOS SDK, and

```bash
brew install cmake gperf ccache ldid llvm
```

```bash
git clone --recursive https://github.com/bla1r1/iTgLegacy.git
cd iTgLegacy
scripts/setup.sh
```

`setup.sh` installs the missing Homebrew tools (without upgrading anything
installed), fetches TDLib, checks the git-ignored inputs below, builds the
dependencies with `build_all.sh --deps`, runs the host tests and, on Apple
Silicon, builds the iPhone 4 / iOS 6.1.3 emulator into `~/lt-emu` (`--no-emu`
skips it). The emulator needs 17 more Homebrew packages (qemu's and
libimobiledevice's build dependencies, the same no-upgrade rule), Rust through
rustup when `cargo` is missing, and Apple's 940 MB iOS 6.1.3 IPSW. A cold run
takes about an hour; a rerun skips what is done.
`scripts/build_all.sh` then builds the release IPAs.

`build_all.sh` goes from an empty `build/` to the release IPAs in
`build/ipa/` with a `SHA256SUMS` file (`LegacyTG.ipa` is the one published;
the per-architecture ones are for testing a slice): SDK, OpenSSL, libvpx, FFmpeg, TDLib
twice, the release check, then `make ipa`. A cold run takes 30–60 min; each
step is skipped when its output exists. `scripts/build_all.sh --deps` stops
after the dependencies.

The prebuilt `vendor/libs/libcrypto-universal.a`, `libssl-universal.a`,
`WebP.framework` and `third_party/opus/lib/libopus.a` are git-ignored and
have to come from an earlier checkout.

### After the dependencies

| Command | What it does |
|---|---|
| `make -j8 ipa` | All three packages |
| `make -j8 ipa-armv7` | 32-bit IPA |
| `make -j8 ipa-arm64` | 64-bit IPA |
| `make -j8 DEV=1` | Dev build: dev menu, fixture chats, bench, automation URLs; never in a release |
| `make clean` | Remove `build/armv7`, `build/arm64` and `build/ipa`, the per-architecture dependencies with them; run `build_all.sh` again after it |
| `make -j8 -f tests/Makefile test` | Host test suite |
| `scripts/emu.sh test` | armv7 IPA into the iPhone 4 / iOS 6.1.3 emulator: install, open, screenshots and syslog in `~/lt-emu/out`, auth and connection lines printed (~7 min). Vintage tier only; not a substitute for a device |
| `scripts/devrun.sh` | Build, install, launch, log and screenshot on a device over SSH |
| `scripts/check_release.sh` | Fails if anything behind `TG_DEV` reached a release build, on placeholder API keys, missing keychain entitlements or a plain API hash in a slice |
| `scripts/release.sh` | The version in `Info.plist`, from build to published: checks, IPAs, emulator smoke, deb, then (after a question) tag, push, GitHub Release with the CHANGELOG section, Cydia repo. `--dry-run` stops before publishing. The channel post text lands in `build/ipa/telegram-post.txt` |

## Repository layout

```
iTgLegacy/
├── Makefile
├── src/
│   ├── App/          # main, AppDelegate, URL routing, dev bench
│   ├── Features/     # screens by area
│   │   ├── Auth/  BotsPayments/  Business/  Calls/  Channels/
│   │   ├── Chat/         # Actions/ Composer/ Core/ Rendering/ Search/ Selection/ Views/
│   │   ├── ChatList/  Contacts/  Groups/  Media/  Profile/
│   │   ├── Settings/  Stories/
│   │   └── Dev/          # dev menu and harnesses, TG_DEV only
│   ├── Core/
│   │   ├── Client/       # TGClient, the TDLib bridge: Account/ Audit/ Chats/ Features/ Messages/ Stories/
│   │   ├── Model/        # message flattening, cards, message text
│   │   ├── Stores/       # caches, options, stickers, media, custom emoji
│   │   ├── Style/        # TGStyle metrics, TGTheme colours, theme files, text drawing
│   │   ├── Platform/     # device tiers, capabilities, perf, passcode
│   │   └── Support/      # JSON, update batching, localisation, QR, dates
│   ├── UI/           # shared Controllers/ Controls/ Format/ Overlays/
│   ├── Views/Icons/  # procedural icons and SVG paths
│   ├── Media/        # WebP and WebM sticker decoders
│   ├── Audio/        # voice notes, music player
│   ├── CallEngine/   # tgcalls: Crypto/ Media/ Network/ Signaling/
│   └── Compat/       # dyld TLV and iOS 6/7 shims
├── resources/        # Info.plist, images, fonts, sounds, built-in themes
├── third_party/      # libtgvoip, libvpx, opus, ogg, yyjson, tlottie, …
├── tdlib/td/         # TDLib (git submodule)
├── vendor/           # include/ (tg_config.h), libs/ (prebuilt, git-ignored)
├── tools/            # machofix and device helpers
├── scripts/          # build, device, lint and i18n scripts
├── tests/            # host tests
└── docs/             # status by area, roadmap, design spec
```

## Documentation

[docs/README.md](docs/README.md) lists everything. Start with
[docs/status/README.md](docs/status/README.md) for what works and
[docs/ROADMAP.md](docs/ROADMAP.md) for what comes next.

## Author & license

- **[bla1r1](https://github.com/bla1r1)** — author and maintainer
- **GPLv3** — see [LICENSE](LICENSE)

Icons come from [Material Design Icons](https://pictogrammers.com/library/mdi/) (Apache 2.0) and [Font Awesome Free](https://fontawesome.com) 6.5.1 (CC BY 4.0), kept as SVG paths in `src/Views/Icons/TGIconPaths.m`. Which icon comes from which set is listed in `scripts/icon_picks.txt`; `scripts/gen_icon_paths.py <@mdi/js dir> <@fortawesome/fontawesome-free dir>` regenerates the file.

The project started from an early prototype by [@igkuzm](https://github.com/igkuzm) and was later rewritten from scratch: TDLib instead of `libtg`, a new UIKit architecture, the media pipeline and E2EE calls.

> This software is for legacy hardware preservation and educational use. Use at your own risk.
