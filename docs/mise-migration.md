# Migrating tool management to mise

## Part 1 — How mise works

### One binary, three jobs

`mise` (mise-en-place) replaces three separate tools at once:

| Job | What it replaces | Where it's configured |
|---|---|---|
| Dev tool versions | asdf, nvm, pyenv, rustup, tfenv, hand-rolled `curl \| tar` | `[tools]` |
| Directory-scoped env vars | direnv | `[env]` |
| Task running | make, `go-task`, shell scripts | `[tasks]` |

We are only migrating the first of these in this plan. The other two are noted at the end
as follow-on opportunities.

### Config hierarchy

mise reads a **merged stack** of TOML files, nearest-wins, walking up from `$PWD`:

```
./mise.local.toml          ← machine-local, gitignored
./mise.toml                ← project
../mise.toml               ← every parent dir, all the way up
~/.config/mise/config.toml ← global (this is the one we'll stow)
/etc/mise/config.toml      ← system
```

Sections merge differently: `[tools]` is **additive** (a project can add tools without
losing the global set), `[env]` **overrides**, `[tasks]` is **replaced** wholesale.

There are also conditional filenames — `mise.macos-arm64.toml`, `mise.linux.toml`,
`mise.<MISE_ENV>.toml` — which is how we'll handle the few tools that only make sense on
one platform.

### Backends — the concept that matters most

asdf needed a community-maintained plugin (a bash script) per tool. mise mostly doesn't,
because it ships with a **registry** of ~985 tools compiled into the binary, each mapped
to one or more backends:

- **`core:`** — built into mise itself: `node`, `python`, `go`, `rust`, `java`, `ruby`.
- **`aqua:`** — the default for most CLIs. mise embeds the [aqua registry](https://github.com/aquaproj/aqua-registry)
  and downloads release binaries directly. **No plugin, no compilation.** Verifies SHA256
  checksums always, plus Cosign signatures, SLSA provenance, GitHub artifact attestations,
  and minisign where publishers provide them — all natively in Rust.
- **`ubi:` / `github:` / `gitlab:`** — generic "grab the release asset from this repo".
- **`cargo:` `npm:` `go:` `pipx:` `gem:` `spm:` `dotnet:`** — install from a language ecosystem.
- **`asdf:` / `vfox:`** — plugin-based fallback, needed only when a tool must set env vars
  or do more than drop a binary on PATH (aqua explicitly cannot do that).
- **`http:` / `s3:`** — arbitrary URLs, for internal tooling.

So `mise use -g ripgrep` resolves via the registry to `aqua:BurntSushi/ripgrep`. You can
always name the backend explicitly to bypass the registry: `mise use -g cargo:convco`.

Check what's available with `mise registry` and `mise registry <tool>`.

### Activation: PATH vs shims

```bash
eval "$(mise activate zsh)"
```

This installs a zsh precmd hook (`mise hook-env`) that rewrites `PATH` when the resolved
tool set changes, and **exits early when nothing changed** — so it costs ~nothing per
prompt. `which node` returns a real path. This is the recommended mode and what we'll use.

The alternative, `mise activate --shims`, puts wrapper scripts on PATH instead. It's for
non-interactive contexts (CI, editors, systemd units) that never source a shell rc. We may
want shims *in addition* later for nvim/VS Code, but not for the interactive shell.

One ordering caveat: mise prepends to `PATH` at activation time, so anything that prepends
to `PATH` *after* `mise activate` runs will shadow mise's tools. In `.zshrc` that means
activation must come after the existing `export PATH="...:/opt/homebrew/bin:$PATH"` line.
(The `activate_aggressive = true` setting forces mise to the front on every hook instead,
if ordering ever gets hard to control.)

### Lockfile

With `lockfile = true`, mise writes a `mise.lock` next to the config, recording the exact
resolved version, checksum, and download URL **per platform**. This is the pattern we want:

- **Declare loosely** in TOML: `kubectl = "latest"`, `node = "lts"`.
- **Pin exactly** in the committed lockfile.
- `mise upgrade` moves within the declared range; `mise upgrade --bump` moves the range
  itself; `mise lock --bump` regenerates.

Result: a fresh machine gets byte-identical tools to this one, and upgrades are an explicit,
reviewable diff — which the current `brew bundle install` flow does not give us.

### What mise is explicitly NOT

Straight from the FAQ: *"mise is for dev tools, not applications or system packages."*
It will not install:

- System libraries (`openssl`, `zlib`) or anything needing a compiler toolchain
- GUI applications — no Homebrew cask equivalent
- Login shells, fonts, or anything requiring root / system registration

**Homebrew is not going away.** This migration splits our Brewfile rather than deleting it.

---

## Part 2 — Why this repo in particular benefits

Three concrete pains in this repo that mise removes:

1. **`install` has three divergent OS branches.** Today macOS gets tools from the Brewfile,
   Debian gets a much smaller set from apt + a neovim PPA, and RHEL a smaller set still from
   dnf. The Linux boxes simply don't have most of the Kubernetes tooling. mise installs the
   *same* tool set from the *same* declaration on all three.

2. **Two hand-rolled Linux installers exist purely because a tool isn't packaged.**
   `install_tree_sitter_cli_linux()` is 20 lines of arch detection, curl, gunzip, and
   `sudo install` — replaced by `tree-sitter = "latest"`. (`install_nerd_font_linux()` stays;
   fonts are not dev tools.)

3. **`Dockerfile` is ~150 lines of the same problem, worse.** It hand-installs ripgrep,
   convco, kubeseal, eksctl, k9s, stern, go, argo, argocd, opa, regal, oras, uv, coder,
   tilt, pulumi, tree-sitter, and nvm — several by scraping the GitHub tags API at build
   time, which means **the image is not reproducible** and breaks when a release changes
   shape. All of those are in the mise registry.

4. **Four of six Homebrew taps exist only to reach one binary each** — `tilt-dev/tap`
   (tilt, ctlptl), `coder/coder`, `siderolabs/tap` (talosctl), `aquasecurity/trivy`. All
   four tools are in the mise registry. `knative/client` is already dead — nothing in the
   Brewfile uses it.

---

## Part 3 — The split

Verified against the mise registry (985 entries) as of this plan.

### Move to mise (36 formulae)

| Brewfile | mise name | Backend |
|---|---|---|
| `bat` | `bat` | aqua:sharkdp/bat |
| `ripgrep` | `ripgrep` | aqua:BurntSushi/ripgrep |
| `jq` | `jq` | aqua:jqlang/jq |
| `yq` | `yq` | aqua:mikefarah/yq |
| `neovim` | `aqua:neovim/neovim` | pinned; bare `neovim` picks the vfox plugin |
| `tree-sitter-cli` | `tree-sitter` | aqua:tree-sitter/tree-sitter |
| `tmux` | `tmux` | aqua:tmux/tmux-builds |
| `lazygit` | `lazygit` | aqua:jesseduffield/lazygit |
| `apko` | `apko` | aqua:chainguard-dev/apko |
| `docker` | `docker-cli` | aqua:docker/cli |
| `go-task` | `task` | aqua:go-task/task |
| `trivy` | `trivy` | aqua:aquasecurity/trivy — **drops a tap** |
| `gh` | `github-cli` | aqua:cli/cli |
| `coder/coder/coder` | `coder` | aqua:coder/coder — **drops a tap** |
| `convco` | `github:convco/convco` | not in registry, explicit backend (see Phase 5b) |
| `pulumi` | `pulumi` | aqua:pulumi/pulumi |
| `ko` | `ko` | aqua:ko-build/ko |
| `gopls` | `go:golang.org/x/tools/gopls` | not in registry, explicit backend |
| `uv` | `uv` | aqua:astral-sh/uv |
| `opa` | `opa` | aqua:open-policy-agent/opa |
| `regal` | `regal` | aqua:open-policy-agent/regal |
| `oras` | `oras` | aqua:oras-project/oras |
| `eksctl` | `eksctl` | aqua:eksctl-io/eksctl |
| `helm` | `helm` | aqua:helm/helm |
| `kube-linter` | `kube-linter` | aqua:stackrox/kube-linter |
| `kubernetes-cli` | `kubectl` | aqua:kubernetes/kubernetes/kubectl |
| `minikube` | `minikube` | aqua:kubernetes/minikube |
| `stern` | `stern` | aqua:stern/stern |
| `tilt-dev/tap/ctlptl` | `ctlptl` | aqua:tilt-dev/ctlptl — **drops a tap** |
| `tilt-dev/tap/tilt` | `tilt` | aqua:tilt-dev/tilt |
| `argo` | `argo` | aqua:argoproj/argo-workflows |
| `vcluster` | `vcluster` | aqua:loft-sh/vcluster |
| `k9s` | `k9s` | aqua:derailed/k9s |
| `kind` | `kind` | aqua:kubernetes-sigs/kind |
| `kubectx` | `kubectx` + `kubens` | aqua:ahmetb/kubectx |
| `kubeseal` | `kubeseal` | aqua:bitnami/sealed-secrets |
| `clusterctl` | `clusterctl` | aqua:kubernetes-sigs/cluster-api |
| `clusterawsadm` | `clusterawsadm` | github:kubernetes-sigs/cluster-api-provider-aws |
| `siderolabs/tap/talosctl` | `talosctl` | aqua:siderolabs/talos — **drops a tap** |

**Dropped after Phase 0 testing: `uutils-coreutils`.** Homebrew's formula installs 217
individually-named binaries (`uu-ls`, `uu-cat`, …). mise's aqua package is a *single
multi-call binary* — you invoke it as `coreutils ls`, and it puts no `ls`/`uu-ls` on PATH at
all. That's a real behavioral difference, not a version bump. Nothing in this repo references
`uu-*` or `gnubin` (the only mention of it anywhere is the Brewfile line itself), so the
simplest resolution is to **drop it from the Brewfile entirely** rather than port it. If you
do want uutils, keep it in Homebrew.

**Reinstated in Phase 5c** — see below. The multi-call shape is real, but it is worked
around with aliases rather than being a reason to skip the tool.

Plus two additions that mise makes free and that `.zshrc` currently gets elsewhere:
`node` (`core:node`, replacing nvm) and `fzf` (`aqua:junegunn/fzf`, currently a stray
`~/.fzf.zsh`).

### Stay in Homebrew (and apt/dnf on Linux)

- **Login shells** — `zsh`, `bash`. These need to be real system shells registered in
  `/etc/shells` for `chsh`; a mise-managed zsh cannot be your login shell.
- **System libraries and their CLIs** — `openssl`, `curl`.
- **GNU userland** — `gnu-sed`, `diffutils`, `findutils`, `aspell`, `tree`, `watch`, `wget`.
  Not in the registry; these are OS-package territory.
- **`git`, `make`** — not usefully in the registry (`make` only via `conda:`, which we don't
  want). Both are base system tools.
- **`stow`** — must exist *before* the mise config is symlinked into place. Bootstrapping it
  with mise would be circular. Also not in the registry.
- **`wireguard-tools`** — needs root and kernel/system integration.
- **Every `cask`** — mise has no GUI story. Docker Desktop, 1Password, Alacritty, VS Code,
  fonts, Slack, etc. all stay.
- **Every `vscode`** entry — unrelated to mise.

---

## Part 4 — Migration steps

### Phase 0 — Install and evaluate, change nothing  ✅ DONE

```bash
curl https://mise.run | sh
~/.local/bin/mise --version
~/.local/bin/mise doctor
```

Sanity-check a few of the riskier tools before committing to them, without touching PATH:

```bash
~/.local/bin/mise exec neovim@latest -- nvim --version
~/.local/bin/mise exec tmux@latest -- tmux -V
~/.local/bin/mise exec coreutils@latest -- ls --version
```

**Results (mise 2026.9.1, macos-arm64):**

- `neovim` → **v0.12.5, works.** Note the bare name resolves to `vfox:` (a plugin backend);
  the config pins `aqua:neovim/neovim` instead — same binary, no plugin clone.
- `tmux` → **3.7c, works.**
- `coreutils` → **multi-call binary, not `uu-*` shims** (see the split table). Initially
  rejected for that reason; reinstated in Phase 5c behind aliases.
- `ubi:convco/convco` → **0.7.1, works** — and installs a prebuilt binary. `cargo:convco`
  would compile from source on every machine, so the plan originally specified `ubi:`.
  Superseded in Phase 5b: `ubi:` is deprecated, and this is now `github:convco/convco`.
- `go:golang.org/x/tools/gopls` → **v0.23.0, works.**

All 42 remaining tools resolved against the real registry via `mise registry <tool>`.

### Phase 1 — Add the mise stow package  ✅ DONE

Create `dotfiles/mise/.config/mise/config.toml`:

```toml
[settings]
# Pin exact versions + checksums into mise.lock, committed alongside this file.
lockfile = true
# Don't let a typo'd command trigger a surprise install.
not_found_auto_install = false

[tools]
# --- shell tooling ---
bat          = "latest"
coreutils    = "latest"   # uutils
ripgrep      = "latest"
jq           = "latest"
yq           = "latest"
fzf          = "latest"
neovim       = "latest"
tree-sitter  = "latest"
tmux         = "latest"
lazygit      = "latest"

# --- generic dev ---
apko         = "latest"
"docker-cli" = "latest"
task         = "latest"
trivy        = "latest"
"github-cli" = "latest"
coder        = "latest"
"cargo:convco" = "latest"

# --- languages ---
go   = "latest"
node = "lts"
uv   = "latest"
ko   = "latest"
"go:golang.org/x/tools/gopls" = "latest"

# --- policy ---
opa   = "latest"
regal = "latest"
oras  = "latest"

# --- cloud ---
pulumi = "latest"

# --- kubernetes ---
kubectl       = "latest"
helm          = "latest"
k9s           = "latest"
kind          = "latest"
minikube      = "latest"
stern         = "latest"
kubectx       = "latest"
kubens        = "latest"
kubeseal      = "latest"
kube-linter   = "latest"
eksctl        = "latest"
vcluster      = "latest"
argo          = "latest"
ctlptl        = "latest"
tilt          = "latest"
clusterctl    = "latest"
clusterawsadm = "latest"
talosctl      = "latest"
```

Then add `mise` to `STOW_PACKAGES` in `install`. It stows cleanly with normal folding —
`~/.config/mise/` holds only config, not machine-local state, so it does **not** need the
`--no-folding` treatment that `claude` and `agents` require. Confirmed:

```
~/.config/mise -> ../config/dotfiles/mise/.config/mise
```

matching the existing `alacritty` and `nvim` links. `mise install` then installed all 42
tools cleanly, with aqua verifying GitHub artifact attestations, SLSA provenance, and Cosign
signatures along the way (visible for `coder`, `clusterawsadm`, and `talosctl`).

**Verified in Phase 1 — two things differ from what the docs implied:**

1. The file is named `mise.lock`, not `config.lock`, even for the global config.
2. `lockfile = true` alone does **not** auto-create it for the *global* config. mise says so
   directly: *"No tools configured to lock in this project, but global config declares tools.
   Run `mise lock --global` to lock those."* Auto-locking applies to project configs; the
   global one needs the explicit flag.

So generating it is a deliberate step: `mise lock --global`.

It writes through the stow symlink into `dotfiles/mise/.config/mise/mise.lock` as intended,
and **should be committed**. It is created mode `0600`; git only tracks the exec bit, so
that's harmless.

The pleasant surprise: the lockfile is **cross-platform**. One run on macOS produced 42 tools
× `macos-arm64`, `macos-x64`, `linux-x64`, `linux-arm64`, `linux-x64-musl`, `linux-arm64-musl`
(and 39 on `windows-x64`) — 284 entries with pinned URLs and checksums for each. A Linux box
installs from *this* lockfile without re-resolving anything, which is what makes the
cross-platform story in Part 2 actually hold.

### Phase 2 — Activate in the shell  ✅ DONE

**Missing prerequisite, found during this phase:** `~/.local/bin` — where the mise installer
puts the binary — was **not on your PATH**. Without adding it, `mise activate` silently never
runs. So the PATH line changes too:

```diff
-export PATH="/opt/nvim-linux-x86_64/bin:/opt/homebrew/bin:$PATH"
+export PATH="$HOME/.local/bin:/opt/nvim-linux-x86_64/bin:/opt/homebrew/bin:$PATH"
```

Then, at the end of `dotfiles/zsh/.zshrc` (replacing the nvm/fzf tail), guarded so a machine
without mise yet doesn't error on shell start:

```bash
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
```

At the same time, three cleanups this enables:

1. **Delete the nvm block** — mise owns node now:
   ```bash
   export NVM_DIR="$HOME/.nvm"
   [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
   ```
   nvm's own PATH manipulation will otherwise fight mise for `node`.

2. **Replace the fzf source line** with `command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)`,
   placed *after* mise activation so it picks up mise's fzf.

   Worth knowing: **fzf was never in the Brewfile at all.** `/opt/homebrew/bin/fzf` does not
   exist — it was a hand-cloned `~/.fzf` git install, completely untracked by this repo, and
   `~/.fzf.zsh` just hardcoded `/Users/dylan.jenik/.fzf/bin` onto PATH. Moving it to mise puts
   it under version control for the first time. `~/.fzf` and `~/.fzf.zsh` are now dead and can
   be deleted.

3. Nothing needs to move above the p10k instant-prompt guard — `mise activate` prints
   nothing to the console. Confirmed: a real pty session starts clean with no warnings.

**Measured overhead** (rather than taking the docs' word for it): `mise activate` costs
**~8.5 ms** once at shell start, and `mise hook-env` — the per-prompt hook — costs **~5.6 ms**
when nothing has changed. Against a ~365 ms interactive zsh startup dominated by oh-my-zsh,
p10k, and syntax highlighting, this is noise.

**Verified after activation:** `node`, `kubectl`, `nvim`, `rg`, `jq`, `helm`, `k9s`, `fzf`,
`go`, and `gh` all resolve into `~/.local/share/mise/installs/`. neovim is **v0.12.5 from both
brew and mise** — bit-for-bit the same version, so the editor sees no change at all.

(If you test with `zsh -i -c`, you'll see `can't change option: zle` warnings from fzf. Those
are pre-existing — they reproduce identically with the old `~/.fzf.zsh` — and are an artifact
of `zsh -i -c` not being a true interactive shell. A real terminal is clean.)

### Phase 3 — Trim the Brewfile  ✅ DONE

Remove the 36 formulae in the "move to mise" table, plus the four now-unused taps
(`tilt-dev/tap`, `coder/coder`, `siderolabs/tap`, `aquasecurity/trivy`) and the already-dead
`knative/client`. Keep every `cask` and `vscode` line untouched.

Then reconcile, in this order:

```bash
brew bundle install --file=./Brewfile   # no-op, confirms file is valid
brew bundle cleanup --file=./Brewfile   # DRY RUN — read this list carefully
```

`brew bundle cleanup` without `--force` prints what it *would* remove. **Read it before
running `brewup`**, which passes `--force`.

**Result:** Homebrew removed **52 formulae, not the 40 listed above.** The extra 12 are
orphaned dependencies that existed only for the removed tools:

`llhttp` `libgit2` `oniguruma` `jemalloc` `libevent` `libuv` `lpeg` `luajit` `luv`
`tree-sitter` `unibilium` `utf8proc`

This was verified safe two ways before running with `--force`:

- **Forward** — the recursive dependency closure of the 15 kept formulae is 20 packages, with
  zero overlap against the removal list.
- **Reverse** — `brew uses --installed` showed each orphan was needed only by things also
  being removed (`tree-sitter`/`luajit`/`libuv` → neovim, `oniguruma` → bat + jq,
  `libgit2` → bat, `jemalloc` → tmux).

Do this check rather than trusting the label; it is the one step in this phase that can't be
undone with a single command.

Also removed: all 5 taps, and ~2.0 GB of cached downloads (mostly cask DMGs — harmless).

Final state: 15 explicit formulae + 17 dependencies installed, 1 tap, all 21 casks and 38
VS Code extensions untouched.

### Phase 4 — Update `install`  ✅ DONE

**A bug this phase introduces if you're not careful:** `install` runs under **bash** and
never sources `.zshrc`, so mise is never activated for it. `install_claude_plugins` guarded on
`command -v claude` — which was fine when claude came from a Homebrew cask in `/opt/homebrew/bin`,
but claude is a mise tool now and is **not** on this script's PATH. The guard would silently
skip the plugin install on every fresh bootstrap.

Proven with `env -i HOME=$HOME PATH=/usr/bin:/bin bash -c 'command -v claude'` → not found.
The fix is to fall back to `mise which claude`, which resolves correctly in that same clean
environment. Any other script in this repo that shells out to a mise-managed tool needs the
same treatment.

- Add `mise` to `STOW_PACKAGES`.
- Add an `install_mise()` that installs mise if absent (`curl https://mise.run | sh`) — it
  must run *before* `link_dotfiles`, and the actual `mise install` *after*, since the config
  arrives via stow.
- Add `mise install` to `main()` after `link_dotfiles`. The committed `mise.lock` means
  this resolves nothing and re-uses the pinned URLs/checksums.
- **Delete `install_tree_sitter_cli_linux()`** and its two call sites — fully replaced.
- Shrink `install_debian()` and `install_rhel()` to base system packages only: build
  toolchain, `curl`, `git`, `unzip`, `stow`, `zsh`, GNU userland. The neovim PPA and the
  `dnf install neovim` can go — mise supplies neovim on all platforms now.
- Keep `install_nerd_font_linux()`; fonts are not dev tools.

**Result.** `install_debian` went from an apt install + a PPA + a second apt install down to one
`apt-get install`; `install_rhel` similarly. `install_tree_sitter_cli_linux()` — 23 lines of arch
detection, curl, gunzip, and `sudo install` — is gone entirely. Both Linux branches now install
only what mise cannot supply: build toolchain, login shell, and the four things needed to
bootstrap (`curl`, `git`, `unzip`, `stow`).

Verified: `bash -n` clean, `shellcheck` clean (run via `mise exec shellcheck@latest`), and the
four changed functions exercised in an `env -i` clean environment — `install_mise` finds the
existing binary without redownloading, claude resolves via `mise which`, `install_mise_tools`
is a correct no-op when everything is present, and `link_dotfiles` restows idempotently.

### Phase 5 — `brewup`  ✅ DONE

`brewup` now has two halves: the existing Homebrew block, and a mise block that mirrors it.
Four things had to be got right, none of which were obvious from the plan.

**1. mise has to be called by explicit path.** `brewup` runs under bash and never sources
`.zshrc`, so mise is never activated for it. Confirmed the same way as in `install`:

```
$ env -i HOME=$HOME PATH=/usr/bin:/bin bash -c 'command -v mise'
NOT FOUND
```

So the script uses `MISE_BIN="$HOME/.local/bin/mise"`, and a `cd "$(dirname "$0")"` was
added because the `--file=./Brewfile` paths already assumed the repo root as cwd.

**2. `mise lock --global` needs a GitHub token.** This is the one that actually bites.
Normal installs read the lockfile and hit no API at all, but `mise lock` refreshes
**44 tools across 7 platforms — 304 entries** — through the GitHub API. Unauthenticated
that is 60 requests/hour, and it rate-limits partway through.

`gh` is logged in, but mise still reported no token:

```
$ gh auth status
  ✓ Logged in to github.com account eatmyrust (keyring)
$ mise token github
github.com: (none)
```

`gh auth login` stored the token in the **macOS Keychain**, so `~/.config/gh/hosts.yml`
has zero `oauth_token` keys and mise's gh-CLI integration has nothing to read. `brewup`
therefore exports `GITHUB_TOKEN` from `gh auth token` itself (env var beats every
file-based source in mise's resolution order).

Deliberately *not* done via `[settings.github]` in `config.toml`: that file is stowed into
this repo, and a token in it is a credential one `git add` away from being published.
`github_tokens.toml` has the same problem. The env-var route keeps the secret in the
Keychain, where it already lives.

That block runs with `set +x`, because `set -euxo pipefail` would otherwise trace
`export GITHUB_TOKEN=gho_...` straight into the terminal and any captured log. Verified:

```
$ grep -E 'gho_|ghp_' run.log
(no matches)
```

**3. `mise lock --global` is not redundant with `mise upgrade`.** `upgrade` updates the
lockfile only for the platform it is running on. `mise lock` is documented as refreshing
"platforms other than the one you're currently on" — it is what keeps the linux-x64 /
linux-arm64 / musl / windows entries alive. Without it the Docker build in Phase 6 loses
its pinning. This is the easiest line to leave out and the one that matters most.

**4. `mise prune` does not work.** `--dry-run` lists versions it would remove; the real run
removes nothing and exits 0:

```
$ mise prune --tools --dry-run | grep -c uninstall
5
$ mise prune --tools
$ mise ls --prunable          # unchanged — all 5 still there
```

A bare `mise prune` (no `--tools`) only prunes stale *config links*, despite its help text
claiming otherwise. The line is kept in `brewup` so it starts working when mise fixes it,
with the caveat recorded inline. Manual fallback:

```bash
mise ls --prunable
mise uninstall <tool>@<version>
```

Cleared this way: `coreutils`, plain `neovim@0.12.5`, `shellcheck`, `ubi:convco/convco`,
`ubi:solidiquis/erdtree` — **115MB**, all of them abandoned experiments from earlier
phases. Checked first that `mise which nvim` resolves to `aqua-neovim-neovim`, so pruning
the orphaned plain `neovim` could not break the editor.

Use `mise upgrade --bump` when you deliberately want to move the `"latest"`/`"lts"` ranges
themselves, and commit the resulting `config.toml` + `mise.lock` diff.

### Phase 5b — `ubi:` → `github:`  ✅ DONE

Surfaced by a warning while verifying Phase 5:

```
mise WARN deprecated [ubi]: The ubi backend is deprecated. Use the github backend
instead (e.g. github:owner/repo). This will be removed in mise 2027.1.0.
```

`"ubi:convco/convco"` → `"github:convco/convco"`. Same prebuilt-binary story, and the
`github:` backend additionally verified SLSA provenance and GitHub artifact attestations
on install. `convco` 0.7.1 unchanged; lockfile went 43 → 44 tools and 298 → 304 platform
entries. No `ubi:` references remain in either `config.toml` or `mise.lock`.


`cask "claude-code"` moved to `claude-code = "latest"` (`aqua:anthropics/claude-code`).

The risk worth checking first was the self-updater: Claude Code updates itself, and pointing
it at a mise-managed path could have meant it overwriting a version mise thought it owned.
It doesn't — Claude Code **detects mise natively**:

```
Package manager: mise
Path: ~/.local/share/mise/installs/claude-code/2.1.258/claude
Auto-updates: Managed by package manager
```

So mise owns the version exactly as the cask did. Verify with `claude doctor` after any
change to how it's installed.

Migration was a targeted `brew uninstall --cask claude-code` — deliberately **not** `--zap`,
which would delete `~/.claude` (auth, sessions, and the stowed `settings.json` /
`statusline-command.sh` symlinks). Confirmed intact afterwards, with all 22 agent skills still
linked. Version went 2.1.231 (cask) → 2.1.258 (mise).

The `vscode "anthropic.claude-code"` extension is a separate thing and unrelated to this.

### Phase 4b — `tree` and `aspell`  ✅ DONE

Neither could move to mise, for the same reason: **every mise binary backend (aqua, ubi,
github, http) installs a prebuilt binary from a release, and neither project publishes one.**

- canonical `tree` (`Old-Man-Programmer/tree`) has **zero GitHub releases** and no aqua package
- GNU `aspell` publishes 6 releases containing only `aspell-0.60.x.tar.gz` **source tarballs**,
  has no aqua package, and additionally needs separate dictionary data packages — which aqua
  explicitly cannot handle ("cannot do more than download binaries")

Building either from source needs an asdf/vfox plugin, reintroducing the compile-on-every-machine
cost this migration exists to remove. This is the general test for "can tool X move to mise?":
**does upstream ship a prebuilt binary?** If not, it stays with the OS package manager.

Neither was referenced anywhere in the dotfiles, so both were hand-typed conveniences.

**Resolution:**

- `tree` → replaced by `lsd` (`aqua:lsd-rs/lsd`), with `alias tree='lsd --tree'` in `.zshrc` to
  keep the muscle memory. Removed from Brewfile and both Linux package lists — now declared once.
- `aspell` → **dropped**. Unused, and it was reclaiming 338 MB of dictionaries.

Also worth recording: `erd` (erdtree) was the other candidate and works via
`ubi:solidiquis/erdtree[exe=erd]`. The `[exe=erd]` part is required because the repo is named
`erdtree` but the binary inside the tarball is `erd` — a general ubi gotcha when repo name and
binary name differ.

### Phase 5c — GNU coreutils via aliases  ✅ DONE

`coreutils = "latest"` added, reversing the Phase 0 rejection. The multi-call shape that
caused that rejection is real, but it is an aliasing problem, not a blocker.

**What you actually get.** `aqua:uutils/coreutils` is **uutils** — a Rust reimplementation
of GNU coreutils, *not* GNU itself. Homebrew's `coreutils` formula is the genuine GNU
article. uutils targets GNU compatibility and is what Ubuntu 25.10 ships by default, but
it is a different implementation and worth knowing about before trusting it with `rm`.

It installs exactly one executable:

```
$ ls ~/.local/share/mise/installs/coreutils/latest/*/
coreutils  LICENSE  README.md
$ coreutils --version
coreutils 0.11.0 (multi-call binary)
```

107 utilities live inside it, reachable only as `coreutils <util>`. So `.zshrc` aliases
89 of them, plus `ls` separately — 90 total.

**Verified working on macOS before aliasing.** The concern was utilities that read `utmpx`
or termios and return nothing useful on Darwin. They are all fine:

```
who      → dylan.jenik console 2026-08-26 07:07
users    → dylan.jenik dylan.jenik
uptime   →  07:30:01 up 8 days 6:58, 2 users, load average: 3.65
id       → uid=501(dylan.jenik) gid=20(staff) groups=20(staff),...
```

The one exception is `hostid`, which reports `00000000` on macOS, so it is not aliased.

**The `ls` trap.** oh-my-zsh already sets `alias ls='ls -G'`. `-G` is BSD's colour flag; in
GNU it means *"no group column"*. A naive `alias ls='coreutils ls'` silently drops colour,
so `ls` is respelled `coreutils ls --color=auto`. Colours stay on, but the palette changes:
GNU reads `LS_COLORS`, while the `LSCOLORS` oh-my-zsh exports is the BSD format and is
ignored. Run `eval "$(coreutils dircolors -b)"` if you want to tune it.

`ls` was the *only* collision with an existing alias — checked by intersecting
`coreutils --list` against a live shell's `alias` output.

**Deliberately not aliased (18):**

| Skipped | Why |
|---|---|
| `[` `test` `echo` `printf` `pwd` `true` `false` `kill` | zsh builtins — a fork buys nothing and `echo` changes escape semantics |
| `stty` `tty` | terminal control |
| `chroot` `mknod` | root-level, effectively never interactive |
| `more` `install` `env` `hostname` | would shadow a pager, a build tool, and two things scripts reach for |
| `hostid` | returns `00000000` on macOS |

**Scripts are unaffected**, which is the property that makes this safe: aliases are
interactive-only, so this repo's own `install` and `brewup` still get the system binaries.

```
$ bash -c 'date -d 2026-01-15'
date: illegal option -- d      # BSD date, i.e. the system one
```

Confirmed working interactively:

```
$ date -d "2026-01-15 +30 days" +%Y-%m-%d   → 2026-02-14   (BSD date cannot do this)
$ stat -c "%s bytes %n" Brewfile            → 685 bytes Brewfile
$ echo hi | sha256sum                       → macOS has no sha256sum at all
$ printf "2K\n1M\n3B\n" | sort -h         → 3B 2K 1M
```

Startup cost of the 90-alias loop is not measurable against a ~170ms zsh start.

**On Linux this is a downgrade, not an upgrade.** Debian and RHEL already ship real GNU
coreutils, so the aliases swap GNU for a reimplementation there. It is left unguarded to
keep behaviour identical across all three OSes — the stated goal of this migration — but
if you would rather have GNU where GNU exists, wrap the block in:

```zsh
if [[ "$OSTYPE" == darwin* ]] && command -v coreutils >/dev/null 2>&1; then
```

### Phase 6 — the Dockerfile  ✅ DONE

**218 → 158 lines**, and most of what remains is the two VS Code extension lists (~75
lines). Every hand-rolled tool installer is gone.

Removed: `curl|tar` / `dpkg -i` / `gunzip` installs of ripgrep, convco, kubeseal, eksctl,
k9s, stern, go, argo, kubectx, kubens, opa, regal, oras, uv, coder and tree-sitter; the
`go install` of apko and kube-linter; the tilt and pulumi install scripts; the nvm clone;
the neovim PPA; and the kubectl, helm and trivy apt keyrings. Replaced by:

```dockerfile
stow --dir=/home/vscode/dotfiles --target=/home/vscode --restow zsh tmux nvim mise && \
curl https://mise.run | sh && \
MISE_YES=1 ~/.local/bin/mise install
```

**Latent bug found:** the trivy apt repository was configured, but `trivy` was never added
to the apt install list — the image never actually had it. It does now.

**Second latent bug:** the uv install ended `| sh \` followed by a comment line, so the
code-server install that followed was never `&&`-chained to it. A uv failure would not have
failed the build. Both lines are gone now.

**Ordering.** `stow` moved earlier, because it is what puts `config.toml` and `mise.lock`
at `~/.config/mise` — `mise install` is useless before it. `nvim --headless +qa` stays last:
it prewarms plugins and shells out to tree-sitter, and both are now mise tools.

**Shims, not shell activation.** A build has no interactive shell, so PATH is set directly:

```dockerfile
ENV PATH=/home/vscode/.local/share/mise/shims:/home/vscode/.local/bin:${PATH}:/home/vscode/go/bin
```

Interactive shells still run `mise activate zsh` from `.zshrc`, which puts real binary paths
ahead of the shims. `/usr/local/go/bin` and `~/.pulumi/bin` are gone from PATH; `~/go/bin`
stays, because `crane` is still a `go install` — it now uses mise's go via the shims.

**Verified by building.** The mise half was built and run on `linux/arm64`:

```
LOCKFILE STOWED OK
mise talosctl@1.13.9 [2/2] ✓ Cosign verified
#10 DONE 191.8s
```

45 tools in 191s, **no GitHub token** — installs read the lockfile instead of the API.
Every tool resolves through the shims, and versions match the lockfile exactly, which is
the reproducibility claim actually being true rather than asserted:

| | container | mise.lock |
|---|---|---|
| kubectl | v1.37.0 | 1.37.0 |
| helm | v4.2.4 | 4.2.4 |
| nvim | 0.12.5 | 0.12.5 |
| node | v24.20.0 | 24.20.0 |
| go | 1.27.1 | 1.27.1 |
| k9s | v0.51.0 | 0.51.0 |

`docker build --check` on the full Dockerfile: *"Check complete, no warnings found."*

**How stale the image had drifted** — these are the versions the container shipped versus
what the Mac has had all along:

| tool | old Dockerfile | now |
|---|---|---|
| go | 1.22.0 | 1.27.1 |
| ripgrep | 13.0.0 | 15.2.0 |
| k9s | 0.31.8 | 0.51.0 |
| argo | 3.5.4 | 4.1.2 |
| stern | 1.28.0 | 1.34.0 |
| kubectl | 1.29 (apt repo) | 1.37.0 |
| opa / oras / kubeseal | resolved at build time | 1.20.1 / 1.3.4 / 0.39.1 |

The last row is the reproducibility problem in one line: those three scraped
`api.github.com/.../tags` during the build, so two builds of the same commit could produce
different images.

**Still installed by hand**, because adding them to the global config would also install
them on the Mac: `awscli`, `argocd`, `op` (1Password), `packer` (apt), `code-server`, and
`crane` (`go install`). All except code-server *are* in the mise registry — `aqua:aws/aws-cli`,
`aqua:argoproj/argo-cd`, `aqua:1password/cli`, `aqua:hashicorp/packer`,
`aqua:google/go-containerregistry` — so they can move if you want them on both machines.

**Not fully build-tested, and why.** The mise portion was verified end-to-end above. A
complete build of the whole file was not run here: `awscli`, `op` and `argocd` fetch
`x86_64`/`amd64` artifacts unconditionally, so a native build on Apple Silicon fails on
those steps. That is pre-existing, not introduced by this change — but note that the mise
half is now arch-agnostic (it installed arm64 binaries natively), so those three hand-rolled
installers plus code-server are the only things left standing between this image and
multi-arch.

### Phase 6b — the last hand-rolled installers, and dropping code-server  ✅ DONE

Closed out the "still installed by hand" list from Phase 6: `awscli`, `argocd`, `op`,
`packer` moved to mise (global config, so they now install on the Mac too); `code-server`
was removed outright, not migrated.

- **`code-server` has no aqua package** (confirmed again here, not just asserted from Phase
  6) — coder/code-server publishes GitHub releases but aqua's registry has no entry for it,
  and it wasn't worth a `github:` backend entry for a browser-IDE nobody was using outside
  this container. Removed with no replacement: the curl install line, and the trailing
  `apt clean` it was chained to (rejoined to the block above it).
- **`aws-cli`, `argocd`, `crane` moved with their bare registry names** — all three resolve
  through `aqua:` by default with no ambiguity (`aqua:aws/aws-cli`, `aqua:argoproj/argo-cd`,
  `aqua:google/go-containerregistry`).
- **`packer` moved too**, which retires the `apt.releases.hashicorp.com` keyring/repo block
  entirely — it existed only to apt-install packer. `aqua:hashicorp/packer` resolves cleanly.
- **`op` (1Password CLI) could not use the aqua backend**, despite `mise registry op` listing
  one: `mise install "aqua:1password/cli"` fails outright —
  `mise WARN aqua package 1password/cli does not have repo_owner and/or repo_name` /
  `no versions found for aqua:1password/cli matching date filter`. 1Password doesn't publish
  releases on GitHub, and aqua's registry entry for it can't resolve a repo to query. The
  bare name `op` (`vfox:mise-plugins/vfox-1password`) installs fine — 2.39.0, verified working
  — so the config uses that, same pattern as `"aqua:neovim/neovim"` being an explicit
  override in the other direction (there, bare resolves to vfox and an explicit `aqua:` was
  needed to avoid the plugin; here it's the reverse — bare *is* the working backend).
- **`crane` no longer needs `go install`.** The Dockerfile's `go install
  github.com/google/go-containerregistry/cmd/crane@latest` line and the `~/go/bin` PATH
  entry it existed for are both gone.

**Verified:**

```
$ mise install        # all 5 new tools resolve, zero errors after the op fix above
$ mise exec -- aws --version       → aws-cli/2.36.38 Python/3.14.6 Darwin/25.6.0 exe/arm64
$ mise exec -- argocd version --client → v3.5.2+e258ee2
$ mise exec -- packer --version    → Packer v1.16.0
$ mise exec -- crane version       → 0.22.0
$ mise exec -- op --version        → 2.39.0
```

`mise lock --global` (with `GITHUB_TOKEN` from `gh auth token`, same reasoning as Phase 5)
regenerated the lockfile: 44 → 49 tools, 345 platform entries, all 5 new tools pinned across
every platform including `op` (the vfox-plugin tool — lockfiles cover plugin-backed tools
too, not just aqua ones).

`docker build --check` on the resulting Dockerfile: clean, no warnings. A full native
`linux/arm64` build was run end-to-end (not just the mise layer, as in Phase 6) to confirm
the trimmed apt block, the retired packer keyring, and the removed `go install` line don't
break anything downstream.

With this phase, the "still installed by hand" list from Phase 6 is now just `code-server`
— and it's gone, not hand-rolled. Nothing in the Dockerfile fetches an `x86_64`/`amd64`
artifact unconditionally anymore, so the multi-arch blocker Phase 6 flagged is resolved too.

---

## Verification

After phases 1–3, on macOS:

```bash
mise doctor                 # activated: yes
mise ls                     # every tool installed, versions resolved
type -a kubectl nvim rg jq  # resolves into ~/.local/share/mise/installs, not /opt/homebrew
git status -- dotfiles/mise # mise.lock is present and populated
```

**Verified after Phase 3:** all 44 migrated tools resolve from `~/.local/share/mise/installs`,
zero missing, zero still coming from Homebrew. Functionally exercised: kubectl v1.37.0,
helm 4.2.4, ripgrep 15.2.0, jq 1.8.2, gh 2.99.0, docker 29.7.2, tmux 3.7c, nvim v0.12.5,
node v24.20.0 / npm 11.19.0, go 1.26.0. The 15 kept Homebrew formulae all still resolve.

Two false alarms worth not re-investigating:

- `zsh -i -c` is not a true interactive shell, so it emits `can't change option: zle/monitor`
  and `gitstatus failed to initialize`. Both are artifacts of the test method — a real pty is
  clean, and `~/.cache/gitstatus/gitstatusd-darwin-arm64` (v1.5.4) runs fine. Test prompt
  behaviour with `script -q /dev/null zsh -i -c ...`, not bare `zsh -i -c`.
- `brew leaves` omits `bash` and `openssl@3`, which looks like they went missing. They didn't
  — `openssl` installs as `openssl@3` and is a dependency of `curl`, so it isn't a leaf. Use
  `brew list --formula` to check presence.

Then the real test — a clean Linux box (or a throwaway container) running `./install` from
scratch, confirming it now ends with the same tool set macOS has.

## Rollback

Every phase is independently reversible:

- Phase 2: comment out `eval "$(mise activate zsh)"` — mise's tools leave PATH, Homebrew's
  are still there if Phase 3 hasn't run.
- Phase 3 is the one-way door, because `brew bundle cleanup --force` uninstalls. **Run
  Phases 1–2 and live on them for a few days before Phase 3.** During that window both
  copies of each tool are installed and mise's simply win on PATH, which is exactly the
  low-risk soak test you want.

## Follow-on opportunities (not in scope)

- **`[env]`** could replace per-project direnv-style config, and `TG_TF_FORWARD_STDOUT` /
  `EDITOR` / `LANG` currently in `.zshrc` are candidates.
- **`[tasks]`** could absorb `brewup` and the `install` script's phases into
  `mise run bootstrap` / `mise run update`, cross-platform and self-documenting — and would
  make `go-task` redundant.
