# opencode-box

A single tool to manage a "box": an isolated Ubuntu environment for safely
testing **opencode**, with no risk to your system.

## Installation

```
sudo dpkg -i dist/opencode-box_1.0.0_all.deb
```

## Prerequisites

- **Docker** (`docker.io` or `docker-ce`) — install it first, for example:
  `sudo apt install docker.io`

The package does not install it itself.

## Usage

- `opencode-box install` creates the box (an Ubuntu container).
- Once inside the box, you need to install `opencode` (for example with
  `curl -fsSL https://opencode.ai/install | bash`).
- `opencode-box up` points the working directory to `$PWD`, starts the box and
  enters it.
- `opencode-box exe` runs a shell in the box as the current user.
- `opencode-box down` stops the box.

```
opencode-box install     Create the box
opencode-box uninstall   Remove the box
opencode-box up          Point workdir to $PWD, start the box and enter it
opencode-box down        Stop the box
opencode-box exe         Run a shell in the box (current user)
opencode-box root        Run a shell in the box (administrator)
opencode-box help        Show help
```

**Note on copy/paste:** with its TUI (terminal UI), opencode captures the
mouse, which prevents selecting text with it — a known problem when running
opencode inside Docker. To be able to select and copy text with the mouse, set
the environment variable:

```
export OPENCODE_DISABLE_MOUSE=true
```

Place this line in the box's shell startup file (for example `~/.bashrc`,
since the box uses `bash`) so it is applied on every connection to the box.

## Technical details

- The box is a completely isolated Ubuntu environment (image `ubuntu:24.04`):
  anything that happens inside does not affect your machine.
- `opencode` is not in the box: it must be installed after the box is
  created. Installing it with `root` (as administrator) makes it available to
  all users, but that is not required.
- `install` mounts the `~/opencode-work` directory in the box, at `/work`.
- `~/opencode-work` is a symbolic link to the current directory: `up`
  re-points it to `$PWD` before starting the box, so the share follows the
  directory you are in.
- `exe` and `up` open a terminal with your user (same uid/gid as on the host
  machine); `root` opens a terminal as administrator in the box.