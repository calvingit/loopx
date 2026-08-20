# loopx

`loopx` 是一个面向 Codex CLI 的轻量长任务运行器。它把 Codex TUI 放进 `tmux` 会话中，监听常见临时错误，并在等待后自动继续当前任务。

主要目标：

- 默认支持普通 Codex 任务，不强制使用 `/goal`
- 使用 `--goal` 时通过 `/goal resume` 恢复 Goal
- capacity、429、5xx、网络错误自动退避重试
- 默认 workspace 是运行 `loopx` 时的当前目录，也可用 `--dir` 指定
- `--` 之后的参数原样透传给 `codex`
- 保持在同一个 Codex TUI/thread 中继续，避免重新启动整个任务

## 依赖

- Bash
- [Codex CLI](https://developers.openai.com/codex/cli/)
- `tmux`

macOS：

```bash
brew install tmux
```

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/calvingit/loopx/main/loopx -o /usr/local/bin/loopx
chmod +x /usr/local/bin/loopx
```

如果 `/usr/local/bin` 不可写，也可以安装到 `~/.local/bin`。

## 普通任务

默认就是普通 Codex 任务：

```bash
cd ~/projects/my-app
loopx "修复当前分支的测试失败，并验证结果"
```

也可以显式指定 workspace：

```bash
loopx --dir ~/projects/my-app "检查当前改动并修复问题"
```

多行提示词或文件内容：

```bash
loopx --prompt "$(cat task.md)"
```

普通任务遇到可重试错误后，`loopx` 不会重放原始提示词，而是在同一个 TUI thread 中发送继续提示词，尽量避免重复执行已经完成的工作。

## Goal 模式

只有显式传入 `--goal` 时才使用 Codex `/goal`：

```bash
loopx --goal "实现 SPEC.md，直到所有 success criteria 通过"
```

或：

```bash
loopx --goal --prompt "$(cat GOAL.md)"
```

Goal 遇到可重试错误后，`loopx` 会等待并发送：

```text
/goal resume
```

## 透传 Codex 参数

使用标准 `--` 分隔符。`--` 之后的参数全部传给 `codex`：

```bash
loopx "修复测试" -- --yolo

loopx --goal "实现 SPEC.md" -- --yolo

loopx "检查并修复当前代码" -- \
  --search \
  -m MODEL
```

workspace 统一由 `loopx --dir` 管理，因此不允许透传 Codex 的 `-C` / `--cd`：

```bash
loopx --dir ~/projects/app "修复测试" -- --yolo
```

如果 Codex/tmux 会话已经启动，新的 Codex 启动参数不会动态生效。要修改启动参数，先停止当前会话：

```bash
loopx stop
loopx "继续任务" -- --yolo
```

## 会话管理

```bash
# 查看状态
loopx status

# 重新进入 TUI
loopx attach

# 停止 watchdog 和 tmux 会话
loopx stop
```

指定 workspace：

```bash
loopx status --dir ~/projects/my-app
loopx attach --dir ~/projects/my-app
loopx stop --dir ~/projects/my-app
```

指定 session：

```bash
loopx --session frontend "检查当前改动"
loopx status --session frontend
```

## 错误分类与恢复

| 分类 | 默认行为 |
| --- | --- |
| `capacity` | 自动重试，10s 起指数退避，最大 300s，默认不限次数 |
| `rate_limit` | 自动重试，10s 起；优先遵守 `Retry-After` |
| `server` | 500/502/503/504 等自动重试，10s 起 |
| `network` | 网络/timeout/stream 中断自动重试，10s 起，默认不限次数 |
| `usage_limit` | 默认等待 1800s 后重试 |
| `auth` | 停止自动恢复 |
| `quota` | 停止自动恢复 |
| `policy` | 停止自动恢复 |
| `context` | 停止自动恢复 |
| `goal_state` | Goal 模式下停止自动恢复 |

可以独立测试分类器：

```bash
loopx classify "Selected model is at capacity. Please try a different model."
```

## 环境变量

```text
LOOPX_RESET_AFTER=600
LOOPX_POLL_INTERVAL=2
LOOPX_STARTUP_DELAY=2
LOOPX_CONTINUE_PROMPT=...

LOOPX_CAPACITY_BASE_DELAY=10
LOOPX_CAPACITY_MAX_DELAY=300
LOOPX_CAPACITY_MAX_RETRIES=0

LOOPX_RATE_BASE_DELAY=10
LOOPX_RATE_MAX_DELAY=900
LOOPX_RATE_MAX_RETRIES=30

LOOPX_SERVER_BASE_DELAY=10
LOOPX_SERVER_MAX_DELAY=180
LOOPX_SERVER_MAX_RETRIES=20

LOOPX_NETWORK_BASE_DELAY=10
LOOPX_NETWORK_MAX_DELAY=120
LOOPX_NETWORK_MAX_RETRIES=0

LOOPX_USAGE_DELAY=1800
LOOPX_USAGE_MAX_RETRIES=48
```

所有变量的详细含义可查看：

```bash
loopx --help
```

## 说明

`loopx` 当前通过读取 Codex TUI/tmux 输出文本来识别错误，因此错误分类依赖 Codex 的错误文案。它适合作为当前 Codex CLI 的实用恢复层，但不是 Codex 官方的 Goal lifecycle API。
