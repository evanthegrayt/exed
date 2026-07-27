#!/usr/bin/env sh
set -eu

PROGRAM=exed

usage() {
    cat <<'EOF'
USAGE: ./install.sh [OPTIONS]

Install exed as a standalone executable.

OPTIONS
  --prefix DIR        Install under DIR (default: /usr/local)
  --user              Install under $HOME/.local
  --copy              Copy files instead of symlinking
  --force             Replace existing installed files
  --no-completions    Do not install shell completions
  --no-man            Do not install the man page
  -h, --help          Print this help and exit
EOF
}

abspath_dir() {
    cd "$1" >/dev/null 2>&1
    pwd -P
}

install_one() {
    src=$1
    dest=$2
    mode=$3

    mkdir -p "$(dirname "$dest")"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$force" = false ]; then
            printf '%s\n' "Refusing to replace existing file: $dest" >&2
            printf '%s\n' "Re-run with --force to replace it." >&2
            exit 1
        fi
        rm -f "$dest"
    fi

    if [ "$copy" = true ]; then
        cp "$src" "$dest"
        chmod "$mode" "$dest"
    else
        ln -s "$src" "$dest"
    fi

    printf '%s\n' "Installed $dest"
}

install_tree() {
    src=$1
    dest=$2

    mkdir -p "$(dirname "$dest")"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$force" = false ]; then
            printf '%s\n' "Refusing to replace existing file: $dest" >&2
            printf '%s\n' "Re-run with --force to replace it." >&2
            exit 1
        fi
        rm -rf "$dest"
    fi

    if [ "$copy" = true ]; then
        mkdir -p "$dest"
        cp -R "$src/." "$dest"
        find "$dest" -type f -exec chmod 644 {} +
    else
        ln -s "$src" "$dest"
    fi

    printf '%s\n' "Installed $dest"
}

path_contains() {
    case ":$1:" in
        *":$2:"*) return 0 ;;
        *) return 1 ;;
    esac
}

prefix=/usr/local
copy=false
force=false
install_completions=true
install_man=true

while [ "$#" -gt 0 ]; do
    case $1 in
        --prefix)
            [ "$#" -gt 1 ] || {
                printf '%s\n' "--prefix requires a directory." >&2
                exit 1
            }
            prefix=$2
            shift 2
            ;;
        --prefix=*)
            prefix=${1#--prefix=}
            shift
            ;;
        --user)
            prefix=$HOME/.local
            shift
            ;;
        --copy)
            copy=true
            shift
            ;;
        --force)
            force=true
            shift
            ;;
        --no-completions)
            install_completions=false
            shift
            ;;
        --no-man)
            install_man=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf '%s\n' "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

repo_dir=$(abspath_dir "$(dirname "$0")")
prefix=$(mkdir -p "$prefix" && abspath_dir "$prefix")

install_one "$repo_dir/bin/$PROGRAM" "$prefix/bin/$PROGRAM" 755
install_tree "$repo_dir/share/$PROGRAM/templates" "$prefix/share/$PROGRAM/templates"

if [ "$install_man" = true ]; then
    install_one "$repo_dir/man/man1/$PROGRAM.1" "$prefix/share/man/man1/$PROGRAM.1" 644
fi

if [ "$install_completions" = true ]; then
    install_one \
        "$repo_dir/share/zsh/site-functions/_$PROGRAM" \
        "$prefix/share/zsh/site-functions/_$PROGRAM" \
        644
    install_one \
        "$repo_dir/share/bash-completion/completions/$PROGRAM" \
        "$prefix/share/bash-completion/completions/$PROGRAM" \
        644
fi

printf '\n%s\n' "Next steps:"

if ! path_contains "${PATH:-}" "$prefix/bin"; then
    printf '  Add %s to PATH.\n' "$prefix/bin"
fi

if [ "$install_man" = true ] && command -v man >/dev/null 2>&1; then
    if ! man -w "$PROGRAM" >/dev/null 2>&1; then
        printf '  If man cannot find exed, add %s to MANPATH.\n' "$prefix/share/man"
    fi
fi

if [ "$install_completions" = true ]; then
    printf '  For zsh completion, ensure %s is in fpath before compinit.\n' "$prefix/share/zsh/site-functions"
    printf '  For bash completion, source %s when your system does not load it automatically.\n' "$prefix/share/bash-completion/completions/$PROGRAM"
fi
