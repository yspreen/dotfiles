# Environment shared by every zsh invocation.
# Keep this file silent and free of prompt, alias, and completion setup.

typeset -U path PATH

_zshenv_prepend_path() {
  [[ -d "$1" ]] && path=("$1" $path)
}

_zshenv_append_path() {
  [[ -d "$1" ]] && path+=("$1")
}

_zshenv_prepend_path "/opt/homebrew/bin"
_zshenv_prepend_path "$HOME/perl5/bin"
_zshenv_prepend_path "/opt/homebrew/opt/ruby/bin"
_zshenv_prepend_path "/System/Volumes/Data/opt/homebrew/lib/ruby/gems/3.1.0/bin"
_zshenv_prepend_path "$HOME/.antigravity/antigravity/bin"
_zshenv_prepend_path "$HOME/.local/bin"

_zshenv_append_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
_zshenv_append_path "$HOME/Documents/proj/flutter/bin"

export ANDROID_HOME="$HOME/Library/Android/sdk"
_zshenv_append_path "$ANDROID_HOME/emulator"
_zshenv_append_path "$ANDROID_HOME/platform-tools"

_zshenv_append_path "$HOME/.maestro/bin"

export PATH

if command -v fnm >/dev/null 2>&1; then
  path=(${path:#${HOME}/.local/state/fnm_multishells/*/bin})
  export PATH
  eval "$(fnm env --use-on-cd --shell zsh)" >/dev/null 2>&1
fi

if [[ -n ${SSH_CONNECTION:-} ]]; then
  export EDITOR="vim"
else
  export EDITOR="zed"
fi

export LC_MESSAGES="en_US.UTF-8"
export PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"
export PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
export PERL_MB_OPT="--install_base \"$HOME/perl5\""
export PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"
export BAT_THEME="GitHub"
export NODE_COMPILE_CACHE="$HOME/.cache/nodejs-compile-cache"
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/dotfiles/scriptswithsecrets/play-service-account.json"

if [[ -n $SHELL_INTEGRATION ]] && [[ "$SHELL_INTEGRATION" == *"xcode-copilot-zsh"* ]]; then
  NO_P10K=true
fi

# Custom command functions.
# Keep these available to every zsh invocation; interactive aliases stay in .zshrc.
if [[ -n $NO_P10K ]]; then
    xcodebuild() {
        echo "xcodebuild is disabled. Just ask the user to build with Xcode."
    }
fi

no_npx() {
  echo "npx is disabled. Please use 'pnpm dlx' instead."
}

no_npm() {
  echo "npm is disabled. Please use 'pnpm' instead."
}

no_yarn() {
  echo "yarn is disabled. Please use 'pnpm' instead."
}

no_pnpm() {
  if [[ "$1" == "dev" ]] || ([[ "$2" == "dev" ]] && [[ "$1" == "run" ]]); then
    echo "The server is already running. Don't start commands that never exit. You can run pnpm build to check build errors, or access the server at http://localhost:3000"
  elif [[ "$1" == "drizzle-kit" ]] && [[ "$2" != "push" ]]; then
      echo "Migrations are run with 'drizzle-kit push'. That's the only drizzle kit command you need."
  elif [[ "$1" == "exec" ]] && [[ "$2" == "drizzle-kit" ]] && [[ "$3" != "push" ]]; then
      echo "Migrations are run with 'drizzle-kit push'. That's the only drizzle kit command you need."
  elif [[ "$1" == "drizzle-kit" ]] && [[ "$2" == "push" ]]; then
      echo "Migrations complete!"
  elif [[ "$1" == "exec" ]] && [[ "$2" == "drizzle-kit" ]] && [[ "$3" == "push" ]]; then
      echo "Migrations complete!"
  elif [[ "$1" == "build" ]]; then
      $orig_pnpm "$@"
      restart-next 2> /dev/null
  elif [[ "$2" == "build" ]] && [[ "$1" == "run" ]]; then
      $orig_pnpm "$@"
      restart-next 2> /dev/null
  else
      $orig_pnpm "$@"
  fi
}

restart-next() {
    # find pid for port 3000:
    lsof -ti:3000 | xargs kill -9
}

fork() { open -a "GitButler" "${1:-.}"; }

function listall() {
    emulate -L zsh
    [ -f .pyenv/bin/activate ] && source .pyenv/bin/activate
}

randomstring()
{
    cat /dev/urandom | base64 | sed 's/\//_/' | fold -w ${1:-32} | head -n 1
}

dockspeedup() {
    defaults write com.apple.dock autohide-delay -int 0; defaults write com.apple.dock autohide-time-modifier -float 0.15; killall Dock
}

unlockapp() {
    sudo chflags noschg "$1"
}

hlg() { hyperlayout global "$1" ; }

dockerrun () { docker run -it --rm -v "$(pwd):/m" --entrypoint sh "${1:-alpine}" -c "cd /m && sh" }

transmissiondocker() {
    local transmission_dir="$HOME/dotfiles/transmission"
    local settings_file="$transmission_dir/settings.json"
    local rpc_password

    if [[ ! -f "$settings_file" ]]; then
        echo "Transmission settings file not found: $settings_file" >&2
        return 1
    fi

    rpc_password="$(uuidgen | tr '[:upper:]' '[:lower:]')"

    python3 - "$settings_file" "$rpc_password" <<'PY'
import json
import sys

settings_file, rpc_password = sys.argv[1], sys.argv[2]

with open(settings_file, "r", encoding="utf-8") as f:
    settings = json.load(f)

settings["rpc-password"] = rpc_password

with open(settings_file, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=4)
    f.write("\n")
PY

    printf 'Transmission RPC password: %s\n' "$rpc_password"

    command docker run --rm \
        -p 9091:9091 \
        -v /Users/user/Downloads/torr:/downloads \
        -v /Users/user/dotfiles/transmission:/config \
        lscr.io/linuxserver/transmission:latest
}

unloaditunes() {
    launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist
}

loaditunes() {
    launchctl load -w /System/Library/LaunchAgents/com.apple.rcd.plist
}

pgadmin() {
    docker run -p 9090:80 --rm -e PGADMIN_DEFAULT_EMAIL=admin@example.com -e PGADMIN_DEFAULT_PASSWORD=pw -v ~/.pgadminsession:/var/lib/pgadmin dpage/pgadmin4
}

lnhyper() {
    sudo ln -s "/Applications/Hyper.app/Contents/Resources/bin/hyper" /usr/local/bin/hyper
}

gcp() { git commit -m "$*"; git push }

gac() { git add -A; git commit -m "$*" }

gacp() { git add -A; git commit -m "$*"; git push }

giacp() { git init; git add -A; git commit -m "$*"; git push }

copyhtml() {
    printf "set the clipboard to «data HTML$(cat $@ | hexdump -ve '1/1 "%.2x"')»" | osascript -
}

ensuredocker() {
    docker ps >/dev/null 2>&1 || orb >/dev/null 2>&1
    while ! docker ps >/dev/null 2>&1
    do
        sleep 1
    done
}

cleardocker() {
    yes | orb delete docker
    ensuredocker
}

fixxcodetemplate() {
    # Find all Xcode applications
    xcode_apps=$(find /Applications -maxdepth 1 -name "Xcode*" -type d)

    # Function to perform sed replacement
    perform_sed_replacement() {
        # macOS (BSD) sed
        sed 's://___FILEHEADER___:___FILEHEADER___:g' "$1" > .tmp.swift
        sudo mv .tmp.swift "$1" || echo "Give this terminal app full disk access and run the command again."
    }

    # Loop through each Xcode application
    echo "$xcode_apps" | while read -r app
    do
        echo "Processing $app"

        # Construct the path to the Templates directory
        templates_dir="$app/Contents/Developer/Library/Xcode/Templates/"

#/Applications/Xcode-16.0.0-Release.Candidate.app/Contents/Developer/Library/Xcode/Templates/File Templates/MultiPlatform/Source/Swift File.xctemplate/___FILEBASENAME___.swift

        # Check if the Templates directory exists
        if [ -d "$templates_dir" ]; then
            # Find all .swift files in the Templates directory and its subdirectories
            while IFS= read -r -d '' file; do
                echo "  Modifying $file"

                # Perform the string replacement
                perform_sed_replacement "$file"
            done < <(find "$templates_dir" -type f -name "*.swift" -print0)
        else
            echo "  Templates directory not found in $app"
        fi
    done

    echo "Script completed."
}

dump() {
    ~/Documents/proj/dump-s3-files/dump.sh
}

nu() {
    (cd ~/dotfiles/nix; nix flake update)
}

ns() {
    sudo darwin-rebuild switch --impure --flake ~/dotfiles/nix#spreen
}

nc() {
    sudo nix-collect-garbage -d
    nix-store --optimise
}

jn() {
    ~/Documents/proj/journal/new.sh
}

jc() {
    (cd ~/Documents/proj/journal; gacp .)
}

ks() {
    killall sketchybar
}

telnet() {
    nix-shell -p inetutils --run "telnet $(printf '%q ' "$@")"
}

eas() {
    npx eas-cli $@
}

p() {
    cd ~/Documents/proj/"$1"
}

ghostty() {
    wd="${1:-$(pwd)}"
    # Replace pattern replacements with sed
    if [[ "$wd" == "^$" ]]; then
        wd="$(pwd)"
    elif [[ "$wd" =~ "^\.(.*)" ]]; then
        wd="$(pwd)$(echo "$wd" | sed 's/^\.//')"
    fi

    open -na ghostty --args --title=ghostty-from-vscode --working-directory="$wd"
}

dotenv() {
    # tell Bash to export all vars that get defined
    set -o allexport

    # source your .env (only if it exists)
    [ -f .env ] && source .env
    [ -f .env.development.local ] && source .env.development.local

    # turn off automatic exporting
    set +o allexport
}

cleancaches() {
    # Xcode caches
    bash -c 'sudo rm -rf ~/Library/Developer/Xcode/DerivedData'
    bash -c 'sudo rm -rf ~/Library/Developer/Xcode/Archives'
    bash -c 'sudo rm -rf ~/Library/Developer/Xcode/DocumentationCache'
    bash -c 'sudo rm -rf ~/Library/Developer/Xcode/Products'
    bash -c 'sudo rm -rf ~/Library/Developer/Xcode/UserData/Previews'
    bash -c 'sudo rm -rf ~/Library/Developer/CoreSimulator/Caches'

    # Node.js caches
    bash -c 'sudo rm -rf ~/.npm/_cacache'
    bash -c 'sudo rm -rf ~/.cache/nodejs-compile-cache'
    bash -c 'sudo rm -rf ~/.yarn/cache'
    bash -c 'sudo rm -rf ~/.pnpm-store'
    bash -c 'sudo rm -rf node_modules/.cache'

    # Development tool caches
    bash -c 'sudo rm -rf ~/.cache/pip'
    bash -c 'sudo rm -rf ~/.gradle/caches'
    bash -c 'sudo rm -rf ~/.m2/repository/.cache'
    bash -c 'sudo rm -rf ~/.docker/desktop/vms/*/log.log'
    bash -c 'sudo rm -rf ~/.cache/composer'
    bash -c 'sudo rm -rf ~/.cache/go-build'
    bash -c 'sudo rm -rf ~/.cache/deno'
    bash -c 'sudo rm -rf ~/.cargo/registry/cache'
    bash -c 'sudo rm -rf ~/.cargo/git/db'
    bash -c 'sudo rm -rf ~/.cache/*'

    # Android Studio caches
    bash -c 'sudo rm -rf ~/Library/Caches/Google/AndroidStudio*'
    bash -c 'sudo rm -rf ~/Library/Application\ Support/Google/AndroidStudio*/caches'
    bash -c 'sudo rm -rf ~/Library/Logs/Google/AndroidStudio*'
    bash -c 'sudo rm -rf ~/.android/cache'
    bash -c 'sudo rm -rf ~/.android/avd/*.avd/cache'
    bash -c 'sudo rm -rf ~/.gradle/daemon'

    # VS Code caches
    bash -c 'sudo rm -rf ~/Library/Application\ Support/Code/CachedExtensions'
    bash -c 'sudo rm -rf ~/Library/Application\ Support/Code/logs'

    # System and general caches
    bash -c 'sudo rm -rf /tmp/*'
    bash -c 'sudo rm -rf ~/Library/Caches/*'
    bash -c 'sudo rm -rf ~/Library/Logs/*'
    bash -c 'sudo rm -rf /Library/Caches/*'
    bash -c 'sudo rm -rf /Library/Logs/*'
    bash -c 'sudo rm -rf ~/.Trash/*'

    # macOS system caches
    bash -c 'sudo rm -rf /private/var/folders/*/C/com.apple.DeveloperTools'
    bash -c 'sudo rm -rf /System/Library/Caches/*'
    bash -c 'sudo rm -rf /var/db/diagnostics'
    bash -c 'sudo rm -rf /var/db/uuidtext'

    bash -c 'sudo rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/'
    bash -c 'sudo rm -rf ~/Library/Developer/CoreSimulator/'

    # Chrome caches (but not cookies)
    bash -c 'sudo rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Cache'
    bash -c 'sudo rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Cache\ Storage'
    bash -c 'sudo rm -rf ~/Library/Application\ Support/Google/Chrome/Default/IndexedDB'
    bash -c 'sudo rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Service\ Worker'

    bash -c 'sudo rm -rf ~/Library/Caches/fnm_multishells'
    bash -c 'sudo rm -rf ~/.local/state/fnm_multishells'
    bash -c 'sudo rm -rf ~/.local/share/fnm/node-versions'
    bash -c 'sudo rm -rf ~/.local/share/fnm/aliases/*'
    bash -c 'sudo rm -rf /Users/user/Library/pnpm'

    find ~/Documents/proj -name node_modules -type d | grep -Ev 'node_modules/.' | while read d
    do
        rm -rf "$d"
    done
    find ~/Documents/proj -iname 'cargo.toml' -print0 | while IFS= read -r -d '' manifest
    do
        rm -rf "${manifest%/*}/target"
    done
    go clean --modcache
    find "$HOME/Library/Developer/Xcode/Archives" -type d -name "*.xcarchive" -print -exec rm -rf {} +
}

androidemulator() {
    "$HOME/Library/Android/sdk/emulator/emulator" -list-avds \
  | head -n 1 \
  | xargs -I{} "$HOME/Library/Android/sdk/emulator/emulator" -avd "{}"

}

uuidgen20() {
    # 20 uuids in a loop:
    for i in {1..20}; do
        uuidgen
    done
}

get-current-prompt() {
    # wait for file and wait for it to not be empty:
    while [[ ! -s ~/prompt.txt ]]; do
        sleep 0.5
    done

    prompt=$(cat ~/prompt.txt)
    # system="IMPORTANT: We're running in infinite mode. This means you should **never** end the current chat. To get the next user input, don't end your turn, but just call the "'`get-next-prompt`'" command in the shell tool. This will fetch the next user input without ending the chat."

    # # add <system> around the system message:
    # system="<system>$system</system>"

    # # print without replacing any special characters or backslashes:
    # printf "%s\n" "$system"
    # echo
    # echo
    printf "%s\n" "$prompt"
    echo
    echo '---'
    echo
    echo 'Then, once you are done, run `get-next-prompt` with shell_execute again. Never end your turn, just run `get-next-prompt` with shell_execute to get the next user input.'
}

get-next-prompt() {
    afplay "/System/Library/Sounds/Submarine.aiff" &
    rm ~/prompt.txt
    get-current-prompt
}

kill-mcp-child() {
    mcp=`ps -A | grep 'uv run mcp-shell-server' | grep -v grep | grep -Eo '^\s*\d+'`
    child1=`ps -axo pid,ppid,stat,etime,command | awk '$2=='$mcp | grep -Eo '^\s*\d+'`
    child2=`ps -axo pid,ppid,stat,etime,command | awk '$2=='$child1 | grep -Eo '^\s*\d+'`
    kill $child2
    sleep 1
    kill -9 $child2
}

cx() {
    codex --yolo "$@"
}

cl() {
    (brew upgrade --cask claude-code >/dev/null 2>&1 &)
    claude "$@" --dangerously-skip-permissions
}

openscad() {
    nix-shell -p openscad --run "open /nix/store/`ls /nix/store | grep -i openscad | grep -v .drv`/Applications/OpenSCAD.app"
}

petname() {
    # first param = number of words, default 1:
    local words=${1:-1}
    nix run nixpkgs#rust-petname -- -w "$words"
}

stripe() {
    nix run nixpkgs#stripe-cli -- "$@"
}

gcloud() {
	nix run nixpkgs#google-cloud-sdk -- "$@"
}

gacpg() {
    git init || return
    gac "$@"
    # check if remotes is empty:
    remotes=$(git remote)
    if [[ -n $remotes ]]; then
        echo "This repository already has a remote. Aborting."
        return 1
    fi

    fallback=$(petname 1)
    nix run nixpkgs#gh -- repo create "$(basename "$PWD")" --source=. --remote=origin --private --push && return 0
    nix run nixpkgs#gh -- repo create "$(basename "$PWD")-$(date +%Y)" --source=. --remote=origin --private --push && return 0
    nix run nixpkgs#gh -- repo create "$(basename "$PWD")-$fallback" --source=. --remote=origin --private --push && return 0
}

killfly() {
    ps -A | grep fly | grep -v grep | grep -Eo '^\s*\d+' | while read pid; do kill $pid; done
}

find_fly_token() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.fly_token" ]]; then
            echo "$dir/.fly_token"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

flylaunch() {
    local app_name="$1"
    if [[ -z "$app_name" ]]; then
        echo "Usage: flylaunch <app-name>"
        return 1
    fi

    local token
    if token_file=$(find_fly_token); then
        token=$(cat "$token_file")
    fi

    if [[ -z "$token" ]]; then
        echo "Error: Could not find .fly_token"
        return 1
    fi

    curl -sS -X POST "https://api.machines.dev/v1/apps" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{\"app_name\": \"$app_name\", \"org_slug\": \"personal\"}"
    echo
}

flydeleteapp() {
    local app_name="$1"
    if [[ -z "$app_name" ]]; then
        echo "Usage: flylaunch <app-name>"
        return 1
    fi

    local token
    if token_file=$(find_fly_token); then
        token=$(cat "$token_file")
    fi

    if [[ -z "$token" ]]; then
        echo "Error: Could not find .fly_token"
        return 1
    fi

    curl -o - -I -sS -X DELETE "https://api.machines.dev/v1/apps/$app_name" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" 2>&1 | head -1
    echo
}

killport() {
    local port=${1:-3000}
    kill `lsof -i :$port | grep -Eio '^\s*\w*\s*\d+' | grep -Eio '\d+'`
}

midnight() {
	s=$(( $(date -v+1d -v0H -v0M -v0S +%s) - $(date +%s) )); echo "Waiting $((s/3600))h $((s%3600/60))m $((s%60))s until midnight"; sleep $s
}


unfunction _zshenv_prepend_path _zshenv_append_path
