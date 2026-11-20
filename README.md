# King Exit — JoiPlay Performance & Stability Patch

> **Disclaimer:** Unofficial community performance & compatibility patch. This repository contains no copyrighted game assets, archives, or full game scripts, and requires an existing copy of the base game.

Non-destructive RPG Maker VX Ace (`libmkxp19.so` / Ruby 1.9.2) optimization and stability patch for **King Exit** on **JoiPlay**, delivered via JoiPlay's standard [`postload.rb`](postload.rb) hook. Zero vanilla game files are modified.

## What `postload.rb` fixes

1. **Main-thread Oniguruma pre-warm:** Evaluates `/\eS\[(\d+),(.*?),(.*?)\]/i` once on the main thread at startup to pre-initialize Oniguruma's Unicode case-fold table safely.
2. **Eliminate menu/map exit stalls (`Sprite_Character#get_cross_character_name`):** Stops per-event probing for nonexistent `"-X"` diagonal character sprites and directly calls `@character.set_character_diagonal(false)`.
3. **Fast-path Langscore `_en` picture lookup (`Cache.load_bitmap`):** Uses the 30 verified `Graphics/Pictures/*_en` keys in `Langscore::KE_EN_PICTURES` instead of probing every bitmap load with rescue-driven exceptions.
4. **Prevent bitmap cache thrashing (`Cache_Delete`):** Raises `Cache`'s `@maximum` limit from `40` to `200`.
5. **Eliminate quadratic CSV parsing (`LSCSV.parse_col`):** Replaces quadratic `+=` string accumulation with in-place `<<`.
6. **Single-threaded Langscore execution:** Updates `Window_Base#convert_escape_characters`, `DataManager.load_normal_database`, and `Langscore.changeLanguage` to avoid Ruby 1.9.2 arm64 thread/Oniguruma race crashes.

## Usage

Make sure JoiPlay's **Enable Postload Scripts** option is enabled, then either copy `postload.rb` directly into your King Exit folder or run `apply.py`:

```bash
# Check status against /storage/emulated/0/Download/kingexit
python3 apply.py --check

# Install (or update) postload.rb
python3 apply.py --apply

# Revert (removes postload.rb or restores postload.rb.bak)
python3 apply.py --revert

# Custom game folder
python3 apply.py --apply --game-dir "/path/to/kingexit"
```
