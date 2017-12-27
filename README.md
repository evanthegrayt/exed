# executable-editor
Quickly edit an executable script in your `$PATH`

# Installation
Clone the repo.

```bash
git clone https://github.com/evanthegrayt/executable-editor.git
```

Either add the `bin` to your `PATH`, move the file into your existing `PATH`, or
create an alias.

```bash
export PATH=INSTALLATION_PATH/bin:$PATH
# or
mv INSTALLATION_PATH/bin/exed /usr/local/bin
# or
alias exed INSTALLATION_PATH/bin/exed
```

Add the manual direcotry to your manpath.

```bash
export MANPATH=$MANPATH:INSTALLATION_PATH/executable-editor/man
```

In both instances, replace `INSTALLATION_PATH` with the correct path.

# Usage
Once instaled, simply type `exed [EXECUTABLE FILE NAME]` to quickly edit an
executable in your `PATH`.

For available options, run `exed -h`, or if you correctly installed the `man`
page, run `man exed`.

This script can source a file called `~/.exedrc`, where you can set some default
options, such as
```bash
verbose=true       # run in verbose mode
all_in_path=true   # show all instances in $PATH; let user choose which to edit
```

