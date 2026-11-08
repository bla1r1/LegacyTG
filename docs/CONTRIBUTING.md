# Contributing to LegacyTG

Telegram client for iOS 6.0–12.5.7: TDLib (`libtdjson` at runtime), Objective-C UI.

## Done

Done = matches the official client, with a row in [status/checks.md](status/checks.md) and, where possible, a host test. Each check names the tap, the screen, the wait and the log line (`scripts/devrun.sh`). Forbidden: "works", "looks fine", "doesn't crash for me". Calls and read receipts need a second device or account.

## Tests

`make -j8 -f tests/Makefile test` compiles real `src/` against stubs. Every fix ships with the regression test that failed before it; a silent re-fix needs the check row that would have caught it. UIKit lifecycle: record why next to the check and use `devrun.sh`.

## Style

Colours from `TGTheme+Colours`, sizes from `src/Core/Style/TGStyle.h`; screens ask for a role, never a number. `scripts/lint_tokens.sh` fails on a hardcoded point size or colour. `UIAlertView`/`UIActionSheet` use only falls.

No mastodons: a source file over 1800 lines is split by responsibility. The main type stays in its feature folder; its parts go to a thematic subfolder (`Chat/Actions`, `Chat/Composer`, `Core/Client/Chats`, …). `scripts/lint_size.sh` fails on any file over the limit; there is no baseline.

`scripts/split_source.py` does the mechanical part. It is a dry run unless `--apply` is passed, and it updates both Makefiles and docs line references:

```sh
scripts/split_source.py plan src/Features/Business/TGBusinessViewController.m
scripts/split_source.py classes src/Features/Business/TGBusinessViewController.m --out src/Features/Business --apply
scripts/split_source.py sections src/Core/Client/TGClient+Account.m \
    --base TGClient+Account --out src/Core/Client/Account \
    --headers src/Core/Client/TGClient+Account.h --umbrella src/Core/Client/TGClient.h --apply
```

`classes` splits a file with several `@implementation` blocks. `sections` splits one implementation by `#pragma mark -`; pass `--map "account settings=Settings"` to name a section, otherwise it derives `Base+PascalCase(title)`. Unassigned header declarations go to a `<Base>Misc.h` so nothing is lost. Static helpers are copied into the sections that use them; non-static functions go to `<File>Support.m`.

## Bugs and commits

Every bug is a row in [status/bugs.md](status/bugs.md) until the closing fix names its regression test; long root causes are in git at `cf71bc9`. Commit as `fix(chat): …`, zone first, with `B1`–`Bn` in the body when one closes.

## PR

- [ ] host suite green
- [ ] `sh scripts/lint_tokens.sh` clean
- [ ] fix lands with its failing test
- [ ] every claim backed by a check row or a device log
- [ ] gated UI exercised on a Vintage/Legacy device
