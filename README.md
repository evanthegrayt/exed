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
- `perms=MODE` (three-digit chmod-style permissions where the owner can execute,
  such as `755` or `700`)
- `env=true` (same as passing `-n`)
- `clobber=true` (same as passing `-C`)
- `clobber_mode=clobber`, `clobber_mode=noclobber`, or
  `clobber_mode=interactive`
- `set_ifs=true` (same as passing `-I`)

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
