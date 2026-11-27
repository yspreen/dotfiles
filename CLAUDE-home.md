@~/dotfiles/secrets/personal.md
The folder for projects is ~/Documents/proj.
Each line of code you write is a risk. Keep it short. Each LOC has to advance your goal. All code becomes a maintainability liability later.
Don't use claude api skill its not needed for this task at all, that's a waste of time.
Shell is zsh. Unquoted `$VAR` does NOT word-split: use arrays or `${=VAR}`, never `set -- $x` or `cmd $FLAGS`. Unmatched globs abort the whole command: quote them (`--include='*.ts'`, `'src/app/kanji/[k].tsx'`, `'(tabs)'`). Bash scripts: run with `bash -c`, don't source in zsh.
Google Play, all my apps: public contact email is always googleplaypublic@getmanten.app, no phone number. `gpd publish details patch` can't clear a phone: PUT the full edits.details object via the Play API.
When making an ios app in xcode or expo: add ITSAppUsesNonExemptEncryption to info plist
