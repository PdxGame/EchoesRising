# gdmcp CLI 使用指南（Godot 编辑器 MCP 客户端）

> 本项目 gdmcp 用法速查（由 opencode `skills/gdmcp` 移植并精简）。项目流程约定以 `AGENTS.md` 为准，本文件只讲 gdmcp 本身及与其强相关的落地要点。

## 说明

gdmcp 是 Godot MCP Native 插件的命令行客户端。需要「正在运行的 Godot 编辑器」配合的操作（检查/编辑场景、节点、脚本、资源、运行调试），统一用 gdmcp 处理，不加载完整 MCP 工具目录。
项目根目录 PowerShell 调用：`.\ .gdmcp\bin\gdmcp.exe`（示例中写作 `gdmcp`）。`.gdmcp/` 已 gitignore，仅供本机开发。

## 配置发现

在项目根目录运行即可：CLI 自动发现 `project.godot`，并读取 Godot `user://mcp_settings.cfg` 持久化的 HTTP 端口（兜底 `http://127.0.0.1:9080`）。
非项目根目录时：`gdmcp --project-path <根目录> --godot-user-data-dir <user-data根> --json doctor`。

## 快速开始

```bash
gdmcp --json doctor
gdmcp --json editor state
```

## 常用命令

```bash
gdmcp --json scenes current                     # 当前场景（含 is_modified）
gdmcp --json scenes list --limit 20
gdmcp --json scenes tree --depth 4
gdmcp --json nodes list --limit 20
gdmcp --json nodes get /root/Main/Player --fields position,visible
gdmcp --json nodes properties set /root/Main/Player --property speed --value 300
gdmcp --json scripts list --limit 20
gdmcp --json scripts read res://player.gd --lines 1:200
gdmcp --json scripts create res://new_script.gd --script-type GDScript
gdmcp --json resources list --limit 20
gdmcp --json resources get res://player.tres --fields resource_path
gdmcp --json project settings --filter display/
gdmcp --json debug logs --limit 50
gdmcp --json runtime tree --depth 4
gdmcp --json runtime nodes get /root/Main/Player
```

名称转稳定路径（免 tool-call）：

```bash
gdmcp --json nodes resolve Player
gdmcp --json scenes resolve Main
gdmcp --json scripts resolve player
gdmcp --json resources resolve icon
```

节点重构：

```bash
gdmcp --json nodes move /root/Main/Player --new-parent /root/World
gdmcp --json nodes rename /root/Main/Enemy1 --new-name Boss
```

领域命令没有时，渐进式发现：

```bash
gdmcp --json tools search "<意图>" --limit 5
gdmcp --json tools schema <工具名>
gdmcp --json tool-call <工具名> --args-file <request.json>
```

## 规则

- 输出需程序化分析时用 `--json`；优先领域命令，少用裸 `tool-call`。
- 用 `--limit / --depth / --fields / --lines / --out` 控制输出量，不拉全量目录。
- 渐进式翻页：`scripts list --limit <n> [--cursor <c>]`、日志 `debug logs --cursor <offset>`（列表默认 50 条）。
- `project settings` 必须带 `--filter <前缀>`。
- 破坏性命令要 `--apply`；先 `batch preview` 再 `batch apply`。
- 运行时/open-world 工具要 `--allow-open-world`。
- token 只经 `GODOT_MCP_TOKEN` 传入、绝不打印（本机 localhost 默认免 token）。

更多任务流程见 DSH 技能目录 `~/.dsh/skills/gdmcp/references/command-workflows.md`。

## 本项目落地要点（只列与 gdmcp 强相关，其余见 AGENTS.md）

- 改场景前先 `scenes current` 看 `is_modified`：有未保存改动先保存或与用户确认，不外部改写文件/强制重载。
- 测试采用明确授权制：除非用户在当次请求中明确要求测试，否则不得启动项目、运行场景、模拟输入、截取运行截图或进行玩法验证。实现完只做必要的静态检查，并汇报「建议测试什么」。
- gdmcp 经 PowerShell 调用需写全路径；沙箱内禁止直接启动 Godot 引擎进程，一律通过 gdmcp 与已运行的编辑器交互。
