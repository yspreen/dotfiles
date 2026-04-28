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

  alias npx='no_npx'

  # npm to pnpm:
  alias npm='no_npm'

  # yarn to pnpm:
  alias yarn='no_yarn'

  # create an alias for pnpm that does everything pnpm does, but filters out `pnpm dev` because the `dev` command is not supported in pnpm:
  orig_pnpm=$(command -v pnpm)
  alias pnpm='no_pnpm'
fi

# Add completions to search path
if [[ ":$FPATH:" != *":/Users/$USER/.zsh/completions:"* ]]; then export FPATH="/Users/$USER/.zsh/completions:$FPATH"; fi
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

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
alias kraken='open -a "GitButler"'

alias sentry-wizard='pnpm dlx @sentry/wizard@latest'

alias wifion='networksetup -setnetworkserviceenabled Wi-Fi on'
alias wifioff='networksetup -setnetworkserviceenabled Wi-Fi off'

# alias python3='/usr/local/opt/python@3.8/bin/python3'

chpwd_functions=(${chpwd_functions[@]} "listall")

alias archiveall='ls -1 | grep -Ev '.tgz$' | while read f; do sudo tar czf "$f.tgz" "$f" && sudo rm -rf "$f"; done'
alias unarchiveall='ls -1 | grep -E '.tgz$' | while read f; do sudo tar xzf "$f" && sudo rm "$f"; done'
alias rooktools='kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='\''{.items[0].metadata.name}'\'') bash'

# added by travis gem
[ ! -s /Users/$USER/.travis/travis.sh ] || source /Users/$USER/.travis/travis.sh
# export PATH="/usr/local/opt/openjdk/bin:$PATH"; export PATH;
# alias code=code-insiders

autoload -U add-zsh-hook

alias unplugalarm="while pmset -g batt | head -n 1 | cut -d \' -f2 | grep attery; do sleep 1; done; sudo sh -c \"while true; do sleep 1; pmset -g batt | head -n 1 | cut -d \' -f2 | grep attery && osascript -e 'set Volume 5' && afplay ~/Music/alarm.wav; done\""

# export AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/credentials"
(&>/dev/null source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc" &)

unalias gcp

# RUN
alias aocr='python main.py'
# SOLVE
alias aocs='aoc solve "$(AOC_SOLVE=1 python main.py | tail -1)"'
# NEXT
alias aocn='[ -f ../../next.sh ] && source ../../next.sh; [ -f ../next.sh ] && source ../next.sh'
# ACTIVATE
alias aoca='export prevpath=$(pwd); cd /Users/$USER/Documents/proj/advent; cd "$prevpath"'

alias uuid='python3 -c "from uuid import *; print(uuid4())"'

PROMPT='${ret_status}%{$fg_bold[green]%}%p %{$fg[cyan]%}%c %{$fg_bold[blue]%}$(git_prompt_info)%{$fg_bold[blue]%} %D %T % %{$reset_color%}'
PROMPT="%{$fg[cyan]%}%D{%r} %(?:%{$fg_bold[green]%}%1{➜%}:%{$fg_bold[red]%}%1{➜%}) %{$fg[cyan]%}%c%{$reset_color%}"
PROMPT+=' $(git_prompt_info)'
# bun completions
(&>/dev/null [ -s "/Users/$USER/.bun/_bun" ] && source "/Users/$USER/.bun/_bun" &)

bindkey '^U' backward-kill-line  # Ctrl-U deletes to start of line

# # pnpm
# export PNPM_HOME="/Users/$USER/Library/pnpm"
# case ":$PATH:" in
#   *":$PNPM_HOME:"*) ;;
#   *) export PATH="$PNPM_HOME:$PATH" ;;
# esac
# # pnpm end

# nix update

# nix switch

# nix clean

# journal new

# journal commit

# kill sketchybar

alias lg='lazygit'

if ! [[ -n $NO_P10K ]]; then
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
fi

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# Git Add Commit Push make Github repo

alias cursor="open -a Cursor"

# find nearest .fly_token in parent directories

unalias gpd 2>/dev/null

eval "$(but completions zsh)"

# >>> forge initialize >>>
# !! Contents within this block are managed by 'forge zsh setup' !!
# !! Do not edit manually - changes will be overwritten !!

# Add required zsh plugins if not already present
if [[ ! " ${plugins[@]} " =~ " zsh-autosuggestions " ]]; then
    plugins+=(zsh-autosuggestions)
fi
if [[ ! " ${plugins[@]} " =~ " zsh-syntax-highlighting " ]]; then
    plugins+=(zsh-syntax-highlighting)
fi

# Load forge shell plugin (commands, completions, keybindings) if not already loaded
if [[ -z "$_FORGE_PLUGIN_LOADED" ]]; then
    eval "$(forge zsh plugin)"
fi

# Load forge shell theme (prompt with AI context) if not already loaded
if [[ -z "$_FORGE_THEME_LOADED" ]]; then
    eval "$(forge zsh theme)"
fi
# <<< forge initialize <<<
