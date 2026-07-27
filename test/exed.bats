#!/usr/bin/env bats

setup() {
    REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
    EXED="$REPO_ROOT/bin/exed"
    TEST_HOME="$BATS_TEST_TMPDIR/home"
    PATH_FIXTURES="$BATS_TEST_TMPDIR/path"
    ENV_PATH=$(command -v env)
    BASH_PATH=$(command -v bash)

    mkdir -p "$TEST_HOME" "$PATH_FIXTURES"
}

exed() {
    HOME="$TEST_HOME" VISUAL= EDITOR= "$EXED" "$@" 2>&1
}

file_mode() {
    if stat -f %Lp "$1" >/dev/null 2>&1; then
        stat -f %Lp "$1"
    else
        stat -c %a "$1"
    fi
}

line_at() {
    sed -n "${1}p" "$2"
}

make_executable() {
    local file=$1

    printf '#!/bin/sh\n' > "$file"
    chmod +x "$file"
}

make_recording_editor() {
    local editor=$1
    local record_file=$2

    {
        printf '#!/usr/bin/env bash\n'
        printf 'printf "%%s\\n" "$1" > %q\n' "$record_file"
    } > "$editor"
    chmod +x "$editor"
}

make_arg_recording_editor() {
    local editor=$1
    local record_file=$2

    {
        printf '#!/usr/bin/env bash\n'
        printf 'printf "%%s\\n" "$@" > %q\n' "$record_file"
    } > "$editor"
    chmod +x "$editor"
}

@test "script can be sourced without running main" {
    run bash -c 'source "$1"; print_usage; declare -p PROGRAM VERSION USAGE DEFAULT_LANGUAGE DEFAULT_PERMS IFS_LINE' _ "$EXED"

    [ "$status" -eq 0 ]
    [[ $output == *"USAGE: exed [OPTIONS...] EXECUTABLE_NAME"* ]]
    [[ $output == *"declare -r PROGRAM"* ]]
    [[ $output == *"declare -r VERSION"* ]]
    [[ $output == *"declare -r USAGE"* ]]
    [[ $output == *"declare -r DEFAULT_LANGUAGE"* ]]
    [[ $output == *"declare -r DEFAULT_PERMS"* ]]
    [[ $output == *"declare -r IFS_LINE"* ]]
}

@test "bash plugin exposes executable and completion without sourcing executable" {
    run bash --noprofile --norc -c 'PATH=/usr/bin:/bin; source "$1"; command -v exed; complete -p exed' _ "$REPO_ROOT/exed.plugin.bash"

    [ "$status" -eq 0 ]
    [[ $output == *"$REPO_ROOT/bin/exed"* ]]
    [[ $output == *"complete"* ]]
    [[ $output == *"_exed_complete"* ]]
}

@test "bash completion distinguishes option arguments from the executable operand" {
    run bash --noprofile --norc -c '
        source "$1"

        COMP_WORDS=(exed foo "")
        COMP_CWORD=2
        _exed_complete
        printf "after_operand=%s\n" "${#COMPREPLY[@]}"

        COMP_WORDS=(exed -c -l bash "")
        COMP_CWORD=4
        _exed_complete
        printf "create_candidates=%s\n" "${#COMPREPLY[@]}"
    ' _ "$REPO_ROOT/share/bash-completion/completions/exed"

    [ "$status" -eq 0 ]
    [[ $output == *"after_operand=0"* ]]
    [[ $output == *"create_candidates="* ]]
    [[ $output != *"create_candidates=0"* ]]
}

@test "bash completion completes PATH commands in find mode" {
    local target="$PATH_FIXTURES/exed-fixture-command"

    make_executable "$target"

    run bash --noprofile --norc -c '
        source "$1"
        PATH="$2"
        COMP_WORDS=(exed exed-fixt)
        COMP_CWORD=1
        _exed_complete
        printf "%s\n" "${COMPREPLY[@]}"
    ' _ "$REPO_ROOT/share/bash-completion/completions/exed" "$PATH_FIXTURES"

    [ "$status" -eq 0 ]
    [[ $output == *"exed-fixture-command"* ]]
}

@test "bash completion completes files in create mode" {
    local target="$BATS_TEST_TMPDIR/completion-script"

    printf '%s\n' "draft" > "$target"

    run bash --noprofile --norc -c '
        source "$1"
        COMP_WORDS=(exed -c "$2")
        COMP_CWORD=2
        _exed_complete
        printf "%s\n" "${COMPREPLY[@]}"
    ' _ "$REPO_ROOT/share/bash-completion/completions/exed" "$BATS_TEST_TMPDIR/completion-s"

    [ "$status" -eq 0 ]
    [[ $output == *"$target"* ]]
}

@test "bash completion scopes template names by selected language" {
    local templates="$BATS_TEST_TMPDIR/templates"

    mkdir -p "$templates/bash" "$templates/python"
    printf '%s\n' "echo user" > "$templates/bash/user"
    printf '%s\n' "print('user')" > "$templates/python/userpy"
    printf 'template_dir=%q\n' "$templates" > "$TEST_HOME/.exedrc"

    run bash --noprofile --norc -c '
        source "$1"
        HOME="$2"
        PATH="$3/bin:$PATH"
        COMP_WORDS=(exed -c -l bash -t "")
        COMP_CWORD=5
        _exed_complete
        printf "%s\n" "${COMPREPLY[@]}"
    ' _ "$REPO_ROOT/share/bash-completion/completions/exed" "$TEST_HOME" "$REPO_ROOT"

    [ "$status" -eq 0 ]
    [[ $output == *"strict"* ]]
    [[ $output == *"user"* ]]
    [[ $output != *"cli"* ]]
    [[ $output != *"userpy"* ]]
}

@test "zsh completion scopes template names by selected language" {
    command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"

    local templates="$BATS_TEST_TMPDIR/templates"

    mkdir -p "$templates/bash" "$templates/python"
    printf '%s\n' "echo user" > "$templates/bash/user"
    printf '%s\n' "print('user')" > "$templates/python/userpy"
    printf 'template_dir=%q\n' "$templates" > "$TEST_HOME/.exedrc"

    run zsh -f -c '
        source "$1" >/dev/null 2>&1 || true
        HOME="$2"
        PATH="$3/bin:$PATH"
        typeset -A opt_args
        opt_args=(-l bash)
        _exed_template_words
    ' _ "$REPO_ROOT/share/zsh/site-functions/_exed" "$TEST_HOME" "$REPO_ROOT"

    [ "$status" -eq 0 ]
    [[ $output == *"strict"* ]]
    [[ $output == *"user"* ]]
    [[ $output != *"cli"* ]]
    [[ $output != *"userpy"* ]]
}

@test "zsh plugin exposes executable and completion" {
    command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"

    run zsh -f -c 'source "$1"; command -v exed; print -r -- ${fpath[1]}; (( $+functions[_exed] ))' _ "$REPO_ROOT/exed.plugin.zsh"

    [ "$status" -eq 0 ]
    [[ $output == *"$REPO_ROOT/bin/exed"* ]]
    [[ $output == *"$REPO_ROOT/share/zsh/site-functions"* ]]
}

@test "zsh plugin works from an Oh My Zsh custom plugin directory" {
    command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"

    local custom="$BATS_TEST_TMPDIR/oh-my-zsh/custom"

    mkdir -p "$custom/plugins"
    ln -s "$REPO_ROOT" "$custom/plugins/exed"

    run zsh -f -c 'source "$1/plugins/exed/exed.plugin.zsh"; command -v exed; print -r -- ${path[1]}; print -r -- ${fpath[1]}' _ "$custom"

    [ "$status" -eq 0 ]
    [[ $output == *"$REPO_ROOT/bin/exed"* ]]
    [[ $output == *"$REPO_ROOT/bin"* ]]
    [[ $output == *"$REPO_ROOT/share/zsh/site-functions"* ]]
}

@test "zsh plugin keeps PATH changes when sourced from a function" {
    command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"

    run zsh -f -c 'load_plugin() { source "$1"; }; load_plugin "$1"; command -v exed; print -r -- ${path[1]}; print -r -- ${fpath[1]}' _ "$REPO_ROOT/exed.plugin.zsh"

    [ "$status" -eq 0 ]
    [[ $output == *"$REPO_ROOT/bin/exed"* ]]
    [[ $output == *"$REPO_ROOT/bin"* ]]
    [[ $output == *"$REPO_ROOT/share/zsh/site-functions"* ]]
}

@test "installer installs executable, man page, and completions under prefix" {
    local prefix="$BATS_TEST_TMPDIR/prefix"

    run "$REPO_ROOT/install.sh" --prefix "$prefix"

    [ "$status" -eq 0 ]
    [ -L "$prefix/bin/exed" ]
    [ -L "$prefix/share/exed/templates" ]
    [ -L "$prefix/share/man/man1/exed.1" ]
    [ -L "$prefix/share/zsh/site-functions/_exed" ]
    [ -L "$prefix/share/bash-completion/completions/exed" ]
}

@test "installer copy mode creates regular files with expected modes" {
    local prefix="$BATS_TEST_TMPDIR/copy-prefix"

    run "$REPO_ROOT/install.sh" --prefix "$prefix" --copy

    [ "$status" -eq 0 ]
    [ -f "$prefix/bin/exed" ]
    [ ! -L "$prefix/bin/exed" ]
    [ "$(file_mode "$prefix/bin/exed")" = "755" ]
    [ -f "$prefix/share/exed/templates/bash/strict" ]
    [ "$(file_mode "$prefix/share/exed/templates/bash/strict")" = "644" ]
    [ -f "$prefix/share/man/man1/exed.1" ]
    [ "$(file_mode "$prefix/share/man/man1/exed.1")" = "644" ]
    [ -f "$prefix/share/zsh/site-functions/_exed" ]
    [ "$(file_mode "$prefix/share/zsh/site-functions/_exed")" = "644" ]
    [ -f "$prefix/share/bash-completion/completions/exed" ]
    [ "$(file_mode "$prefix/share/bash-completion/completions/exed")" = "644" ]
}

@test "installer refuses to overwrite existing files without force" {
    local prefix="$BATS_TEST_TMPDIR/refuse-prefix"

    run "$REPO_ROOT/install.sh" --prefix "$prefix" --no-man --no-completions
    [ "$status" -eq 0 ]

    run "$REPO_ROOT/install.sh" --prefix "$prefix" --no-man --no-completions

    [ "$status" -eq 1 ]
    [[ $output == *"Refusing to replace existing file:"* ]]
    [[ $output == *"/bin/exed"* ]]
}

@test "installer force replaces existing files" {
    local prefix="$BATS_TEST_TMPDIR/force-prefix"

    mkdir -p "$prefix/bin"
    printf '%s\n' "old" > "$prefix/bin/exed"

    run "$REPO_ROOT/install.sh" --prefix "$prefix" --force --no-man --no-completions

    [ "$status" -eq 0 ]
    [ -L "$prefix/bin/exed" ]
    [ "$(readlink "$prefix/bin/exed")" = "$REPO_ROOT/bin/exed" ]
}

@test "installer can skip man page and completions" {
    local prefix="$BATS_TEST_TMPDIR/minimal-prefix"

    run "$REPO_ROOT/install.sh" --prefix "$prefix" --no-man --no-completions

    [ "$status" -eq 0 ]
    [ -L "$prefix/bin/exed" ]
    [ -L "$prefix/share/exed/templates" ]
    [ ! -e "$prefix/share/man/man1/exed.1" ]
    [ ! -e "$prefix/share/zsh/site-functions/_exed" ]
    [ ! -e "$prefix/share/bash-completion/completions/exed" ]
}

@test "installer user mode installs under home local prefix" {
    local home="$BATS_TEST_TMPDIR/install-home"

    run env HOME="$home" "$REPO_ROOT/install.sh" --user --no-man --no-completions

    [ "$status" -eq 0 ]
    [ -L "$home/.local/bin/exed" ]
}

@test "installer rejects unknown options and missing prefix arguments" {
    run "$REPO_ROOT/install.sh" --definitely-not-real
    [ "$status" -eq 1 ]
    [[ $output == *"Unknown option: --definitely-not-real"* ]]

    run "$REPO_ROOT/install.sh" --prefix
    [ "$status" -eq 1 ]
    [[ $output == *"--prefix requires a directory."* ]]
}

@test "default mode opens first executable found in PATH" {
    local target="$PATH_FIXTURES/existing"
    local opened="$BATS_TEST_TMPDIR/opened"

    make_executable "$target"

    run env PATH="$PATH_FIXTURES:$PATH" HOME="$TEST_HOME" VISUAL= EDITOR= \
        "$EXED" -e "touch $opened" existing

    [ "$status" -eq 0 ]
    [ -e "$opened" ]
}

@test "editor option accepts flags before the opened file" {
    local target="$PATH_FIXTURES/existing"
    local editor="$BATS_TEST_TMPDIR/record-editor-args"
    local opened="$BATS_TEST_TMPDIR/opened-args"

    make_executable "$target"
    make_arg_recording_editor "$editor" "$opened"

    run env PATH="$PATH_FIXTURES:$PATH" HOME="$TEST_HOME" VISUAL= EDITOR= \
        "$EXED" -e "$editor --wait" existing

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$opened")" = "--wait" ]
    [ "$(line_at 2 "$opened")" = "$target" ]
}

@test "all matches mode prompts and opens the selected PATH match" {
    local first_dir="$BATS_TEST_TMPDIR/first-path"
    local second_dir="$BATS_TEST_TMPDIR/second-path"
    local first_target="$first_dir/dupe"
    local second_target="$second_dir/dupe"
    local editor="$BATS_TEST_TMPDIR/record-editor"
    local opened="$BATS_TEST_TMPDIR/opened-path"

    mkdir -p "$first_dir" "$second_dir"
    make_executable "$first_target"
    make_executable "$second_target"
    make_recording_editor "$editor" "$opened"

    run bash -c 'printf "2\n" | PATH="$1:$2:$PATH" HOME="$3" VISUAL= EDITOR= "$4" -e "$5" -a dupe' \
        _ "$first_dir" "$second_dir" "$TEST_HOME" "$EXED" "$editor"

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$opened")" = "$second_target" ]
}

@test "default mode refuses missing executables" {
    run env PATH="$PATH_FIXTURES:$PATH" HOME="$TEST_HOME" VISUAL= EDITOR= \
        "$EXED" -e true definitely-not-an-exed-test-executable

    [ "$status" -eq 1 ]
    [[ $output == *"Executable [definitely-not-an-exed-test-executable] either does not exist, or is not executable."* ]]
}

@test "paths with slashes must be executable" {
    local target="$BATS_TEST_TMPDIR/local-file"

    printf '%s\n' "not executable" > "$target"
    run exed -e true "$target"

    [ "$status" -eq 1 ]
    [[ $output == *"either does not exist, or is not executable"* ]]
}

@test "create mode creates a bash executable with default permissions" {
    local file="$BATS_TEST_TMPDIR/bash-script"

    run exed -e true -c -C "$file"

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$file")" = "#!$BASH_PATH" ]
    [ "$(file_mode "$file")" = "755" ]
}

@test "create mode supports language, env shebangs, and interpreter options" {
    local file="$BATS_TEST_TMPDIR/env-script"

    run exed -e true -c -C -n -l ksh -o -x "$file"

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$file")" = "#!$ENV_PATH ksh -x" ]
}

@test "custom interpreter creates a shebang without requiring the interpreter to exist" {
    local file="$BATS_TEST_TMPDIR/custom-script"

    run exed -e true -c -C -i /tmp/not-real-interpreter "$file"

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$file")" = "#!/tmp/not-real-interpreter" ]
}

@test "create mode renders a built-in language template" {
    local file="$BATS_TEST_TMPDIR/strict-script"

    run exed -e true -c -C -l bash -t strict "$file"

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$file")" = "#!$BASH_PATH" ]
    [ "$(line_at 2 "$file")" = "set -euo pipefail" ]
    [ "$(line_at 3 "$file")" = "IFS=\$'\\n\\t'" ]
}

@test "user templates override built-in templates for the same language and name" {
    local file="$BATS_TEST_TMPDIR/user-strict-script"
    local templates="$BATS_TEST_TMPDIR/templates"

    mkdir -p "$templates/bash"
    {
        printf '%s\n' "{{shebang}}"
        printf '%s\n' "echo user strict"
    } > "$templates/bash/strict"
    printf 'template_dir=%q\n' "$templates" > "$TEST_HOME/.exedrc"

    run exed -e true -c -C -l bash -t strict "$file"

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$file")" = "#!$BASH_PATH" ]
    [ "$(line_at 2 "$file")" = "echo user strict" ]
}

@test "templates without a shebang token get a prepended shebang" {
    local file="$BATS_TEST_TMPDIR/prepended-script"
    local templates="$BATS_TEST_TMPDIR/templates"

    mkdir -p "$templates/bash"
    printf '%s\n' 'echo "{{language}} {{file}}"' > "$templates/bash/body"
    printf 'template_dir=%q\n' "$templates" > "$TEST_HOME/.exedrc"

    run exed -e true -c -C -l bash -t body "$file"

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$file")" = "#!$BASH_PATH" ]
    [ "$(line_at 2 "$file")" = "" ]
    [ "$(line_at 3 "$file")" = "echo \"bash $file\"" ]
}

@test "templates are language-scoped and missing templates fail" {
    local file="$BATS_TEST_TMPDIR/missing-template-script"

    run exed -e true -c -C -l bash -t cli "$file"

    [ "$status" -eq 1 ]
    [[ $output == *"Template [cli] for language [bash] was not found."* ]]
    [ ! -e "$file" ]
}

@test "templates can be listed across built-ins and configured user templates" {
    local templates="$BATS_TEST_TMPDIR/templates"

    mkdir -p "$templates/bash" "$templates/fish"
    printf '%s\n' "echo user strict" > "$templates/bash/strict"
    printf '%s\n' "echo swim" > "$templates/fish/default"
    printf 'template_dir=%q\n' "$templates" > "$TEST_HOME/.exedrc"

    run exed -L

    [ "$status" -eq 0 ]
    [[ $output == *"bash:"* ]]
    [[ $output == *"  strict"* ]]
    [[ $output == *"fish:"* ]]
    [[ $output == *"  default"* ]]
    [[ $output != *"awk:"* ]]
}

@test "template listing can be scoped by language" {
    run exed -l python -L

    [ "$status" -eq 0 ]
    [[ $output == *"python:"* ]]
    [[ $output == *"  cli"* ]]
    [[ $output != *"bash:"* ]]
}

@test "selected templates can be previewed without creating a file" {
    local file="$BATS_TEST_TMPDIR/preview-script"

    run exed -l bash -t strict -P "$file"

    [ "$status" -eq 0 ]
    [[ $output == *"#!$BASH_PATH"* ]]
    [[ $output == *"set -euo pipefail"* ]]
    [[ $output == *"IFS=\$'\\n\\t'"* ]]
    [ ! -e "$file" ]
}

@test "preview mode can be added to create mode without creating a file" {
    local file="$BATS_TEST_TMPDIR/create-preview-script"

    run exed -e false -c -C -l bash -t strict -P "$file"

    [ "$status" -eq 0 ]
    [[ $output == *"Preview mode: file not created."* ]]
    [[ $output == *"set -euo pipefail"* ]]
    [ ! -e "$file" ]
}

@test "configured templates can be previewed and unset for previews" {
    printf '%s\n' "template=strict" > "$TEST_HOME/.exedrc"

    run exed -l bash -P

    [ "$status" -eq 0 ]
    [[ $output == *"set -euo pipefail"* ]]

    run exed -l bash -T -P

    [ "$status" -eq 1 ]
    [[ $output == *"No template selected to preview."* ]]
}

@test "list and preview modes cannot be combined" {
    run exed -L -P

    [ "$status" -eq 1 ]
    [[ $output == *"-L cannot be used with -P."* ]]
}

@test "configured templates can be unset at runtime" {
    local file="$BATS_TEST_TMPDIR/unset-template-script"

    printf '%s\n' "template=strict" > "$TEST_HOME/.exedrc"

    run exed -e true -c -C -l bash -T "$file"

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$file")" = "#!$BASH_PATH" ]
    [ "$(line_at 2 "$file")" = "" ]
}

@test "IFS line is written only for compatible shells" {
    local file="$BATS_TEST_TMPDIR/ifs-script"

    run exed -e true -c -C -I -l bash "$file"

    [ "$status" -eq 0 ]
    [ "$(line_at 2 "$file")" = "IFS=\$'\\n'" ]

    run exed -e true -c -C -I -l sh "$file"

    [ "$status" -eq 1 ]
    [[ $output == *"'-I' is only compatible with bash and zsh"* ]]
}

@test "IFS validation runs before interpreter resolution" {
    local file="$BATS_TEST_TMPDIR/fish-script"

    run exed -e true -c -I -l fish "$file"

    [ "$status" -eq 1 ]
    [[ $output == *"'-I' is only compatible with bash and zsh"* ]]
    [[ $output != *"[fish] is not supported"* ]]
}

@test "creation options require create mode" {
    run exed -e true -l bash bash

    [ "$status" -eq 1 ]
    [[ $output == *"Creation options can only be used with -c."* ]]
}

@test "all matches cannot be used with create mode" {
    run exed -e true -a -c script

    [ "$status" -eq 1 ]
    [[ $output == *"-a cannot be used with -c."* ]]

    run exed -a -c -l bash -t strict -P script

    [ "$status" -eq 1 ]
    [[ $output == *"-a cannot be used with -c."* ]]
}

@test "no-clobber refuses existing files in create mode" {
    local file="$BATS_TEST_TMPDIR/existing-script"

    printf '%s\n' "already here" > "$file"
    run exed -e true -c -B "$file"

    [ "$status" -eq 1 ]
    [[ $output == *"already exists and 'No-Clobber' is set"* ]]
    [ "$(line_at 1 "$file")" = "already here" ]
}

@test "configuration defaults are loaded from exedrc" {
    local file="$BATS_TEST_TMPDIR/config-script"

    {
        printf '%s\n' "language=bash"
        printf '%s\n' "editor=true"
        printf '%s\n' "perms=700"
        printf '%s\n' "env=true"
        printf '%s\n' "set_ifs=true"
        printf '%s\n' "clobber_mode=clobber"
    } > "$TEST_HOME/.exedrc"

    run exed -c "$file"

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$file")" = "#!$ENV_PATH bash" ]
    [ "$(line_at 2 "$file")" = "IFS=\$'\\n'" ]
    [ "$(file_mode "$file")" = "700" ]
}

@test "configured editor accepts flags before the opened file" {
    local target="$PATH_FIXTURES/config-existing"
    local editor="$BATS_TEST_TMPDIR/config-record-editor-args"
    local opened="$BATS_TEST_TMPDIR/config-opened-args"

    make_executable "$target"
    make_arg_recording_editor "$editor" "$opened"
    printf 'editor=%q\n' "$editor --wait" > "$TEST_HOME/.exedrc"

    run env PATH="$PATH_FIXTURES:$PATH" HOME="$TEST_HOME" VISUAL= EDITOR= \
        "$EXED" config-existing

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$opened")" = "--wait" ]
    [ "$(line_at 2 "$opened")" = "$target" ]
}

@test "VISUAL fallback accepts flags before the opened file" {
    local target="$PATH_FIXTURES/visual-existing"
    local editor="$BATS_TEST_TMPDIR/visual-record-editor-args"
    local opened="$BATS_TEST_TMPDIR/visual-opened-args"

    make_executable "$target"
    make_arg_recording_editor "$editor" "$opened"

    run env PATH="$PATH_FIXTURES:$PATH" HOME="$TEST_HOME" VISUAL="$editor --wait" EDITOR= \
        "$EXED" visual-existing

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$opened")" = "--wait" ]
    [ "$(line_at 2 "$opened")" = "$target" ]
}

@test "permissions must give the owner execute permission" {
    local private_file="$BATS_TEST_TMPDIR/private-script"
    local unusual_file="$BATS_TEST_TMPDIR/unusual-script"
    local non_executable_file="$BATS_TEST_TMPDIR/non-executable-script"

    run exed -e true -c -C -m 700 "$private_file"
    [ "$status" -eq 0 ]
    [ "$(file_mode "$private_file")" = "700" ]

    run exed -e true -c -C -m 577 "$unusual_file"
    [ "$status" -eq 0 ]
    [ "$(file_mode "$unusual_file")" = "577" ]

    run exed -e true -c -C -m 644 "$non_executable_file"
    [ "$status" -eq 1 ]
    [[ $output == *"must give the owner execute permission"* ]]
    [ ! -e "$non_executable_file" ]
}

@test "explicit default assignment syntax is used instead of colon assignment" {
    run grep -F ': "${' "$EXED"

    [ "$status" -eq 1 ]
}
