# ToolBag

ToolBag is a script to help packaging *stuff* to bring it around.

The typical use case is when you have to pack a few tools, scripts and
files (e.g. configuration files) so that you can bring them with
a single package where you have to do some activity.

## Installation

Just download it, set executable and put in `PATH`. You will need the
following tools around:

- a POSIX shell and "normal" tooling you would expect to find in
  a shell, plus something like `mktemp` and `wget`. [BusyBox][] contains
  everything needed in case and is also available as a statically linked
  binary;
- `jq`: this is needed to parse the configuration file. It should not be
  a big deal, you can get it as a [statically linked
  binary](https://stedolan.github.io/jq/download/);
- `git`: if you want to include Git repositories, otherwise you can do
  without.

## Usage

~~~~
toolbag.sh [-c|--clone] [-i|--input <filename>]
~~~~


`toolbag` supports the following options:

- `-c`/`--clone`: for git repositories, re-clone them even if they are
  already present (by default `git fetch` would be called instead). This
  can be useful if tags were removed and/or commits were force-pushed to
  the central repository. Implementation-wise, when this option is
  present the fresh clone is saved into a temporary directory and any
  cache present in the current directory is ignored.

- `-i`/`--input`: set the input JSON file, to be used instead of
  standard input.



## Configuration

The configuration file is in JSON format, at the higher leve it is an
object with the following keys:

- `target`: set the name of the target, which is used verbatim as the
  high level directory name, as well as a base for the `.tar.gz` archive
  produced

- `tools`: an array of objects, each containing the configuration for
  a specific element to be added in the final archive. All these
  configurations are processed in the order as they appear, so later
  elements can override parts of previous elements.

A configuration for an element to be added is an object that contains
*at least* the following keys:

- `type`: the type of the element, see below for the different available
  options;
- `prefix`: a prefix to pre-pend to the elements to be added, in
  practice it is a sub-directory name.

Key `type`, which can be:

- `git`: a git repository. Other keys supported are:

    - `url`: the url where the git repository is located. Whatever `git`
      can use as an origin to clone from is fine, even a local path;
    - `ref`: a reference in the repository to get data from.

- `tar`: a tar archive (optionally compressed). Other supported keys
  are:
    - `url`: the URL to the file (URL are downloaded with `wget`);
    - `file`: the path to the local file OR (if `url` is provided) the
      path to where the file will be saved locally.

- `file`: a single file. Other supported keys are:
    - `url`: the URL to the file (URL are downloaded with `wget`);
    - `file`: the path to the local file OR (if `url` is provided) the

- `dir`: a (local) directory. Other supported keys are:
    - `dir`: the path to the directory.

Local paths are either absolute or relative to the current directory.

## Example

~~~~
{
   "target": "teepee-stuff",
   "tools": [
      {
         "type": "git",
         "url": "https://github.com/polettix/teepee.git",
         "ref": "remotes/origin/master",
         "prefix": "teepee-master"
      },
      {
         "type": "file",
         "url": "https://github.com/polettix/teepee/raw/master/bundle/teepee"
      },
      {
         "type": "tar",
         "url": "https://github.com/polettix/teepee/archive/0.7.1.tar.gz"
      }
   ]
}
~~~~

[BusyBox]: https://busybox.net/
