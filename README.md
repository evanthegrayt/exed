# Executable Editor
In short, `exed FILE` finds `FILE` in your path and opens it in your editor.

With `exed -c -l LANGUAGE -m PERMS FILE`, it creates `FILE`, writes an
interpreter line for `LANGUAGE` at the top, applies executable `PERMS` via
`chmod`, and opens the file in your editor. Users can create templates for
generated scripts and can be specified at runtime.

Defaults can be set, so creating a script can be as simple as `exed -c FILE`.

More details are in the [usage](#usage) section of this file. After installing, view
help with `-h` or the manual with `man exed`.

## Installation
Clone the repository, `cd` into the base directory, and run the installer:

```sh
git clone https://github.com/evanthegrayt/exed.git
cd exed
./install.sh
```

By default, the installer symlinks the executable, templates, man page, and
completion files under `/usr/local`:

```text
/usr/local/bin/exed
/usr/local/share/exed/templates
/usr/local/share/man/man1/exed.1
/usr/local/share/zsh/site-functions/_exed
/usr/local/share/bash-completion/completions/exed
```

Use `./install.sh --user` to install under `$HOME/.local`, or
`./install.sh --prefix DIR` to choose another prefix. Run `./install.sh --help`
for all installer options.

Manual installation is also fine:

```sh
ln -s "$PWD/bin/exed" /usr/local/bin/exed
ln -s "$PWD/man/man1/exed.1" /usr/local/share/man/man1/exed.1
```

## Shell Plugins
`exed` can be used as a shell plugin for zsh or bash. The plugin files are
sourceable setup layers: they add this repository's `bin` directory to `PATH`
and register completion. They do not source the executable itself.

For zsh:

```sh
source /path/to/exed/exed.plugin.zsh
```

For bash:

```sh
source /path/to/exed/exed.plugin.bash
```

For Oh My Zsh, clone this repository into the custom plugin directory and add
`exed` to the `plugins=(...)` list:

```sh
git clone https://github.com/evanthegrayt/exed.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/exed"
```

For Bash-it, use `exed.plugin.bash` as the plugin file.

## Completion
Completion files can be used without a shell plugin:

```text
share/zsh/site-functions/_exed
share/bash-completion/completions/exed
```

For zsh, place `share/zsh/site-functions` in `fpath` before `compinit` runs.
For bash, source `share/bash-completion/completions/exed` or install it where
your system's bash-completion setup loads command completions.

## Usage
Open an executable that already exists in your `PATH`:

```sh
exed my_shell_script
```

Create a new executable file:

```sh
exed -c my_script
exed -c -l ruby my_ruby_script
```

Useful options:

- `-a`: find all matching executables in `PATH` and choose one
- `-c`: create a file instead of finding one
- `-e EDITOR`: choose an editor
- `-l LANGUAGE`: choose the language for a created file
- `-m MODE`: choose permissions for a created file
- `-n`: use `env` from `PATH` with `LANGUAGE` for a created file
- `-t TEMPLATE`: use a language-scoped template for a created file
- `-T`: unset a configured `template=NAME`
- `-L`: list available templates
- `-P`: preview the selected template
- `-I`: add `IFS=$'\n'` for created `bash` or `zsh` files
- `-v`: print the executable location before opening it

Interpreter lines are resolved from your current `PATH` by default. For example,
`exed -c -l bash script` writes the path returned by `command -v bash`. If your
`PATH` finds a custom Bash installation first, but you specifically want
`#!/bin/bash`, pass `-i /bin/bash`.

Run `exed -h` to see all available options.

Templates are searched by language and name. For example:

```sh
exed -c -l bash -t strict my_bash_script
exed -c -l ruby -t cli my_ruby_script
exed -L
exed -l bash -L
exed -l bash -t strict -P
```

With `-l bash -t strict`, `exed` looks for `bash/strict`; it does not search
templates for other languages. If `template_dir=DIR` is configured, `exed`
checks `DIR/LANGUAGE/TEMPLATE` before the built-in
`share/exed/templates/LANGUAGE/TEMPLATE`, so personal templates can override
the built-ins. Built-in templates are reserved for useful scaffolds beyond the
standard generated shebang. Templates are plain text files and may include `{{shebang}}`,
`{{language}}`, and `{{file}}`. When `{{shebang}}` is omitted, `exed` prepends
the interpreter line automatically.

Use `-L` to list templates, optionally scoped by `-l LANGUAGE`. Use `-P` to
render the selected or configured template to standard output without creating
or opening a file. If `-P` is added to a create command, `exed` previews the
rendered file and prints a warning instead of writing, chmodding, or opening it.

Editor values can include simple flags. For example:

```sh
exed -e "code -w" my_script
exed -e "vim -p" my_script
```

## Environment Variables
If no editor is passed with `-e`, `exed` will check your environment for
`$VISUAL`, and `$EDITOR`, in that order. It is recommended to use these
variables, as it's the *nix standard. If, for some reason, you want to specify a
certain editor specifically for exed, you can set `editor=EDITOR` in the
[configuration file](#configuration-file).

If none of the above are set, `exed` falls back to `vi`.

## Configuration File
`exed` accepts a configuration file where you can set default variables. Create
a file in your home directory called `.exedrc`. Available variables:

- `all_in_path=true` (same as passing `-a`)
- `editor=EDITOR`
- `verbose=true` (same as passing `-v`)
- `language=LANGUAGE`
- `template=NAME`
- `template_dir=DIR`
- `perms=MODE` (three-digit chmod-style permissions where the owner can execute,
  such as `755` or `700`)
- `env=true` (same as passing `-n`)
- `clobber=true` (same as passing `-C`)
- `clobber_mode=clobber`, `clobber_mode=noclobber`, or
  `clobber_mode=interactive`
- `set_ifs=true` (same as passing `-I`)

The `editor` value can also include simple flags, such as:

```sh
editor="code -w"
editor="vim -p"
```

All boolean values are `false` by default. Any variables set in the
configuration file can be overwritten by flags when initiating the program. For
example, `-N` unsets a configured `env=true`, and `-O` restores the default
interactive overwrite prompt if clobbering is configured.

## Testing
Run the test suite with:

```sh
bats test
```

## Reporting Bugs and Requesting Features
If you have an idea or find a bug, please [create an
issue](https://github.com/evanthegrayt/exed/issues/new). Just make sure
the topic doesn't already exist. Better yet, you can always submit a Pull
Request.

## Support this project
I love knowing when people find my work useful. Any kind of support is very much
appreciated!

- ⭐️ Like the project? Star [the repository](https://github.com/evanthegrayt/exed)!
- ❤️ Love the project? Follow me [on GitHub](https://github.com/evanthegrayt)!
- 💸 *Really* love it? Consider [buying me a tea](https://paypal.me/evanrgray)!
