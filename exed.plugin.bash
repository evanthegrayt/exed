##
# Sourceable bash integration for exed.
#
# This file intentionally does not source bin/exed. It only makes the
# executable and bash completion discoverable in the current shell.

_exed_source=${BASH_SOURCE[0]}
while [[ -h $_exed_source ]]; do
    _exed_dir="$( cd -P "$( dirname "$_exed_source" )" >/dev/null 2>&1 && pwd )"
    _exed_source="$( readlink "$_exed_source" )"
    [[ $_exed_source == /* ]] || _exed_source="$_exed_dir/$_exed_source"
done
_exed_plugin_dir="$( cd -P "$( dirname "$_exed_source" )" >/dev/null 2>&1 && pwd )"
_exed_completion_file="$_exed_plugin_dir/share/bash-completion/completions/exed"

case ":$PATH:" in
    *":$_exed_plugin_dir/bin:"*) ;;
    *) PATH="$_exed_plugin_dir/bin:$PATH" ;;
esac

if [[ -r $_exed_completion_file ]]; then
    # shellcheck source=/dev/null
    source "$_exed_completion_file"
fi

if [[ -n ${BASH_IT:-} ]] \
    && declare -F cite >/dev/null \
    && declare -F about-plugin >/dev/null; then
    cite about-plugin
    about-plugin 'find or create executable scripts and open them in an editor'
fi

unset _exed_source _exed_dir _exed_plugin_dir _exed_completion_file
