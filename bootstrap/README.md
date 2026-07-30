# bootstrap

Reproduce this `~/.config` on an Ubuntu machine, and keep its pinned versions
current. Two commands do almost everything:

```sh
~/.config/bootstrap/bs.sh          # set up, or repair, the machine
~/.config/bootstrap/bs.sh update   # bump every pin, then review the git diff
```

Both are idempotent and safe to re-run.

## Commands

| | |
| --- | --- |
| `bs.sh` | run every step in order (this is `bs.sh install`) |
| `bs.sh update` | resolve the latest version of everything pinned and rewrite the manifests |
| `bs.sh doctor` | report where this machine differs from the manifests; exits 1 if it does |
| `bs.sh list` | list the steps, and which need root |

Options: `--only ID,…` and `--skip ID,…` (prefix match, so `--only tool:` picks
every tool), `--dry-run`, `--no-sudo`, `--arch ARCH`, and `--check` for `update`.

```sh
bs.sh --only tool:              # reinstall the pinned binaries
bs.sh --only tool:fzf           # just one
bs.sh --skip nvim:plugins       # skip the slow one
bs.sh update --check            # is anything behind upstream?
bs.sh update starship           # bump one thing
```

## Updating versions

```sh
bs.sh update       # rewrites the manifests
git diff           # see exactly what moved
git commit -am 'Bump pins'
bs.sh              # install it
```

Nothing is bumped behind your back: `bs.sh` only ever installs what the
committed manifests say. `update` is the one command that changes them, and it
leaves the result as a reviewable diff.

## Layout

```
bs.sh          the driver: argument parsing, step dispatch, doctor, update
lib.sh         everything the steps share (logging, versions, downloads, PATH)
tools.tsv      prebuilt binaries from GitHub releases -> ~/.local/bin
apt.tsv        apt package set, by group
runtimes.tsv   nvim / node / pnpm / go / rust, each via its own manager
steps/*.sh     one file per concern, run in filename order
cleanup.sh     retire files that are no longer read (opt-in, moves not deletes)
test/          run the whole thing in a clean ubuntu:24.04 container
```

### Adding a tool

If it is a binary from a GitHub release, add one line to `tools.tsv`. Nothing
else — the step, the `--only` id, the doctor row and `update` support all follow
from the manifest.

```
name	ref	min	repo	asset	install
```

`ref` is the upstream release tag **verbatim**, because upstreams disagree about
the `v` prefix (sheldon and uv publish `0.8.5`, everyone else `v0.8.5`).
`{VERSION}` in `asset` is that tag with a leading `v` stripped; the other
placeholders are listed at the top of the file.

Anything more involved than "download and unpack" gets a step in `steps/`. A step
is a shell function plus a one-line `register` call; see `steps/30-zdotdir.sh`
for the smallest example.

## Why these versions are pinned, and these are not

**Pinned** — the release binaries, nvim, node, pnpm, go, the zsh plugins
(`sheldon/plugins.toml`), and the neovim plugin tree (`nvim/lazy-lock.json`).
These are what the configuration actually invokes; a surprise major bump changes
the prompt, the keybindings or the plugin loader. Pinning them is cheap because
`bs.sh update` bumps them all at once.

**Not pinned, deliberately:**

- **apt packages.** Ubuntu's archive removes superseded versions, so
  `ripgrep=14.1.1-1` starts failing the moment noble-updates rotates the
  package. A pin here would reduce reproducibility. `apt.tsv` fixes the *set*.
- **yt-dlp.** An old yt-dlp fails against site changes. `latest` is the
  reproducible choice here, and it says so explicitly in the manifest.
- **rust.** Nothing here depends on a rustc version, and re-downloading a ~200MB
  toolchain per bump is not worth it. `min` still catches an ancient one.

**Known limit: Mason's LSP servers are not pinned.** `mason.nvim` has no
lockfile, so the servers `nvim/lua/config/plugins/lsp.lua` asks for install at
whatever version Mason's registry offers that day. Pinning them would mean
`ensure_installed = { "lua_ls@3.7.4" }` or adding a plugin like
`mason-lock.nvim`. Treesitter parsers *are* effectively pinned, because they
compile from the `nvim-treesitter` commit in `lazy-lock.json`.

## Root

Four steps need it: `apt:base`, `apt:cpp`, `apt:media`, `gh`, `locale`,
`zdotdir` and `shell`. They elevate individual commands; **do not run `bs.sh`
itself under sudo** — it would install into `/root/.local`, and it refuses.

`--no-sudo` skips them and everything else still runs, then prints the command to
finish the job later. The locale step also has a rootless path: it compiles into
`$XDG_DATA_HOME/locale`, which `zsh/.zshenv` picks up via `LOCPATH`.

## Testing

```sh
shellcheck -x bootstrap/bs.sh bootstrap/lib.sh bootstrap/steps/*.sh bootstrap/cleanup.sh
bs.sh --dry-run                    # prints every mutation, performs none
bs.sh --dry-run --arch riscv64     # unsupported arch must skip, not fail
bootstrap/test/container.sh        # the real one; --fast skips the nvim plugins
```

`container.sh` pipes `git archive HEAD` into a clean `ubuntu:24.04` with a
sudo-capable non-root user, runs the bootstrap, and then checks that a second run
downloads nothing, that no tracked file was modified, that zsh starts silently,
and that `doctor` passes. Only tracked files go in, so nothing untracked in
`~/.config` — the gh token, shell history — reaches the container.

## WSL

- Windows terminals do not read Linux-side fonts. Cica has to be installed on
  the Windows side too; `bs.sh` prints where the TTFs are and where to copy them.
- The `/mnt/*` PATH pruning belongs to `zsh/.zshenv`, not here. `doctor` reports
  how many entries survive so a regression of that ~80ms saving is visible.
  Setting `appendWindowsPath=false` in `/etc/wsl.conf` would make the pruning
  unnecessary, but also removes `code`, `clip.exe`, `explorer.exe` and `winget`,
  which the keep-list in `.zshenv` preserves on purpose.
