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
    HOME="$TEST_HOME" FCEDIT= VISUAL= EDITOR= "$EXED" "$@" 2>&1
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

@test "default mode opens first executable found in PATH" {
    local target="$PATH_FIXTURES/existing"
    local opened="$BATS_TEST_TMPDIR/opened"

    make_executable "$target"

    run env PATH="$PATH_FIXTURES:$PATH" HOME="$TEST_HOME" FCEDIT= VISUAL= EDITOR= \
        "$EXED" -e "touch $opened" existing

    [ "$status" -eq 0 ]
    [ -e "$opened" ]
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

    run bash -c 'printf "2\n" | PATH="$1:$2:$PATH" HOME="$3" FCEDIT= VISUAL= EDITOR= "$4" -e "$5" -a dupe' \
        _ "$first_dir" "$second_dir" "$TEST_HOME" "$EXED" "$editor"

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$opened")" = "$second_target" ]
}

@test "default mode refuses missing executables" {
    run env PATH="$PATH_FIXTURES:$PATH" HOME="$TEST_HOME" FCEDIT= VISUAL= EDITOR= \
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

@test "IFS line is written only for compatible shells" {
    local file="$BATS_TEST_TMPDIR/ifs-script"

    run exed -e true -c -C -I -l bash "$file"

    [ "$status" -eq 0 ]
    [ "$(line_at 2 "$file")" = "IFS=\$'\\n'" ]
}

@test "IFS validation runs before interpreter resolution" {
    local file="$BATS_TEST_TMPDIR/fish-script"

    run exed -e true -c -I -l fish "$file"

    [ "$status" -eq 1 ]
    [[ $output == *"'-I' is only compatible with bash, sh, and zsh"* ]]
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
        printf '%s\n' "setifs=true"
        printf '%s\n' "clobber_mode=clobber"
    } > "$TEST_HOME/.exedrc"

    run exed -c "$file"

    [ "$status" -eq 0 ]
    [ "$(line_at 1 "$file")" = "#!$ENV_PATH bash" ]
    [ "$(line_at 2 "$file")" = "IFS=\$'\\n'" ]
    [ "$(file_mode "$file")" = "700" ]
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
