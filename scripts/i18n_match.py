#!/usr/bin/env python3
"""Check UI strings against the official Telegram language pack.

The official pack is keyed by its English values. A string that matches one
exactly is translated by TGLocalized; one that differs only in case is caught
by the folded lookup. Anything else needs a different official wording, a
removed description, or an app-specific translation.

Usage:
    scripts/i18n_match.py "Slow Mode"
    scripts/i18n_match.py --file src/Features/Settings/Pages/TGSettingsPagesCore.m
    scripts/i18n_match.py --coverage
    scripts/i18n_match.py --check

`--coverage` splits the missing strings into technical fragments, strings
listed in docs/i18n/allowed-english.md, and real leftovers. `--check` exits
non-zero when a real leftover exists, so the allowed list stays exhaustive.

The lookup JSON is an English-value -> translated-value map produced from a
downloaded pack (see TGClient loadAppLanguagePack:). Pass it with --lookup or
set I18N_LOOKUP.
"""
import argparse
import json
import os
import pathlib
import re
import sys

LIT = re.compile(r'@"((?:[^"\\]|\\.)*)"')
CONTEXT = re.compile(
    r'(title|text|placeholder|message|subtitle|header|footer|label|caption|'
    r'toast|status|button|action|confirm|alert|row|section|menu|empty|hint|'
    r'prompt)', re.I)
SKIP_LINE = re.compile(
    r'NSLog|TGLocalized|#import|@selector|@"@type"|@"@extra"|TGPerf|assert|'
    r'NSAssert', re.I)
SKIP_STRING = re.compile(
    r'^(%[\d$@\.\-+lhd]*[a-zA-Z@]?|[-+]?[\d.,:/\s%()]+|'
    r'[a-z0-9_.-]+://|@?[\w./-]+\.'
    r'(png|jpg|jpeg|gif|mp3|m4a|ttf|plist|json|tgs|webm|caf|zip)$|'
    r'[A-Za-z]+_[A-Za-z_]+|[a-z]+[A-Z][A-Za-z]*|[A-Za-z]+\.[a-z]+)$')


def decode_literal(text):
    """Apply the ObjC escapes the compiler would apply to a @"" literal."""
    return (text.replace("\\n", "\n").replace("\\t", "\t")
            .replace('\\"', '"').replace("\\'", "'").replace("\\\\", "\\"))


def fold(text):
    text = text.strip().lower()
    for a, b in (("\u2019", "'"), ("\u2018", "'"), ("\u201c", '"'),
                 ("\u201d", '"'), ("\u2013", "-"), ("\u2014", "-"),
                 ("\u2026", "...")):
        text = text.replace(a, b)
    return " ".join(text.split())


def load(path):
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    folded = {}
    ambiguous = set()
    for key, value in data.items():
        if not isinstance(value, str) or not value or "\n" in value or len(value) > 120:
            continue
        f = fold(key)
        if not f:
            continue
        if f in folded:
            if folded[f] != value:
                ambiguous.add(f)
            continue
        folded[f] = value
    for key in ambiguous:
        folded.pop(key, None)
    return data, folded


def is_display_literal(line, start):
    """A title/text literal, not an action key or a title comparator."""
    before = line[:start]
    if re.search(r'@"(action|icon|key|type|id|identifier|reuse)"\s*:\s*$', before):
        return False
    if re.search(r'(isEqualToString|hasPrefix|hasSuffix|action|selector)\s*:\s*$', before):
        return False
    return True


def strings_in(path):
    for number, line in enumerate(path.read_text(errors="ignore").splitlines(), 1):
        if SKIP_LINE.search(line) or not CONTEXT.search(line):
            continue
        for match in LIT.finditer(line):
            if not is_display_literal(line, match.start()):
                continue
            text = decode_literal(match.group(1))
            if len(text) < 3 or SKIP_STRING.search(text):
                continue
            if " " not in text and not text[:1].isupper():
                continue
            yield number, text


def strings_in_source(path):
    """Like strings_in, but skips comments and #if TG_DEV regions."""
    lines = path.read_text(errors="ignore").splitlines()
    # (is_dev_condition, skip_this_branch)
    dev_stack = []
    in_comment = False
    for number, line in enumerate(lines, 1):
        stripped = line.strip()
        if in_comment:
            if "*/" in stripped:
                in_comment = False
            continue
        if stripped.startswith("/*"):
            if "*/" not in stripped:
                in_comment = True
            continue
        if stripped.startswith("//") or stripped.startswith("*"):
            continue
        if re.match(r"#\s*if\s+!\s*TG_DEV\b", stripped):
            dev_stack.append((True, False))
            continue
        if (re.match(r"#\s*if\s+TG_DEV\b", stripped) or
                re.match(r"#\s*ifdef\s+TG_DEV\b", stripped)):
            dev_stack.append((True, True))
            continue
        if re.match(r"#\s*ifndef\s+TG_DEV\b", stripped):
            dev_stack.append((True, False))
            continue
        if re.match(r"#\s*if\b", stripped):
            parent = dev_stack[-1][1] if dev_stack else False
            dev_stack.append((False, parent))
            continue
        if re.match(r"#\s*else\b", stripped):
            if dev_stack:
                is_dev, skip = dev_stack[-1]
                dev_stack[-1] = (is_dev, (not skip) if is_dev else skip)
            continue
        if re.match(r"#\s*endif\b", stripped):
            if dev_stack:
                dev_stack.pop()
            continue
        if any(skip for _, skip in dev_stack):
            continue
        if SKIP_LINE.search(line) or not CONTEXT.search(line):
            continue
        for match in LIT.finditer(line):
            if not is_display_literal(line, match.start()):
                continue
            text = decode_literal(match.group(1))
            if len(text) < 3 or SKIP_STRING.search(text):
                continue
            if " " not in text and not text[:1].isupper():
                continue
            yield number, text


REVIEWED_NO_EQUIVALENT = {
    "Topic": "an individual topic name; the pack has New/Edit/Delete Topic but no noun",
    "Read Receipts": "the pack has Read and Receipt separately, no combined setting",
    "Streams and Data": "the pack has Data and Data and Storage, not this section",
    "Author": "the pack has Add author and Author Hidden, no plain row label",
    "Volume": "only sentences about volume; no control label",
    "Web Login Token": "app-specific auth flow; no pack key",
    "RTMP URL": "live-stream setup; the pack has Stream Key, not RTMP URL",
    "Business Connection": "bot console term; no pack key",
    "Mark Myself Speaking": "group-call control; no pack key",
    "Local Note": "app-specific note; the pack's Note means a musical tone",
    "Owner After Leaving": "group setting; no pack key",
    "Sticker Outline": "sticker-sheet tab; no pack key",
    "No custom emoji packs": "empty state; the pack has Custom Emoji, not this sentence",
    "Now Playing": "media player label; no pack key",
    "Live Story": "app-specific live stream; the pack has Live Stream",
    "Inactive Groups": "privacy switch; no pack key",
    "every device": "capability detail; the pack has Devices, not this phrase",
    "1 Star": "gift card count; the pack's Star is a different multi-line value",
    "Rich message": "AI compose label; no pack key",
    "That message is gone": "error text; no pack key",
    "You will stop receiving messages from this %@.": "needs the chat name; no pack template",
    "Paying with Stars is not available in this app yet.": "app-specific payment gate",

    "Light": "QR torch control; the pack has light appearance and highlights, not this toggle",
    "Participant": "singular sender fallback; the pack has the plural Participants",
    "Hand": "group-call hand control; no pack key",
    "Mark Myself Speaking": "group-call control; no pack key",
    "Active For": "story composer duration label; no pack key",
    "Cancelled": "file-transfer state; the pack's Cancel is an action, not a state",
    "Chat -": "placeholder prefix on user content, not a label",
    "Community with %@ chats": "runtime count line; mapped through TGLocalizedFormat",
    "%@ created the channel \"%@\"": "pack has only the group template; this branch is a channel",
    "%@ changed the channel name to \"%@\"": "pack has only the group template; this branch is a channel",
    "%@ changed the channel photo": "pack has only the group template; this branch is a channel",
    "%@ removed the channel photo": "no pack template for removing a channel photo",
    "%@ added %@": "pack has add-member wording but no actor template with this shape",
    "%@ upgraded the group to a supergroup": "pack has Upgrade to Supergroup, not this actor sentence",
    "%@ joined the group from a community": "no pack template for joining from a community",
    "%@ created a topic": "pack has New Topic, not this actor sentence",
    "%@ renamed the topic to \"%@\"": "pack has Edit Topic, not this actor sentence",
    "%@ changed the topic icon": "pack has Select Topic Icon, not this actor sentence",
    "%@ edited the topic": "pack has Edit Topic, not this actor sentence",
    "%@ closed the topic": "pack has Topic closed, not this actor sentence",
    "%@ reopened the topic": "pack has Reopen Topic, not this actor sentence",
}


DEV_FILE_HINTS = (
    "TGDev", "TGGameScores", "TGSettingsPagesPayments", "TGStarsGifts",
    "TGAffiliatePrograms", "TGSponsoredMessages", "TGNetworkViewController",
    "TGSupportInfoViewController", "TGTextStylesViewController",
)


def is_dev(path):
    return ("/Dev/" in str(path) or path.name.startswith("TGDev") or
            any(hint in path.name for hint in DEV_FILE_HINTS) or
            str(path).endswith("AppDelegate+URL.m"))


def is_noise(text):
    """Format fragments, identifiers and field labels that are not copy."""
    if not re.search(r"[A-Za-z]", text):
        return True
    if re.fullmatch(r"[%A-Za-z0-9_@.·—–\-+()/ ]+", text) and "%" in text and len(text) < 24:
        return True
    # CamelCase / underscore identifiers, not ordinary one-word UI labels.
    if re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*[A-Z_][A-Za-z0-9_]*", text):
        return True
    if re.search(r"\b(ID|Id|id|URL|Token|Count|Limit|Offset|Latitude|Longitude|"
                 r"Payload|Hash|Key|Nonce|Price|Mille|Referrer|Datacenter|Score|Force)\b",
                 text):
        return True
    return False


def no_equivalent_reason(text, candidates, where=""):
    if text in REVIEWED_NO_EQUIVALENT:
        return REVIEWED_NO_EQUIVALENT[text]
    nearest = f" nearest pack string is {candidates[0]!r};" if candidates else ""
    if "TGServiceMessageText.m" in where:
        return ("runtime service message; no exact/folded match." + nearest +
                " the pack has the bare verb/feature or only the group form, "
                "not this actor/channel/placeholder shape")
    if "TGPinnedLine.m" in where:
        return ("pinned-line fragment; no exact/folded match." + nearest +
                " the pack has full pinned-message templates, not this fragment")
    if "TGMessageCard.m" in where:
        return ("runtime message-card line; no exact/folded match." + nearest +
                " the pack has the feature label, not this composed sentence")
    folded_text = fold(text)
    words = set(re.findall(r"[a-z]+", folded_text))
    if "%" in text or text.strip() != text or "·" in text:
        return ("runtime format/template; no exact/folded match." + nearest +
                " the pack has no key with this exact placeholder set")
    if any(len(fold(c)) < len(folded_text) for c in candidates) and " " in text:
        return ("candidate is a shorter generic word; it drops the qualifier. "
                + nearest)
    if candidates and all(len(fold(c)) > len(folded_text) for c in candidates):
        return "candidate belongs to a different sentence/context." + nearest
    if candidates:
        cand_words = set(re.findall(r"[a-z]+", fold(candidates[0])))
        if words and len(words & cand_words) <= 1:
            return "candidate shares one word but is a different phrase." + nearest
    return "candidate is not the same phrase/meaning." + nearest


ALLOWED_DOC = pathlib.Path("docs/i18n/allowed-english.md")
BACKTICK = re.compile(r"`([^`\n]+)`")


def allowed_english(path=ALLOWED_DOC):
    """Strings the project keeps in English, taken from the allowed doc.

    Every table row that names a string in backticks counts. The doc is the
    single source of truth; the checker only reads it.
    """
    if not path.exists():
        return set()
    kept = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        if set(line.replace("|", "").strip()) <= set("-: "):
            continue
        for match in BACKTICK.finditer(line):
            kept.add(decode_literal(match.group(1)))
    return kept


def is_technical(text):
    """Not copy: a format fragment, a unit, a class/notification name, a sample."""
    if is_noise(text):
        return True
    stripped = text.strip()
    # Pure separators, bullets and placeholder punctuation.
    if not re.search(r"[A-Za-z]{2,}", stripped):
        return True
    # printf / appendFormat fragments: every word is a placeholder or separator.
    words = [w for w in re.split(r"\s+", stripped) if w]
    if words and all(re.fullmatch(r"[%@\d\W]*", w) or
                     re.fullmatch(
                         r"[\W_]*%[-+ #0-9.*]*(?:hh|h|ll|l|j|z|t|L)?[a-zA-Z@][\W_]*",
                         w)
                     for w in words):
        return True
    # Objective-C class names and notification constants.
    if re.fullmatch(r"(NS|UI|TG|TL|CA|AV)[A-Za-z0-9]+", stripped):
        return True
    # Date/time sample formats.
    if re.fullmatch(r"[YMDhms:\-/ .]+", stripped):
        return True
    # Type sizes and other bare units.
    if re.fullmatch(r"[\d.]+ ?(pt|px|%)", stripped):
        return True
    # A separator fragment glued to a word at runtime.
    if stripped[:1] in {"\u00b7", "|", "\u2022"} or stripped[-1:] in {"\u00b7", "|"}:
        return True
    return False


def candidate_keys(text, exact, limit=5):
    folded_text = fold(text)
    wanted = {w for w in re.findall(r"[a-z]+", folded_text) if len(w) >= 3}
    scored = []
    for key in exact:
        folded_key = fold(key)
        have = {w for w in re.findall(r"[a-z]+", folded_key) if len(w) >= 3}
        if not have:
            continue
        common = wanted & have
        substring = (len(folded_text) >= 4 and
                     (folded_text in folded_key or folded_key in folded_text))
        if not common and not substring:
            continue
        score = 0.0
        if substring:
            score += 3.0
        if wanted and wanted <= have:
            score += 2.0
        if common:
            score += len(common) / max(len(wanted), len(have))
        if score >= 1.5:
            scored.append((score, len(key), key))
    scored.sort(key=lambda item: (-item[0], item[1], item[2]))
    return [key for _, _, key in scored[:limit]]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("text", nargs="?")
    parser.add_argument("--file", type=pathlib.Path)
    parser.add_argument("--coverage", action="store_true")
    parser.add_argument("--check", action="store_true",
                        help="exit 1 if an unmapped non-dev UI string is left")
    parser.add_argument("--inventory", action="store_true")
    parser.add_argument("--lookup", default=os.environ.get("I18N_LOOKUP",
                                                          "/tmp/loc-ru2.json"))
    parser.add_argument("--limit", type=int, default=12)
    args = parser.parse_args()

    exact, folded = load(args.lookup)

    if args.text:
        key = args.text
        if key in exact:
            print(f"exact      {key!r} -> {exact[key]!r}")
        else:
            print(f"exact      no")
        f = fold(key)
        if f in folded:
            print(f"folded     {key!r} -> {folded[f]!r}")
        else:
            print(f"folded     no")
        words = set(re.findall(r"[a-z]+", f))
        hits = [k for k in exact if words and words <= set(re.findall(r"[a-z]+", k.lower()))]
        hits.sort(key=lambda k: (len(k), k))
        print("candidates:")
        for k in hits[:args.limit]:
            print(f"  {k!r} -> {exact[k]!r}")
        return

    if args.file:
        missing = []
        for number, text in strings_in(args.file):
            if text in exact or fold(text) in folded:
                continue
            missing.append((number, text))
        for number, text in missing:
            print(f"{args.file}:{number}: {text}")
        print(f"# {len(missing)} missing", file=sys.stderr)
        return

    if args.coverage or args.check:
        allowed = allowed_english()
        total = found = only_fold = 0
        missing = {}
        for path in sorted(pathlib.Path("src").rglob("*")):
            if path.suffix not in {".m", ".mm"} or is_dev(path):
                continue
            for number, text in strings_in_source(path):
                total += 1
                if text in exact:
                    found += 1
                elif fold(text) in folded:
                    found += 1
                    only_fold += 1
                else:
                    missing.setdefault(text, []).append(f"{path}:{number}")
        technical = {t: p for t, p in missing.items() if is_technical(t)}
        kept = {t: p for t, p in missing.items()
                if t not in technical and t in allowed}
        real = {t: p for t, p in missing.items()
                if t not in technical and t not in allowed}
        print(f"occurrences {total}")
        print(f"covered     {found} ({100.0 * found / max(total, 1):.1f}%)")
        print(f"  exact     {found - only_fold}")
        print(f"  folded    {only_fold}")
        print(f"missing     {total - found} ({len(missing)} unique)")
        print(f"  technical {len(technical)} unique")
        print(f"  allowed   {len(kept)} unique  (docs/i18n/allowed-english.md)")
        print(f"  real      {len(real)} unique")
        for text, places in sorted(real.items(), key=lambda kv: -len(kv[1]))[:args.limit]:
            print(f"  {len(places):3} {text}")
        if args.check and real:
            print("\nunmapped UI strings:", file=sys.stderr)
            for text, places in sorted(real.items(), key=lambda kv: -len(kv[1])):
                print(f"  {len(places):3} {text}  {places[0]}", file=sys.stderr)
            sys.exit(1)
        return

    if args.inventory:
        allowed = allowed_english()
        missing = {}
        for path in sorted(pathlib.Path("src").rglob("*")):
            if path.suffix not in {".m", ".mm"} or is_dev(path):
                continue
            if str(path).endswith("AppDelegate+URL.m"):
                continue
            for number, text in strings_in_source(path):
                if text in exact or fold(text) in folded:
                    continue
                missing.setdefault(text, []).append(f"{path}:{number}")
        noise = []
        kept = []
        needs = []
        none = []
        for text, places in missing.items():
            if is_technical(text):
                noise.append((text, places))
            elif text in allowed:
                kept.append((text, places))
            else:
                cands = candidate_keys(text, exact)
                if cands:
                    needs.append((text, places, cands))
                else:
                    none.append((text, places))
        print("# Remaining non-dev UI strings")
        print()
        print(f"- Missing occurrences: {sum(len(p) for p in missing.values())}")
        print(f"- Unique strings: {len(missing)}")
        print(f"- Kept in English (allowed-english.md): {len(kept)}")
        print(f"- Technical/format identifiers: {len(noise)}")
        print(f"- Unmapped: {len(needs) + len(none)}")
        print()
        print("## Kept in English")
        print()
        print("Reasons are in docs/i18n/allowed-english.md.")
        print()
        print("| n | String | Where |")
        print("|---:|---|---|")
        for text, places in sorted(kept, key=lambda item: -len(item[1])):
            text_md = text.replace("|", "\\|").replace("\n", "\\n")
            print(f"| {len(places)} | `{text_md}` | `{places[0]}` |")
        print()
        print("## Technical / format / identifier")
        print()
        print("| n | String | Where |")
        print("|---:|---|---|")
        for text, places in sorted(noise, key=lambda item: -len(item[1])):
            text_md = text.replace("|", "\\|").replace("\n", "\\n")
            print(f"| {len(places)} | `{text_md}` | `{places[0]}` |")
        print()
        print("## Unmapped")
        print()
        if not needs and not none:
            print("None. `scripts/i18n_match.py --check` passes.")
        else:
            print("| n | String | Where | candidates |")
            print("|---:|---|---|---|")
            for text, places, cands in sorted(needs, key=lambda item: -len(item[1])):
                joined = "<br>".join(f"{k!r} -> {exact[k]!r}" for k in cands)
                text_md = text.replace("|", "\\|").replace("\n", "\\n")
                print(f"| {len(places)} | `{text_md}` | `{places[0]}` | {joined} |")
            for text, places in sorted(none, key=lambda item: -len(item[1])):
                text_md = text.replace("|", "\\|").replace("\n", "\\n")
                print(f"| {len(places)} | `{text_md}` | `{places[0]}` | |")
        return

    parser.error("give a string, --file or --coverage")


if __name__ == "__main__":
    main()
