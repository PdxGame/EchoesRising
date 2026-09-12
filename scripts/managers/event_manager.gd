extends Node
## EventManager — 全局信号总线（Autoload 单例，项目唯一保留的旧模块）
##
## 职责：解耦各模块之间的通信。发射用 EventManager.xxx.emit(...)，订阅用 EventManager.xxx.connect(callable)。
##
## 2026-08 重构说明：项目从横版过关改为纵向跳跃攀登玩法，旧机关/Debuff/收集信号已全部清空。
## 约定：新模块开发时才在这里追加它需要的信号，不提前造大而全的 API（对齐 AGENTS.md 增量原则）。
##
## 使用示例：
##   # 订阅
##   func _ready() -> void:
##       EventManager.player_died.connect(_on_player_died)
##   # 发射
##   EventManager.player_died.emit()


# ── 玩家生命周期（跳跃玩法通用，预置） ────────────────────
## 玩家死亡（掉落/触碰危险），重生逻辑监听后处理
signal player_died
## 已重生（携带重生位置）
signal player_respawned(spawn_position: Vector2)
