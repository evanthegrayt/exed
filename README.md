# Executable Editor
`exed` opens executable scripts in your editor.

By default, it finds an existing executable in your `PATH` and opens it. With
`-c`, it creates a new executable file, writes an interpreter line, applies
executable permissions, and opens the file in your editor.

## Installation
Clone the repository, `cd` into the base directory, and link the executable into
your path:

```sh
git clone https://github.com/evanthegrayt/exed.git
cd exed
ln -s "$PWD/bin/exed" /usr/local/bin/exed
```

## Usage
Open an executable that already exists in your `PATH`:

```sh
exed ruby
```

Create a new executable file:

```sh
exed -c script
exed -c -l ruby ruby_script
```

Useful options:

- `-a`: find all matching executables in `PATH` and choose one
- `-c`: create a file instead of finding one
- `-e EDITOR`: choose an editor
- `-l LANGUAGE`: choose the language for a created file
- `-m MODE`: choose permissions for a created file
- `-n`: use `/usr/bin/env LANGUAGE` for a created file
- `-I`: add `IFS=$'\n'` for created `bash`, `sh`, or `zsh` files
- `-v`: print the executable location before opening it

Run `exed -h` to see all available options.

## Environment Variables
If no editor is passed with `-e`, `exed` will check your environment for
`$FCEDIT`, `$VISUAL`, and `$EDITOR`, in that order. If none are set, it will
fall back to `vim`.

If you want to set a default editor, add something like this to your shell
configuration.

```sh
export VISUAL=code # Make VSCode your default graphical editor.
```

## Configuration Files
`exed` accepts a configuration file where you can set default variables. Create
a file in your home directory called `.exedrc`. Available variables:

- `all_in_path=true` (same as passing `-a`)
- `editor=EDITOR`
- `verbose=true` (same as passing `-v`)
- `language=LANGUAGE`
- `perms=MODE` (three-digit chmod-style permissions where the owner can execute,
  such as `755` or `700`)
- `env=true` (same as passing `-n`)
- `clobber=true` (same as passing `-C`)
- `clobber_mode=clobber`, `clobber_mode=noclobber`, or
  `clobber_mode=interactive`
- `setifs=true` (same as passing `-I`)

All boolean values are `false` by default. Any variables set in the
configuration file can be overwritten by flags when initiating the program. For
example, `-N` unsets a configured `env=true`, and `-O` restores the default
interactive overwrite prompt if clobbering is configured.

## Testing
Run the test suite with:

```sh
bats test
```

## Reporting Bugs
To report bugs, please create an issue in the repository.
