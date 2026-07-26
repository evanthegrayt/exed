##
# Sourceable zsh integration for exed.
#
# This file intentionally does not source bin/exed. It only makes the
# executable and zsh completion discoverable in the current shell.

_exed_plugin_dir=${0:A:h}
_exed_completion_dir="$_exed_plugin_dir/share/zsh/site-functions"

typeset -gU path fpath
path=("$_exed_plugin_dir/bin" $path)
fpath=("$_exed_completion_dir" $fpath)

if ! (( $+functions[compdef] )); then
  autoload -Uz compinit
  compinit -D -i
fi

if (( $+functions[compdef] )); then
  autoload -Uz _exed
  compdef _exed exed
fi

unset _exed_plugin_dir _exed_completion_dir
