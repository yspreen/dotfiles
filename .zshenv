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

unfunction _zshenv_prepend_path _zshenv_append_path
