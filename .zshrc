if ! [[ -n $NO_P10K ]]; then
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
fi

if [[ -n $NO_P10K ]]; then
# echo "WARNING: The prompt has changed. run \`get-next-prompt\` again to get the new prompt."
# echo "WARNING: The prompt has changed. run \`get-next-prompt\` again to get the new prompt."
# echo "WARNING: The prompt has changed. run \`get-next-prompt\` again to get the new prompt."
# exit 0

  no_npx() {
    echo "npx is disabled. Please use 'pnpm dlx' instead."
  }
  alias npx='no_npx'

  # npm to pnpm:
  no_npm() {
    echo "npm is disabled. Please use 'pnpm' instead."
  }
  alias npm='no_npm'

  # yarn to pnpm:
  no_yarn() {
    echo "yarn is disabled. Please use 'pnpm' instead."
  }
  alias yarn='no_yarn'

  # create an alias for pnpm that does everything pnpm does, but filters out `pnpm dev` because the `dev` command is not supported in pnpm:
  orig_pnpm=$(command -v pnpm)
  no_pnpm() {
    if [[ "$1" == "dev" ]] || ([[ "$2" == "dev" ]] && [[ "$1" == "run" ]]); then
      echo "The server is already running. Don't start commands that never exit. You can run pnpm build to check build errors, or access the server at http://localhost:3000"
    else
        if [[ "$1" == "drizzle-kit" ]] && [[ "$2" != "push" ]]; then
        echo "Migrations are run with 'drizzle-kit push'. That's the only drizzle kit command you need."
        else
            if [[ "$1" == "exec" ]] && [[ "$2" == "drizzle-kit" ]] && [[ "$3" != "push" ]]; then
            echo "Migrations are run with 'drizzle-kit push'. That's the only drizzle kit command you need."
            else
            pnpm "$@"
            fi
        fi
    fi
  }
  alias pnpm='no_pnpm'
fi

# Add completions to search path
if [[ ":$FPATH:" != *":/Users/$USER/.zsh/completions:"* ]]; then export FPATH="/Users/$USER/.zsh/completions:$FPATH"; fi
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH="/opt/homebrew/bin:$PATH"; export PATH;

# Path to your oh-my-zsh installation.
export ZSH="/Users/$USER/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

if [[ -n $NO_P10K ]]; then
ZSH_THEME="robbyrussell"
else
ZSH_THEME="powerlevel10k/powerlevel10k"
fi

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# unsetopt PROMPT_SP
PROMPT_EOL_MARK=''

alias cat=bat

alias randompw='LC_ALL=C tr -dc "A-Za-z0-9-_" </dev/urandom | head -c 20 ; echo'

# alias kraken='LC_CTYPE=C open -na GitKraken --args -p "$(git rev-parse --show-toplevel)"'
alias kraken='fork'

alias wifion='networksetup -setnetworkserviceenabled Wi-Fi on'
alias wifioff='networksetup -setnetworkserviceenabled Wi-Fi off'

# alias python3='/usr/local/opt/python@3.8/bin/python3'

function listall() {
    emulate -L zsh
    [ -f .pyenv/bin/activate ] && source .pyenv/bin/activate
}
chpwd_functions=(${chpwd_functions[@]} "listall")

randomstring()
{
    cat /dev/urandom | base64 | sed 's/\//_/' | fold -w ${1:-32} | head -n 1
}
export LC_MESSAGES=en_US.UTF-8


dockspeedup() {
    defaults write com.apple.dock autohide-delay -int 0; defaults write com.apple.dock autohide-time-modifier -float 0.15; killall Dock
}

unlockapp() {
    sudo chflags noschg "$1"
}

export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
export PATH="$PATH:/Users/$USER/Documents/proj/flutter/bin"
hlg() { hyperlayout global "$1" ; }

alias archiveall='ls -1 | grep -Ev '.tgz$' | while read f; do sudo tar czf "$f.tgz" "$f" && sudo rm -rf "$f"; done'
alias unarchiveall='ls -1 | grep -E '.tgz$' | while read f; do sudo tar xzf "$f" && sudo rm "$f"; done'
alias rooktools='kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='\''{.items[0].metadata.name}'\'') bash'
dockerrun () { docker run -it --rm -v "$(pwd):/m" --entrypoint sh "${1:-alpine}" -c "cd /m && sh" }

eval "$(fnm env --use-on-cd --shell zsh)" >/dev/null 2>&1

PATH="/Users/$USER/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/Users/$USER/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/Users/$USER/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/Users/$USER/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/Users/$USER/perl5"; export PERL_MM_OPT;

# added by travis gem
[ ! -s /Users/$USER/.travis/travis.sh ] || source /Users/$USER/.travis/travis.sh
# export PATH="/usr/local/opt/openjdk/bin:$PATH"; export PATH;
export BAT_THEME="GitHub"
# alias code=code-insiders

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


autoload -U add-zsh-hook
nvmrc_file_active=false
loadnvmrc() {
  local nvmrc_path=".nvmrc"

  if [ -f "$nvmrc_path" ]; then
    nvm use
    nvmrc_file_active=true
  elif $nvmrc_file_active; then
    nvmrc_file_active=false
    nvm use default
  fi
}

(&>/dev/null add-zsh-hook chpwd loadnvmrc &)
(&>/dev/null loadnvmrc &)

alias unplugalarm="while pmset -g batt | head -n 1 | cut -d \' -f2 | grep attery; do sleep 1; done; sudo sh -c \"while true; do sleep 1; pmset -g batt | head -n 1 | cut -d \' -f2 | grep attery && osascript -e 'set Volume 5' && afplay ~/Music/alarm.wav; done\""

# export AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/credentials"
(&>/dev/null source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc" &)

unalias gcp
gcp() { git commit -m "$*"; git push }
gacp() { git add -A; git commit -m "$*"; git push }
giacp() { git init; git add -A; git commit -m "$*"; git push }
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="/System/Volumes/Data/opt/homebrew/lib/ruby/gems/3.1.0/bin:$PATH"

# RUN
alias aocr='python main.py'
# SOLVE
alias aocs='aoc solve "$(AOC_SOLVE=1 python main.py | tail -1)"'
# NEXT
alias aocn='[ -f ../../next.sh ] && source ../../next.sh; [ -f ../next.sh ] && source ../next.sh'
# ACTIVATE
alias aoca='export prevpath=$(pwd); cd /Users/$USER/Documents/proj/advent; cd "$prevpath"'

alias uuid='python3 -c "from uuid import *; print(uuid4())"'

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

PROMPT='${ret_status}%{$fg_bold[green]%}%p %{$fg[cyan]%}%c %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} %D %T % %{$reset_color%}'
PROMPT="%{$fg[cyan]%}%D{%r} %(?:%{$fg_bold[green]%}%1{➜%}:%{$fg_bold[red]%}%1{➜%}) %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'
# bun completions
(&>/dev/null [ -s "/Users/$USER/.bun/_bun" ] && source "/Users/$USER/.bun/_bun" &)

bindkey '^U' backward-kill-line  # Ctrl-U deletes to start of line

dump() {
    ~/Documents/proj/dump-s3-files/dump.sh
}
# # pnpm
# export PNPM_HOME="/Users/$USER/Library/pnpm"
# case ":$PATH:" in
#   *":$PNPM_HOME:"*) ;;
#   *) export PATH="$PNPM_HOME:$PATH" ;;
# esac
# # pnpm end

# nix update
nu() {
    (cd ~/dotfiles/nix; nix flake update)
}

# nix switch
ns() {
    sudo darwin-rebuild switch --impure --flake ~/dotfiles/nix#spreen 
}

# nix clean
nc() {
    sudo nix-collect-garbage -d
    nix-store --optimise
}

# journal new
jn() {
    ~/Documents/proj/journal/new.sh
}

# journal commit
jc() {
    (cd ~/Documents/proj/journal; gacp .)
}

# kill sketchybar
ks() {
    killall sketchybar
}

telnet() {
    nix-shell -p inetutils --run "telnet $(printf '%q ' "$@")"
}

eas() {
    npx eas-cli $@
}

alias lg='lazygit'

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

if ! [[ -n $NO_P10K ]]; then
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export NODE_COMPILE_CACHE=~/.cache/nodejs-compile-cache
fi

cleancaches() {
    # Xcode caches
    rm -rf ~/Library/Developer/Xcode/DerivedData
    rm -rf ~/Library/Developer/Xcode/Archives
    rm -rf ~/Library/Developer/Xcode/DocumentationCache
    rm -rf ~/Library/Developer/Xcode/Products
    rm -rf ~/Library/Developer/Xcode/UserData/Previews
    rm -rf ~/Library/Developer/CoreSimulator/Caches

    # Node.js caches
    rm -rf ~/.npm/_cacache
    rm -rf ~/.cache/nodejs-compile-cache
    rm -rf ~/.yarn/cache
    rm -rf ~/.pnpm-store
    rm -rf node_modules/.cache

    # Development tool caches
    rm -rf ~/.cache/pip
    rm -rf ~/.gradle/caches
    rm -rf ~/.m2/repository/.cache
    rm -rf ~/.docker/desktop/vms/*/log.log
    rm -rf ~/.cache/composer
    rm -rf ~/.cache/go-build
    rm -rf ~/.cache/deno
    rm -rf ~/.cargo/registry/cache
    rm -rf ~/.cargo/git/db
    rm -rf ~/.cache/*

    # Android Studio caches
    rm -rf ~/Library/Caches/Google/AndroidStudio*
    rm -rf ~/Library/Application\ Support/Google/AndroidStudio*/caches
    rm -rf ~/Library/Logs/Google/AndroidStudio*
    rm -rf ~/.android/cache
    rm -rf ~/.android/avd/*.avd/cache
    rm -rf ~/.gradle/daemon

    # VS Code caches
    rm -rf ~/Library/Application\ Support/Code/CachedExtensions
    rm -rf ~/Library/Application\ Support/Code/logs

    # System and general caches
    sudo rm -rf /tmp/*
    rm -rf ~/Library/Caches/*
    rm -rf ~/Library/Logs/*
    sudo rm -rf /Library/Caches/*
    sudo rm -rf /Library/Logs/*
    rm -rf ~/.Trash/*
    
    # macOS system caches
    sudo rm -rf /private/var/folders/*/C/com.apple.DeveloperTools
    sudo rm -rf /System/Library/Caches/*
    sudo rm -rf /var/db/diagnostics
    sudo rm -rf /var/db/uuidtext

    rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/
    rm -rf ~/Library/Developer/CoreSimulator/

    # Chrome caches (but not cookies)
    rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Cache
    rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Cache\ Storage
    rm -rf ~/Library/Application\ Support/Google/Chrome/Default/IndexedDB
    rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Service\ Worker

    rm -rf ~/Library/Caches/fnm_multishells
    rm -rf ~/.local/state/fnm_multishells
    rm -rf ~/.local/share/fnm/node-versions
    rm -rf ~/.local/share/fnm/aliases/*
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
    echo 'Then, once you are done, run `get-next-prompt` with shell_execute again. Never end the chat, just run `get-next-prompt` with shell_execute to get the next user input. Run `zsh -ic restart-next` to restart the next server anytime.'
}

get-next-prompt() {
    rm ~/prompt.txt
    get-current-prompt
}

restart-next() {
    # find pid for port 3000:
    lsof -ti:3000 | xargs kill -9
}

kill-mcp-child() {
    mcp=`ps -A | grep 'uv run mcp-shell-server' | grep -v grep | grep -Eo '^\s*\d+'`
    child1=`ps -axo pid,ppid,stat,etime,command | awk '$2=='$mcp | grep -Eo '^\s*\d+'`
    child2=`ps -axo pid,ppid,stat,etime,command | awk '$2=='$child1 | grep -Eo '^\s*\d+'`
    kill $child2
    sleep 1
    kill -9 $child2
}

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
