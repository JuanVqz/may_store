# Pre-commit hook so linting is enforced, not trusted

## Why

`CLAUDE.md` tells whoever touches a view to run `bundle exec herb lint` before committing. That is documentation, so it works exactly as well as the reader's attention. CI catches the miss, but only after a push, a wait, and a fixup commit. A hook moves the feedback from minutes to under a second.

This is worth doing precisely because the checks are fast: `herb lint` is about 1s over the whole app, and `rubocop` on staged files is comparable. There is no reason to pay CI latency for either.

## Decisions to make first

### What runs

At minimum `herb lint` on staged `*.erb` / `*.html` files. Worth considering in the same hook:

- `rubocop` on staged `*.rb`, since `bin/rubocop` is already in the repo and CI already gates on it.
- Nothing else. Do **not** put the test suite in a pre-commit hook. `bin/rails test` is about 6s and `test:system` about 45s; that turns every commit into a coffee break and people start passing `--no-verify`, which loses the hook entirely.

### Whole project or staged files only

Staged-files-only is faster but misses offenses in files a commit did not touch, which can happen after a rebase or a config change. Given `herb lint` over all 56 templates takes under a second, running the whole project for views is simpler and has no real cost. Scope `rubocop` to staged files, where the difference actually matters.

### Which tool

Three options, in increasing weight:

1. **A plain `.githooks/pre-commit` script** plus `git config core.hooksPath .githooks`, committed to the repo. Zero dependencies. The cost is that every clone needs the `git config` line once, so it belongs in `bin/setup` and the README.
2. **`lefthook`** (a gem or a binary). Config in `lefthook.yml`, installs itself, handles staged-file globs and parallelism. One more dependency, and it does the staged-file plumbing correctly instead of hand-rolled `git diff --cached` parsing.
3. **`overcommit`**. More established in Ruby, heavier, wants to manage the whole hook directory and has a signature-verification step people find annoying.

Recommendation: start with option 1. The hook is roughly ten lines, the repo has no hook tooling today (verified: no `lefthook.yml`, no `.overcommit.yml`, no `husky`, no `core.hooksPath` set), and adding a dependency to run two commands is hard to justify. Revisit `lefthook` only if the script grows.

### Escape hatch

`git commit --no-verify` must keep working, and the hook should say so when it fails, otherwise someone mid-rebase with a broken tree gets stuck. Do not try to defeat it.

## Sketch

```sh
#!/usr/bin/env bash
set -eu

if ! git diff --cached --name-only --diff-filter=ACM | grep -qE '\.(erb|html)$'; then
  exit 0
fi

echo "Linting HTML+ERB templates..."
bundle exec herb lint || {
  echo "herb lint failed. Fix the offenses, or commit with --no-verify."
  exit 1
}
```

Note `herb lint` shells out to `npx @herb-tools/linter`, so the hook needs Node on PATH. On a machine without it the hook should skip with a warning rather than block the commit, since not every contributor setup is guaranteed to have it.

## Watch out for

- **The gem is in `:development, :test`.** A hook running in an environment where the bundle was installed with `BUNDLE_WITHOUT=development:test` will fail on a missing binstub. Guard on `bundle exec herb --version` succeeding.
- **Staged vs working tree.** The sketch above lints the working tree, not the staged snapshot. If someone stages a fix but leaves a broken working copy, the hook reports an offense that is not in the commit. Living with that is fine for a solo repo; a stash-based or `git stash create` approach is the correct fix if it becomes annoying.
- **Do not duplicate CI as a hook.** The hook is a fast local filter, not a second gate. CI stays the authority.

## Done when

Touching a view and committing an offense fails locally with a message naming the rule, `--no-verify` still works, `bin/setup` sets `core.hooksPath`, and the README says one line about it.
