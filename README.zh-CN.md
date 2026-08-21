# loopx

[English](./README.md) | 简体中文

`loopx` 是一个面向 Codex CLI 的轻量长任务运行器。它把 Codex TUI 放进 `tmux` 会话中，监听常见临时错误，并在等待后自动继续当前任务。

主要能力：

- 不提供提示词时，直接打开可交互的 Codex TUI
- 默认支持普通 Codex 任务，不强制使用 `/goal`
- 使用 `--goal` 时通过 `/goal resume` 恢复 Goal
- capacity、429、5xx、网络错误自动退避重试
- 默认 workspace 是运行 `loopx` 时的当前目录，也可用 `--dir` 指定
- `--` 之后的参数原样透传给 `codex`
- 保持在同一个 Codex TUI/thread 中继续，避免重新启动整个任务
- 忽略 `Conversation interrupted` 等用户主动中断

## 依赖

- Bash
- Codex CLI
- `tmux`

macOS：

```bash
brew install tmux
```

## 安装

推荐使用安装脚本。它会自动选择可写的安装目录、验证下载内容和 Bash 语法，并检查 `tmux` / `codex` 是否存在，但不会自动安装第三方依赖。

快速安装：

```bash
curl -fsSL https://raw.githubusercontent.com/calvingit/loopx/main/install.sh | bash
```

也可以先下载并检查：

```bash
curl -fsSL https://raw.githubusercontent.com/calvingit/loopx/main/install.sh -o /tmp/loopx-install.sh
less /tmp/loopx-install.sh
bash /tmp/loopx-install.sh
```

自定义安装前缀：

```bash
PREFIX="$HOME/.local" bash /tmp/loopx-install.sh
```

默认安装策略：设置 `PREFIX` 时安装到 `$PREFIX/bin/loopx`；否则优先使用可写的 `/usr/local/bin`，不可写时回退到 `~/.local/bin`。

## 交互模式

不提供提示词时，`loopx` 会直接打开 Codex TUI：

```bash
loopx
loopx --dir ~/projects/my-app
loopx -- --yolo
```

用户可以像直接执行 `codex` 一样正常对话。watchdog 会继续监听真正的临时故障，并在同一个 TUI thread 中恢复当前任务；`Conversation interrupted`、用户主动取消、Esc/Ctrl-C 等交互中断会被忽略，不触发自动恢复。

## 普通任务

默认就是普通 Codex 任务：

```bash
cd ~/projects/my-app
loopx "修复当前分支的测试失败，并验证结果"
```

显式指定 workspace：

```bash
loopx --dir ~/projects/my-app "检查当前改动并修复问题"
```

多行提示词或文件内容：

```bash
loopx --prompt "$(cat task.md)"
```

普通任务遇到可重试错误后，`loopx` 不会重放原始提示词，而是在同一个 TUI thread 中发送继续提示词。

## Goal 模式

只有显式传入 `--goal` 时才使用 Codex `/goal`：

```bash
loopx --goal "实现 SPEC.md，直到所有 success criteria 通过"
loopx --goal --prompt "$(cat GOAL.md)"
```

Goal 遇到可重试错误后，`loopx` 会等待并发送 `/goal resume`。

## 透传 Codex 参数

使用标准 `--` 分隔符，之后的参数全部传给 `codex`：

```bash
loopx "检查并修复当前代码" -- --search -m MODEL
loopx --dir ~/projects/app "完成任务" -- -c 'model_reasoning_effort="high"'
```

workspace 统一由 `loopx --dir` 管理，因此不允许透传 Codex 的 `-C` / `--cd`。

## 会话管理

```bash
loopx status
loopx attach
loopx stop
```

也可以配合 `--dir` 或 `--session` 定位会话。

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
| `user_interrupt` | 忽略，不重试，也不增加重试计数 |

可以独立测试分类器：

```bash
loopx classify "Selected model is at capacity. Please try a different model."
```

## 环境变量

支持 `LOOPX_RESET_AFTER`、`LOOPX_POLL_INTERVAL`、`LOOPX_STARTUP_DELAY`、`LOOPX_CONTINUE_PROMPT`，以及 capacity、rate limit、server、network、usage limit 对应的 `*_BASE_DELAY`、`*_MAX_DELAY`、`*_MAX_RETRIES` 配置。

完整默认值和逐项说明：

```bash
loopx --help
```

## 限制

`loopx` 当前通过读取 Codex TUI/tmux 输出文本来识别错误，因此错误分类依赖 Codex 的错误文案。它适合作为当前 Codex CLI 的实用恢复层，但不是 Codex 官方的 Goal lifecycle API。

## License

MIT
