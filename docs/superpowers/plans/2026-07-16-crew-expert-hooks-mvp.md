# Crew 专家钩子 (MVP) Implementation Plan

> **For agentic workers:** 用 TDD 逐任务实现。每个任务：先写/改测试 → 实现到测试通过 → commit。步骤用 `- [ ]` 复选框跟踪。**本计划只在 `crew_core` 里落"钩子"**，不实现专家池/提炼本身（那是 P2/P3，见 `specs/2026-07-16-crew-expert-pool-design.md`）。

**Goal:** 让"专家会成长"在 MVP 当场可感知，并为将来"提炼/专家池"铺好数据与格式，届时不返工。三件事：
1. **记忆系统分层**——`solved/`(解决过的问题) + `playbooks/`(套路) + 召回式索引。
2. **AgentSpec 扩展 + 中性序列化**——加人格/判断标准/技术栈/SDK/重难点/来源字段 + `toJson/fromJson` 往返（将来 `expert.json` 的核心搬运单元）。
3. **成长约定内置**——渲染出"开工召回 + 收工蒸馏"约定，让自动成长闭环当场能跑。

**Architecture（不变）:** 探查(Runner) → `AgentSpec` 中间表示 → 多 `OutputAdapter` 渲染 → `WritePlanner` 落盘（保护 `memory/**`）。本计划只**扩展** `AgentSpec` 字段、**增强** `MemoryAdapter` 与 `agent_body`，不改管线结构。

**Tech Stack:** Dart 3 纯包（无 Flutter）；依赖仅 `yaml`/`path`；测试 `package:test`。

## Global Constraints

- 不得依赖 `package:flutter`。依赖不新增（仅 `yaml`/`path`/`test`）。
- **记忆保护不变**：所有记忆产物 `FileArtifact(..., isMemory: true)`，由 `WritePlanner` 保证已存在则 `skip`（`crew_core/lib/src/engine/write_planner.dart:47`）。
- **多格式同源不变**：agent 正文仍由 `renderAgentBody`（`agent_body.dart`）单一函数渲染，Claude/Codex 共用。
- **无库内 `DateTime.now()`**：任何时间戳由调用方/probe 输入传入，保证测试确定性。
- 新增对外类型/函数从 `crew_core/lib/crew_core.dart` barrel 导出。
- **向后兼容**：`AgentSpec` 新增字段一律带默认值（空字符串/空列表/默认枚举），现有测试与 `fromProbeJson`(缺字段) 不得回归。

## 现状锚点（实现前先读）

- `crew_core/lib/src/models/agent_spec.dart` — `AgentSpec` + `KeyFile` + `fromProbeJson`（本计划在此加字段与序列化）。
- `crew_core/lib/src/adapters/memory_adapter.dart` — 目前只出 `MEMORY.md` + `project-notes.md`（扁平），本计划改成分层。
- `crew_core/lib/src/adapters/agent_body.dart` — agent 正文渲染，本计划加人格/判断标准/技术栈/SDK/重难点/成长约定 section。
- `crew_core/lib/src/runner/probe_parser.dart` + `fromProbeJson` — probe JSON → AgentSpec，本计划扩展解析。
- `crew_core/lib/src/adapters/docs_adapter.dart` — 团队文档（可选：加成长约定，Task 4）。

---

## File Structure（本计划新增/改动）

```
crew_core/lib/src/
├── models/agent_spec.dart          # [改] 加字段 + toJson/fromJson + fromProbeJson 扩展
├── adapters/memory_adapter.dart    # [改] 分层：MEMORY.md/project-notes/solved/playbooks + 模板
├── adapters/agent_body.dart        # [改] 渲染人格/判断标准/技术栈/SDK/重难点 + 成长约定
└── adapters/docs_adapter.dart      # [改, 可选] 团队 AGENTS.md/CLAUDE.md 加成长约定
crew_core/test/
├── models/agent_spec_test.dart     # [改] 新字段 + 序列化往返 + probe 解析
├── adapters/memory_adapter_test.dart      # [改] 分层产物断言
└── adapters/agent_body_test.dart          # [改] 新 section 断言
```

---

### Task 1: AgentSpec 扩展字段 + 中性序列化

**Files:**
- Modify: `crew_core/lib/src/models/agent_spec.dart`
- Modify: `crew_core/test/models/agent_spec_test.dart`

**Interfaces:**
- Produces: `AgentSpec` 新增字段 + `Map<String,dynamic> toJson()` / `factory AgentSpec.fromJson(Map)`；`fromProbeJson` 解析新字段。这是将来 `expert.json` 的核心搬运单元。

**新增字段（全部带默认值，向后兼容）：**

| 字段 | 类型 | 默认 | 含义 |
|------|------|------|------|
| `personality` | `String` | `''` | 人格/性格（写进 IDENTITY 维度） |
| `principles` | `List<String>` | `const []` | 判断标准/品味/质量红线 |
| `techStack` | `List<String>` | `const []` | 技术栈 |
| `sdks` | `List<String>` | `const []` | 用到的 SDK/三方库 |
| `difficulties` | `List<String>` | `const []` | 重难点清单 |
| `source` | `String` | `'private'` | 项目来源：`opensource` \| `private`（隐私钩子） |
| `github` | `String` | `''` | 开源仓库地址（仅 opensource 有意义） |

- [x] **Step 1: 先写测试（红）**
  - 往返：构造一个填满所有字段（含 `keyFiles`）的 `AgentSpec` → `toJson()` → `AgentSpec.fromJson(...)`，断言所有字段逐一相等（含 `keyFiles` 的 `path/purpose`）。
  - 缺省兼容：`AgentSpec.fromJson({'name':'x','displayName':'y','repos':[]})` 不抛异常，新字段取默认值。
  - probe 解析：`fromProbeJson` 传入含 `personality/principles/techStack/sdks/difficulties/source/github` 的 map → 断言解析到位；不含这些字段时取默认值（保护现有 probe 用例不回归）。
- [x] **Step 2: 实现字段 + 构造器**（新字段在构造器里默认可选，不破坏现有 `const AgentSpec(...)` 调用方——检查 `builtin_templates.dart`/`fake_runner.dart` 等是否有直接构造，若有则补默认或改调用）。
- [x] **Step 3: 实现 `toJson()` / `fromJson()`**（`keyFiles` 序列化为 `[{path,purpose}]`）。
- [x] **Step 4: 扩展 `fromProbeJson`** 解析新字段（沿用现有 `strList` 辅助）。
- [x] **Step 5: barrel 无需改（已导出 agent_spec）**；`cd crew_core && dart test test/models/agent_spec_test.dart` 通过。
- [x] **Step 6: 全量回归** `dart test` 全绿。Commit。

**Acceptance（验收标准）:**
- `toJson`→`fromJson` 往返对所有字段（含 keyFiles、source、github）无损。
- 旧调用/旧 probe JSON（无新字段）不回归，新字段取默认。
- `dart test` 全绿。

---

### Task 2: 记忆系统分层 + 召回/蒸馏模板

**Files:**
- Modify: `crew_core/lib/src/adapters/memory_adapter.dart`
- Modify: `crew_core/test/adapters/memory_adapter_test.dart`

**Interfaces:**
- Produces: 每个 agent 产出分层记忆骨架，全部 `isMemory: true`（受保护）：
  - `memory/<name>/MEMORY.md` — **召回式索引**：说明"开工先读本文件、用症状关键词 grep `solved/` 与 `playbooks/`；命中即复用/秒解"，并含初始指针。
  - `memory/<name>/project-notes.md` — 语义记忆（现有，保留：角色 + 关联目录 + 技术栈/SDK 若有）。
  - `memory/<name>/solved/README.md` — 情景记忆**条目模板**（含 §8.2 的 frontmatter：症状/关键词/时间/结果/来源/source + 根因/解法/关联）。
  - `memory/<name>/playbooks/README.md` — 程序记忆**套路模板**（何时用、步骤、来自哪些 solved）。

- [x] **Step 1: 先写测试（红）** —— 给一个含 2 个 spec 的 `GenerationResult`，`MemoryAdapter().render(result)`，断言：
  - 产出 4 类路径均存在且 `isMemory == true`。
  - `MEMORY.md` 文本含"召回/grep/症状"等关键词（断言召回约定在场），含指向 `project-notes.md` 的指针。
  - `solved/README.md` 含 frontmatter 字段名（`症状`/`关键词`/`根因`/`解法`）。
  - `playbooks/README.md` 含"套路/何时用/步骤"。
- [x] **Step 2: 实现** —— 重写 `render`，为每个 spec 生成上述 4 文件。`solved/`、`playbooks/` 用 `README.md` 承载模板（既建目录又给示范）。
- [x] **Step 3:** `dart test test/adapters/memory_adapter_test.dart` 通过；全量 `dart test` 全绿。Commit。

**Acceptance:**
- 4 类记忆文件齐全、均 `isMemory: true`（确保 `WritePlanner` 重生成时 `skip`，不覆盖用户记忆——可在测试中额外断言 `isMemory`）。
- `MEMORY.md` 明确写出"开工召回"的用法（grep 症状关键词）。
- `solved`/`playbooks` 模板字段与设计 §8.2 一致。

---

### Task 3: agent_body 渲染新维度 + 成长约定

**Files:**
- Modify: `crew_core/lib/src/adapters/agent_body.dart`
- Modify: `crew_core/test/adapters/agent_body_test.dart`

**Interfaces:**
- Produces: `renderAgentBody(AgentSpec)` 在现有 section（项目坐标/模块结构/关键文件/数据流/记忆/工作约定）基础上新增：
  - **人格与判断标准**（`personality` + `principles`）——即 IDENTITY 维度。
  - **技术栈 / SDK / 重难点**（`techStack` / `sdks` / `difficulties`）——即 COMPETENCE 维度补充。
  - **成长约定**（固定文案，不依赖字段）——开工召回 + 收工蒸馏闭环，让自动成长当场可跑。

- [x] **Step 1: 先写测试（红）:**
  - 填了 `personality/principles/techStack/sdks/difficulties` 的 spec → body 含对应标题与内容。
  - 这些字段为空时，对应 section **不出现**（沿用现有 `section()` 空则跳过的约定）。
  - body 恒含"成长约定"段，且含"开工"/"召回"/"收工"/"蒸馏"/"solved"/"playbooks"等关键词（约定固定文案）。
- [x] **Step 2: 实现** —— 复用现有 `section()` 辅助渲染可空维度；成长约定用固定文案段落，明确写出：
  - 开工：读 `memory/<name>/MEMORY.md` → 用症状关键词 grep `solved/`、`playbooks/` → 命中即复用/秒解。
  - 收工：新问题写 `solved/`；新事实更新 `project-notes`；某类问题 ≥2 次 → 提炼 `playbooks/`；更新 `MEMORY.md` 索引；过时/错误记忆改或删。
  - 放置顺序建议：人格/判断标准 → 项目坐标/模块/技术栈/SDK/重难点/关键文件/数据流 → 成长约定 → 工作约定。
- [x] **Step 3:** `dart test test/adapters/agent_body_test.dart` 通过；全量 `dart test` 全绿。Commit。

**Acceptance:**
- 新维度按字段有无正确出现/隐藏。
- 成长约定段恒在，且开工召回、收工蒸馏两半都写全（含 solved/playbooks 分层）。
- Claude 与 Codex 输出因共用 `renderAgentBody` 自动同源（无需分别改）。

---

### Task 4（可选，低优先）: 团队文档补成长约定

**Files:**
- Modify: `crew_core/lib/src/adapters/docs_adapter.dart`
- Modify: `crew_core/test/adapters/docs_mcp_adapter_test.dart`

**Interfaces:**
- Produces: 团队级 `AGENTS.md`/`CLAUDE.md` 增一段"团队记忆与成长约定"，重申开工召回/收工蒸馏，作为团队级强化（agent 正文已含，本段是团队层面的说明）。

- [x] **Step 1:** 先读 `docs_adapter.dart` 现有结构，测试断言团队文档含"记忆"/"召回"/"蒸馏"段。
- [x] **Step 2:** 实现；`dart test` 全绿。Commit。

**Acceptance:** 团队文档含成长约定段；不与 agent 正文冲突（措辞团队视角）。

> 若 MVP 时间紧，Task 4 可跳过——Task 1-3 已让钩子完整。

---

## 明确不做（本计划边界，避免 glm-5.2 越界）

- ❌ 不建全局专家池 `~/.crew/experts`、不写 `expert.json` 落盘、不实现 `publish/merge/instantiate/distill`（P2/P3）。
- ❌ 不加 `Expert` model、不改 `Runner` 接口、不动 `generation_pipeline` 结构。
- ❌ `crew.yaml`/`CrewConfig` 本计划**不改**（source/privacy 先只落在 `AgentSpec`；crew.yaml 记录留到 P2）。
- ❌ 不碰 `crew_gui`（本计划纯 `crew_core`）。

> 本计划的价值恰在"小而不返工"：只扩 `AgentSpec` 字段+序列化、增强两个 Adapter。P2/P3 的专家池直接消费这些字段与记忆结构。

---

## 验收（由 Claude 负责，实现完成后执行）

实现方（glm-5.2）完成后，Claude 按下列清单验收：

1. **测试全绿**：`cd crew_core && dart test` 全部通过，无跳过。
2. **Task 1**：`AgentSpec` 往返序列化无损（读测试确认覆盖所有新字段含 keyFiles/source/github）；旧 probe JSON 无回归。
3. **Task 2**：临时目录跑一次 `MemoryAdapter`，确认产出 `MEMORY.md`+`project-notes.md`+`solved/README.md`+`playbooks/README.md` 且全 `isMemory:true`；`MEMORY.md` 含召回用法。
4. **Task 3**：渲染一个满字段 spec 与一个空字段 spec，肉眼核对 body：满字段各 section 在场、空字段隐藏、成长约定两半齐全。
5. **同源一致**：Claude 与 Codex adapter 对同一 spec 的 agent 正文一致（共用 `renderAgentBody`）。
6. **约束合规**：无新依赖、无 `package:flutter`、无库内 `DateTime.now()`、新增类型已从 barrel 导出。
7. **边界合规**：未触碰"明确不做"清单中的文件/能力。

验收通过后，Claude 更新本文件把任务 `- [ ]` 勾为 `- [x]` 并记录验收结论。

---

## 验收结论（Claude，2026-07-16）

**通过 ✅** —— 提交 `5c6db11`。`cd crew_core && dart test` = **52 passed, 0 skipped**。

| 验收项 | 结论 |
|--------|------|
| 1. 测试全绿 | ✅ 52 通过，无跳过 |
| 2. Task 1 序列化 | ✅ `toJson→fromJson` 覆盖全字段（含 keyFiles/source/github）；probe 新字段解析 + 缺省默认；旧 probe 无回归（`agent_spec_test.dart` 7 例） |
| 3. Task 2 记忆分层 | ✅ 每 agent 出 `MEMORY.md`+`project-notes.md`+`solved/README.md`+`playbooks/README.md`，全部 `isMemory:true`；`MEMORY.md` 含召回用法（grep/症状）；模板字段对齐 spec §8.2 |
| 4. Task 3 正文维度 | ✅ 人格/判断标准/技术栈/SDK/重难点按字段有无正确显隐；成长约定段恒在，开工召回+收工蒸馏两半齐全、含 solved/playbooks |
| 5. 同源一致 | ✅ Claude/Codex 共用 `renderAgentBody`，adapter 测试断言一致 |
| 6. 约束合规 | ✅ 无新依赖、无 `package:flutter`、无库内 `DateTime.now()`、无需新增 barrel 导出 |
| 7. 边界合规 | ✅ 未碰 `CrewConfig`/`generation_pipeline`/`Runner`/`crew_gui`；Task 4 仅在 `docs_adapter` 追加团队约定段 |

**非阻塞的可选优化（留给后续，不影响验收）：**
- `memory_adapter.dart:39` 的局部函数 `notes_buffer` 用了 snake_case（非 Dart 惯例，建议 `lowerCamelCase`），且 `if/else` 两支重复了 `project-notes.md` 的 `FileArtifact` 添加，可合并为先构建正文字符串再统一 add。纯风格问题，功能与测试均正常。
