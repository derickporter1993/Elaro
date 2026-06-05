# Git hooks (`.githooks/`)

Version-controlled git hooks for this repo. They are activated by pointing
git at this directory:

```bash
git config core.hooksPath .githooks
```

This runs automatically via the `prepare` npm script on `npm install`, so a
fresh clone gets the hooks after dependencies are installed. To verify:

```bash
git config --get core.hooksPath   # -> .githooks
```

## Hooks

| Hook          | Purpose                                                              |
| ------------- | ------------------------------------------------------------------- |
| `post-commit` | After each commit, asks how to sync the current branch, local `main`, and the remote. |

### `post-commit` behaviour

- Runs **only in an interactive terminal**. In non-interactive contexts
  (Claude Code, CI, GUI git clients, rebases) it exits silently so commits are
  never blocked or delayed.
- Prompts for one of: push current branch, fast-forward local `main` from
  `origin/main`, both, or skip.
- **Never pushes to `main`.** Promoting changes into `main` goes through a pull
  request, per the project's branch-protection rule.

To disable temporarily: `git config core.hooksPath .git/hooks` (or commit with
`git commit --no-verify`, which skips pre/commit-msg hooks but not post-commit;
to skip post-commit, unset `core.hooksPath`).
