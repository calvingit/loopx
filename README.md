# loopx

English | [简体中文](./README.zh-CN.md)

`loopx` is a lightweight long-running task runner for Codex CLI. It keeps Codex TUI inside a `tmux` session, watches for common transient failures, waits with backoff, and continues the current task instead of forcing you to restart it manually.

Key capabilities:

- Normal Codex tasks are the default; `/goal` is optional
- `--goal` resumes interrupted goals with `/goal resume`
- Automatic recovery for capacity, 429/rate limit, 5xx, and network failures
- The current directory is the default workspace; `--dir` can override it
- Arguments after `--` are passed through to `codex`
- Recovery stays in the same Codex TUI/thread whenever possible

## Requirements

- Bash
- Codex CLI
- `tmux`

On macOS:

```bash
brew install tmux
```

## Installation

The recommended installer chooses a writable destination, validates the downloaded script with `bash -n`, installs it atomically, and checks whether `tmux` and `codex` are available. It does not install third-party dependencies automatically.

Quick install:

```bash
curl -fsSL https://raw.githubusercontent.com/calvingit/loopx/main/install.sh | bash
```

If you prefer to inspect the installer first:

```bash
curl -fsSL https://raw.githubusercontent.com/calvingit/loopx/main/install.sh -o /tmp/loopx-install.sh
less /tmp/loopx-install.sh
bash /tmp/loopx-install.sh
```

Custom install prefix:

```bash
PREFIX="$HOME/.local" bash /tmp/loopx-install.sh
```

Default destination policy:

1. If `PREFIX` is set, install to `$PREFIX/bin/loopx`.
2. Otherwise use `/usr/local/bin/loopx` when `/usr/local/bin` is writable.
3. Otherwise fall back to `~/.local/bin/loopx`.

The installer warns if the selected directory is not in `PATH`.

## Normal tasks

Normal Codex tasks are the default mode:

```bash
cd ~/projects/my-app
loopx "Fix the failing tests and verify the result"
```

Specify a workspace explicitly:

```bash
loopx --dir ~/projects/my-app "Review the current changes and fix issues"
```

Pass a multi-line prompt or a file:

```bash
loopx --prompt "$(cat task.md)"
```

When a retryable failure occurs, `loopx` does not replay the original prompt. It sends a continuation prompt in the same TUI thread to reduce the chance of repeating already completed work.

## Goal mode

Use `--goal` only when you want Codex `/goal` mode:

```bash
loopx --goal "Implement SPEC.md until all success criteria pass"
loopx --goal --prompt "$(cat GOAL.md)"
```

After a retryable failure, Goal mode waits and then sends `/goal resume`.

## Passing Codex arguments

Use the standard `--` separator. Everything after it is passed to `codex`:

```bash
loopx "Review and fix the current code" -- --search -m MODEL
loopx --dir ~/projects/app "Finish the task" -- -c 'model_reasoning_effort="high"'
```

Workspace selection is owned by `loopx --dir`, so Codex `-C` / `--cd` arguments are intentionally rejected.

Codex startup arguments cannot be changed for an already running session. Stop it first, then start a new session with different Codex arguments.

## Session management

```bash
loopx status
loopx attach
loopx stop
```

You can combine these commands with `--dir` or `--session` to select a specific session.

## Error classification and recovery

| Class | Default behavior |
| --- | --- |
| `capacity` | Retry automatically, exponential backoff from 10s up to 300s, unlimited retries by default |
| `rate_limit` | Retry from 10s; honor `Retry-After` when present |
| `server` | Retry 500/502/503/504-style failures from 10s |
| `network` | Retry network/timeout/stream failures from 10s, unlimited retries by default |
| `usage_limit` | Wait 1800s before retrying by default |
| `auth` | Stop automatic recovery |
| `quota` | Stop automatic recovery |
| `policy` | Stop automatic recovery |
| `context` | Stop automatic recovery |
| `goal_state` | Stop automatic recovery in Goal mode |

Test the classifier directly:

```bash
loopx classify "Selected model is at capacity. Please try a different model."
```

## Environment variables

`loopx` supports `LOOPX_RESET_AFTER`, `LOOPX_POLL_INTERVAL`, `LOOPX_STARTUP_DELAY`, `LOOPX_CONTINUE_PROMPT`, plus per-error retry settings for capacity, rate limit, server, network, and usage limit.

See all defaults and descriptions with:

```bash
loopx --help
```

## Limitations

`loopx` currently detects errors by reading Codex TUI/tmux output, so classification depends on Codex error messages. It is a practical recovery layer around the current Codex CLI, not an official Codex Goal lifecycle API.

## License

MIT
