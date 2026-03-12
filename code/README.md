# SRPG Roguelike MVP (Godot 4)

这是根据 `doc/plan.md` 生成的一版 Godot 项目骨架，包含关键系统与测试样例。

## 已实现模块

- `scripts/core/BattleController.gd`：回合状态机（玩家回合/敌方回合/胜负）
- `scripts/core/GridService.gd`：网格地形、寻路、可控随机地图约束校验
- `scripts/core/UnitEntity.gd`：单位基础属性与伤害结算入口
- `scripts/core/CombatResolver.gd`：命中/暴击/伤害/反击预览与结算
- `scripts/core/RewardSystem.gd`：战后三选一 + 保底倾斜逻辑
- `scripts/core/ManagementSystem.gd`：经营节点行动模型（行动点约束）
- `scripts/core/ModifierSystem.gd`：敌方词条分层生成（普通/精英/Boss）
- `scripts/core/ScenarioRunner.gd`：24关推进节奏（每2关经营、每6关Boss、Boss后商人）
- `scripts/core/BattleState.gd`：里程碑A对战编排（单位位置、行动、敌方自动回合）
- `scripts/battle_scene.gd`：可玩最小战斗场景（网格绘制、点击操作、回合切换）

## 测试覆盖（关键节点）

- `tests/TestBattleController.gd`
- `tests/TestGridService.gd`
- `tests/TestCombatResolver.gd`
- `tests/TestRewardSystem.gd`
- `tests/TestScenarioRunner.gd`
- `tests/TestBattleState.gd`

统一入口：`tests/test_runner.gd`

## 运行

### 启动项目

```bash
godot4 --path .

进入后可直接进行最小战斗：

- 左键点击我方单位进行选择
- 点击 `Move` 后，左键点击可达格移动
- 点击 `Attack` 后，左键点击敌人查看预览，再次点击同一目标确认攻击
- 点击 `Wait` 让当前单位待机（消耗本回合行动）
- 按 `Space` 或点击 `EndTurn` 结束我方回合并执行敌方回合

调试增强：

- 可通过右上角勾选框切换“每格移动消耗数字”显示
- 可在输入框中设置地块数量（`n*m`，如 `12*8`）并点击“应用地块数量”重建战场
- 应用新尺寸后会自动调整 Camera2D 视野，尽量完整展示当前地图
- 新增“锁定缩放/自动缩放”开关：锁定后使用输入框倍率，关闭后自动适配地图
- 右键任意格子查看固定信息面板（单位/地块详情）
- 面板内保留最近30条查看历史，便于调试对比
- 可在信息面板中将单位“设为对比基准”，查看其他单位属性差值
- 新增热力层切换（关闭 / 移动代价 / 可达区 / 危险区）
```

### 运行测试（headless）

```bash
godot4 --headless --path . -s res://tests/test_runner.gd
```

> 若你的可执行名不是 `godot4`，请替换为本机 Godot 4 可执行路径。
