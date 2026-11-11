# WoWTranslate / 魔兽翻译

<p align="center">
  <strong>Real-time chat translation for World of Warcraft 1.12</strong><br>
  Break the language barrier on multilingual WoW 1.12 servers
</p>

<p align="center">
  <img src="https://img.shields.io/badge/WoW-1.12-blue" alt="WoW 1.12">
  <img src="https://img.shields.io/badge/version-2.1-green" alt="Version 2.1">
</p>

This is a fork of [sanjaygbhat/wow-translate](https://github.com/sanjaygbhat/wow-translate) (original authors: belthazor and the WoWTranslate team). It keeps the original feature set and adds a persistent item-name store, a ranked self-pruning cache, a user dictionary, a read-only shared dictionary layer and a few filters that stop useless text from being sent to the translation service. See [What changed](#what-changed-compared-to-the-original) for the full comparison.

Fully compatible with [WoW-CNLocale](https://github.com/paokkerkir/WoW-CNLocale).

---

## Client mods

| Mod | Role | Notes |
|---|---|---|
| `WoWTranslate.dll` (pre-built, attached to each [GitHub Release](../../releases/latest)) | **Required** | Performs the HTTP translation request off the game thread and exposes it to Lua through the `UnitXP("WoWTranslate", ...)` entry point. Must be loaded by a DLL launcher such as VanillaFixes. |

No other client mod (SuperWoW, Nampower, ClassicAPI, VanillaHelpers) is required or called by the addon code.

**Compatibility note:** `WoWTranslate.dll` hooks the same `UnitXP` Lua entry point that UnitXP SP3 extends. If translations stop while both are loaded, change their order in `dlls.txt`.

---

## Features

### Original features (kept)

| Feature | Description |
|---------|-------------|
| 🌍 **Multi-language** | Chinese, Japanese, Korean, Russian → English (and vice-versa) |
| 📚 **WoW glossary** | 850+ gaming terms translated correctly ("老克" → "Kel'Thuzad", not "Old gram") |
| 💬 **Outgoing translation** | Type in English, send in Chinese (or other languages) |
| 🔗 **Hyperlink safe** | Player names, items and quests stay clickable and are translated |
| 📺 **Channel filtering** | Choose exactly which channels get translated |
| 💤 **AFK auto-pause** | Pause translation while you are AFK |
| 🗺️ **Minimap button** | One-click access to settings |

### Added in this fork

| Feature | Description |
|---------|-------------|
| 🗃️ **Persistent item names** | Item names are remembered across sessions, so item links resolve instantly even when the `WDB` folder is deleted before every launch. |
| 📈 **Ranked cache with self-pruning** | Every cache entry tracks how often and how recently it was used. Entries that are unlikely to come back are removed at login. |
| 📖 **User dictionary** | Your own `source = translation` pairs. Checked before everything else, never pruned, never cleared by `/wt clearcache`. |
| 🔁 **Reverse pairs for your own messages** | When you send a translated message, the pair is cached in reverse. When the server echoes your line back, you see exactly what you typed, with no translation request. |
| 🎭 **Kaomoji skip** | Messages that are nothing but kaomoji are no longer sent for translation (65 non-ASCII codes taken from the TwitchEmotes+ kaomoji list). |
| 🈂️ **Stricter Japanese detection** | Full-width CJK punctuation no longer counts as Japanese text, so punctuation-only messages are not sent to the translation service. |
| 🐞 **Pipe-safe results** | A translation that contains a `\|` character (for example `WTS \| 100g`) is delivered intact. Before, it was cut at the pipe and reported as a failure. |
| ✏️ **Fix a translation without typing Chinese** | `/wt recent` lists the last translated lines and `/wt fix <n> <text>` saves your own wording to the user dictionary. |
| 🔎 **Tracing** | `/wt debug` also logs which source answered a lookup, cache pruning, skipped emote-only text, reverse pairs, item names from the store or the bundled table, item names found in plain text, and lines posted locally by the glossary. `/wt log` shows the latest entries. |
| 📘 **Turtle WoW shorthand in the glossary** | 58 entries from the community translation table: build tags (ZST, QST, 科技LR, 开怪LR, 跳怪LR, 电萨, 鸟D, 猫D...), summon and crafting callouts, Turtle WoW dungeons and raids (FMH, WHC, DMR, HFQ, SWV, LKH, TMH, Kara40, HLMM...), 3Q and hhh. |
| 🧩 **Cleaner glossary replacements** | Replacements that touch each other across Chinese text are separated by a space (`来个MS` gave `NeedPriest`, now `Need Priest`). |
| ⚡ **Faster glossary lookup** | The sorted key list is built once instead of for every partial lookup (about 5 to 8 times faster in the test harness). |
| 📦 **Item names without the server** | A bundled table of 6,111 item names (item ID to English name) is the last fallback for item links, after the client and the names stored from earlier sessions. On an English client a link resolves at once, with no server query and no wait, even right after the `WDB` folder was deleted. |
| 🧾 **Item names typed without a link** | Chinese item names of four or more characters are replaced by their English names (5,233 names). Names of two or three characters, and names that map to more than one English name, are left out on purpose. A glossary entry wins when a name is also a glossary key. |
| ✅ **Local posting of fully glossary-translated lines** | A line whose Chinese is completely covered by the glossary (and item names) is posted directly. Before, it was still sent to the translation service, because English text always counted as "something to translate". |
| 🌐 **Shared dictionary layer** | An optional read-only data file, `WoWTranslate_SharedDict.lua`, checked after the cache. It ships empty and is maintained by hand. |

---

## How a message is resolved

```
user dictionary → cache → shared dictionary → glossary → translation service
   (yours)       (ranked)     (read-only)        (instant)      (last resort)
```

Anything answered before the last step costs no characters from the translation service.

---

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `/wt show` / `/wt hide` | Open / close the configuration panel |
| `/wt on` / `/wt off` | Enable / disable incoming translation |
| `/wt outgoing [on\|off]` | Toggle outgoing translation |
| `/wt outchannel [type]` | Show / toggle outgoing channel settings |
| `/wt prefix <text>` | Set the outgoing message prefix |
| `/wt dict` | Show dictionary and cache sizes |
| `/wt recent` | List the last translated lines |
| `/wt fix [n] <your translation>` | Replace the translation of recent line `n` (default 1) with your own text, saved to the user dictionary |
| `/wt dict add <text> = <translation>` | Add or replace a user dictionary entry |
| `/wt dict del <text>` | Remove a user dictionary entry |
| `/wt clearcache` | Clear the translation cache and the item-name store (the user dictionary is kept) |
| `/wt reset` | Recover if translations stop after alt-tab |
| `/wt debug` | Toggle debug tracing |
| `/wt log` | Show the latest debug log entries |
| `/wt clearlog` | Clear the debug log |

### User dictionary

```
/wt dict add 求带 = need a carry
/wt dict del 求带
```

The 1.12 chat box cannot input Chinese, so the easiest way to correct a translation is to fix a recent line instead of typing the original:

```
/wt recent
/wt fix 2 need a carry for Scholomance
```

`/wt dict add` is for when you can paste the original text. The text before ` = ` must match the incoming message exactly. Dictionary entries win over every other source, which makes them the way to fix a translation you do not like.

### Cache behaviour

The cache is pruned once per login, never during play:

| Rule | Value |
|------|-------|
| Entries seen once and unused for | 45 days → removed |
| Cache size limit | 8,000 entries; pruned down to 6,000, lowest "chance of coming back" first |
| Entries seen at least | 5 times (and used within 90 days) are protected |

Ranking score is `hits / (1 + ageInDays / 7)`. All thresholds are constants at the top of `WoWTranslate_Cache.lua`. Existing caches from older versions are upgraded automatically.

---

## What changed compared to the original

| Area | Original (1.5) | This fork (2.1) |
|------|----------------|-----------------|
| Item names in links | Read only from the game's `WDB` cache. After the folder is deleted, every item link is requested from the server and the chat message is held for up to 3 seconds. | Names are stored per item ID and per client locale, so previously seen items resolve instantly. Cleared automatically if the client locale changes. |
| Translation cache | Exact-match strings, unbounded, never expires. | Entries carry hit count and last-used day; stale and low-value entries are pruned at login; frequent entries are protected. |
| Dictionary | Static glossary only. | Adds a user dictionary (`/wt dict`, `/wt fix`) checked first, and a read-only shared dictionary file checked after the cache. Both are checked before the glossary. |
| Your own messages | The echo of a message you sent in Chinese was translated back by the translation service. | The reverse pair is cached when you send, so the echo shows your original text without a request. |
| Japanese detection | Any full-width CJK punctuation counted as Japanese, so punctuation-only messages were sent for translation. Hangul jamo (ㅋㅋㅋ) were treated as Japanese. | Only real hiragana and katakana count as Japanese; rare CJK Extension A ideographs count as Chinese; Hangul jamo are detected as Korean. |
| Kaomoji-only messages | Detected as Japanese or Russian from their symbols and sent for translation. | Skipped. |
| Translations containing `\|` | Cut at the first pipe; the rest was treated as an error, so the message stayed untranslated and a "translation failing" warning appeared. Outgoing messages containing `\|` were sent untranslated. | The error is read after the last pipe, so the translation arrives intact. |
| Version shown in the panel | Fixed text (`v1.5`). | Read from the TOC. |
| Debugging | `/wt debug` logged the chat pipeline only. | Cache, item-name, prune and emote decisions are logged too. |
| Glossary coverage of Turtle WoW shorthand | 120 of 230 spellings in the community table. | 147 of 230; the rest are deliberately excluded or conflict (see Glossary notes). |
| Glossary partial lookup | Sorted all keys on every call, so results for equal-length keys depended on table order. | Sorted once and cached; ties are alphabetical, so results are stable. |
| Item names in links, `WDB` wiped | Needed a server query per item and held the message for up to 3 seconds. | The name comes from the client, the names stored earlier or the bundled table, whichever has it first, so there is no wait. |
| Item names typed as plain Chinese text | Sent to the translation service, which often renders them as ordinary words. | Replaced with the official English name before translation. |
| Lines fully covered by the glossary | Sent to the translation service anyway. | Posted locally. |
| `/wt clearcache` | Cleared the translation cache. | Also clears the item-name store; the user dictionary is kept. |

Saved variables added by this fork: `WoWTranslateDict` and `WoWTranslateItemNames`.

---

### Glossary notes

- Add entries to `WoWTranslate_Glossary.lua` (Chinese to English) or `WoWTranslate_OutGlossary.lua` (English to Chinese) as `WoWTranslateGlossary["key"] = "value"`.
- Longer keys win over shorter ones. Equal-length keys are ordered alphabetically, so adding an unrelated entry never changes which of two overlapping terms is chosen.
- ASCII keys of up to three characters only match whole words; Chinese keys match anywhere.
- Single characters, bare digits and generic words are left out on purpose, because partial matching would rewrite ordinary text (the `2` in `(3=2)`, the `力` in `能力`). Isolated numeric slang such as `88`, `110`, `666` and `999` is handled in `PreprocessIncoming`.
- Two entries of the community table were not taken over because they conflict with existing, more likely readings: `KBZ` stays Fury Warrior (the table lists it as Arms) and `RL` stays raid leader (the table lists it as Human).

### Item data

`WoWTranslate_ItemData.lua` is generated from AtlasLoot (Turtle WoW Edition) and its zhCN fork:

```
python qa/tools/gen_itemdata.py <English AtlasLoot dir> <zhCN AtlasLoot dir> Interface/AddOns/WoWTranslate/WoWTranslate_ItemData.lua
```

It holds `WoWTranslate_ItemEN` (item ID to English name) and `WoWTranslate_ItemZH` (Chinese name to English name). The English table is only used when the game client itself is English. The minimum name length for plain-text matching is `MIN_NAME_BYTES` at the top of `WoWTranslate_ItemNames.lua`.

## Testing

The `qa/` folder holds a regression suite that loads the real addon files into a small WoW 1.12 mock and runs them on a standard Lua interpreter (developed with Lua 5.4):

```
sh qa/run_all.sh Interface/AddOns/WoWTranslate [path/to/original/WoWTranslate] [lua]
```

With the second argument (a copy of the original addon) the A/B suites run against both versions: DLL result parsing, cache API compatibility, item names after a `WDB` wipe, language detection on a corpus, glossary lookups on about 4,500 generated lines (with the data held constant to isolate code changes), the item data, and an end-to-end incoming-chat simulation. `qa/REPORT.md` records the latest run. The mock does not replace testing inside the game client.

## Credits

- Original WoWTranslate: belthazor and the WoWTranslate team ([sanjaygbhat/wow-translate](https://github.com/sanjaygbhat/wow-translate)).
- Kaomoji codes used by the skip filter come from the TwitchEmotes+ kaomoji list (`Data/Kaomoji.lua`).
- DLL hooking uses [MinHook](https://github.com/TsudaKageyu/minhook).
- Item names: AtlasLoot (Turtle WoW Edition) authors and the AtlasLoot zhCN fork, whose data tables `WoWTranslate_ItemData.lua` is generated from.

## License

See [LICENSE](LICENSE).
