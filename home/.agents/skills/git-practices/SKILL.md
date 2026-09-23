---
name: git-practices
description: "Rebase-only git workflow: linear history with no merge commits, commit message and staging conventions, force-push safety, and recovery from a bad rewrite. Use when committing, branching, pulling, updating a branch against main, resolving conflicts, rewriting history, or landing a PR."
---

# Git practices

History is **linear**. Every integration is a rebase, every landing is a fast-forward or a squash, and the graph never grows a merge commit.

## Integrating

- Update a topic branch: `git fetch origin && git rebase origin/main`.
- Pull: `git pull` (rebase is already the configured default).
- Land a PR: `gh pr merge --rebase` or `gh pr merge --squash`.

The safe path is the default path: `pull.rebase`, `merge.ff=only`, `rebase.autoStash`, `rebase.updateRefs`, `rerere`, and `push.autoSetupRemote` contained in the global git config. `merge.ff=only` turns an accidental merge into a refused command, so a refused merge means rebase and retry, never reach for a flag that forces the merge through.

Conflicts surface one commit at a time. Resolve the files the rebase names, `git add` them, then `git rebase --continue`. To get back to where you started, `git rebase --abort`; the pre-rebase tip also stays in `ORIG_HEAD`.

## Rewriting history

Rewrite only your own topic branches. `main` and any branch someone else is committing on move forward by fast-forward alone.

Interactive flags do not work in this environment, so reach for the non-interactive equivalents:

- Fold a fix into an earlier commit: `git commit --fixup <sha>` then `GIT_SEQUENCE_EDITOR=true git rebase --autosquash <base>`.
- Move a branch onto a new base: `git rebase --onto <new-base> <old-base> <branch>`.
- Amend the tip: `git commit --amend --no-edit`.

Push a rewritten branch with `git push --force-with-lease --force-if-includes`, which refuses when the remote holds work you have not seen. Ask the user before any force-push, `reset --hard`, or branch deletion.

## Committing

- One logical change per commit. Stage paths explicitly rather than `git add -A`.
- Check `git status` for files that wandered in, and leave unrelated changes out of the commit.
- Subject line: the repo's existing prefix convention (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`), imperative mood, under 72 characters. Read `git log --oneline -20` when the convention is unclear.
- Body: only if further clarification is needed, why the change exists and what it rules out, not a restatement of the diff.
- Create a branch or worktree for a body of work and commit, push, and open a PR if possible when work is completed.

## Recovering

`git reflog` holds every position HEAD has occupied, so a rebase or reset that went wrong is recoverable: find the pre-rewrite entry and `git reset --hard <sha>`. Look there before concluding work is lost.
