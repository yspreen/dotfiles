# Add deno completions to search path
if [[ ":$FPATH:" != *":/Users/user/.zsh/completions:"* ]]; then export FPATH="/Users/user/.zsh/completions:$FPATH"; fi
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH="/opt/homebrew/bin:$PATH"; export PATH;

# Path to your oh-my-zsh installation.
export ZSH="/Users/user/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

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

sudotouchid() {
    n="$(cat /etc/pam.d/sudo | wc -l)"
    t="$(cat /etc/pam.d/sudo | head -1; echo 'auth sufficient pam_tid.so'; cat /etc/pam.d/sudo | tail "-$((n-1))")"
    echo $t | sudo tee /etc/pam.d/sudo
}

dockspeedup() {
    defaults write com.apple.dock autohide-delay -int 0; defaults write com.apple.dock autohide-time-modifier -float 0.15; killall Dock
}

unlockapp() {
    sudo chflags noschg "$1"
}

export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
export PATH="$PATH:/Users/user/Documents/proj/flutter/bin"
hlg() { hyperlayout global "$1" ; }

alias archiveall='ls -1 | grep -Ev '.tgz$' | while read f; do sudo tar czf "$f.tgz" "$f" && sudo rm -rf "$f"; done'
alias unarchiveall='ls -1 | grep -E '.tgz$' | while read f; do sudo tar xzf "$f" && sudo rm "$f"; done'
alias rooktools='kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='\''{.items[0].metadata.name}'\'') bash'
dockerrun () { docker run -it --rm -v "$(pwd):/m" --entrypoint sh "${1:-alpine}" -c "cd /m && sh" }

eval "$(fnm env --use-on-cd --shell zsh)"

PATH="/Users/user/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="/Users/user/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="/Users/user/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"/Users/user/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=/Users/user/perl5"; export PERL_MM_OPT;

# added by travis gem
[ ! -s /Users/user/.travis/travis.sh ] || source /Users/user/.travis/travis.sh
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
alias aoca='export prevpath=$(pwd); cd /Users/user/Documents/proj/advent; cd "$prevpath"'

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
(&>/dev/null [ -s "/Users/user/.bun/_bun" ] && source "/Users/user/.bun/_bun" &)

bindkey '^U' backward-kill-line  # Ctrl-U deletes to start of line

# store old `fly` command:
alias fly_old=`which fly`

# find nearest .fly_token in parent directories
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

# override `fly` command to use contents of nearest .fly_token with -k $token if present:
fly() {
  if token_file=$(find_fly_token); then
    token=$(cat "$token_file")
    fly_old --access-token "$token" $@
  else
    fly_old $@
  fi
}

dump() {
    ~/Documents/proj/dump-s3-files/dump.sh
}
# # pnpm
# export PNPM_HOME="/Users/user/Library/pnpm"
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
    darwin-rebuild switch --flake ~/dotfiles/nix#spreen
}
