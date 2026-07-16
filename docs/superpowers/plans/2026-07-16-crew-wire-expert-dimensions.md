# Crew 专家维度接线 Implementation Plan

> **For agentic workers:** 用 TDD 逐任务实现。每个任务：先写/改测试 → 实现到测试通过 → commit。步骤用 `- [ ]` 复选框跟踪。**本计划全部在 `crew_core`**（`crew_gui` 侧的自定义专家人格编辑作为跟进，见文末）。

**Goal:** 把上一批 MVP 钩子（`plans/2026-07-16-crew-expert-hooks-mvp.md`）**接上线**——让 `AgentSpec` 的 `personality/principles/techStack/sdks/difficulties` 在生成时真正被填充。当前状态是"通了电没接线"：字段和渲染都在，但**没有上游会填它们**，生成出来的专家这些维度恒为空。

**根因（实现前先确认）:**
- `builtin_templates.dart:4` 的 `_probeCommon` **没有**请求 `techStack/sdks/difficulties`，故 `fromProbeJson` 拿不到值。
- `AgentTemplate`（`agent_template.dart`）**没有** `personality/principles` 字段，`probe()`/`parseProbe`（`generation_pipeline.dart`/`probe_parser.dart`）也没有把模板人设注入 `AgentSpec` 的路径 → 人格/判断标准恒空。

**分工原则:** 人设是**预设**（来自模板，人工/AI 优化）；能力是**探查**出来的（来自 probe）。即：
- `personality` / `principles` ← **AgentTemplate 预设**（Task 1、3）
- `techStack` / `sdks` / `difficulties` ← **probe 探查**（Task 2）
- `source` / `github` ← 可选，来自静态探测（Task 4，可选）

**Architecture（不变）:** 探查(Runner) → `AgentSpec` → 多 `OutputAdapter` 渲染 → `WritePlanner` 落盘。本计划只扩展 `AgentTemplate`、`_probeCommon` 与 `probe()` 的合并逻辑，不改管线结构、不改 Runner 接口。

**Tech Stack:** Dart 3 纯包（无 Flutter）；依赖仅 `yaml`/`path`；测试 `package:test`。

## Global Constraints

- 不得依赖 `package:flutter`；不新增依赖。
- 无库内 `DateTime.now()`。
- **向后兼容**：`AgentTemplate` 新增字段带默认值（`''` / `const []`）；`parseProbe` 现有调用方（不传新参数）不得回归。
- 新增对外类型/成员从 `crew_core/lib/crew_core.dart` barrel 导出（`AgentTemplate`/`AgentSpec` 已导出，加成员无需改 barrel；若新增 `copyWith` 亦随类导出）。
- **人设优先级**：模板预设的 `personality/principles` 覆盖 probe JSON 里的同名字段（人设不由 LLM 探查决定）。

## 现状锚点（实现前先读）

- `crew_core/lib/src/models/agent_template.dart` — `AgentTemplate`（本计划加 `personality`/`principles`）。
- `crew_core/lib/src/templates/builtin_templates.dart` — `_probeCommon` + 6 个内置模板（本计划加探查字段 + 预设人设）。
- `crew_core/lib/src/models/agent_spec.dart` — `AgentSpec`（本计划加 `copyWith`）。
- `crew_core/lib/src/engine/generation_pipeline.dart:64` — `probe()` 里 `parseProbe(...)` 调用点（本计划注入模板人设）。
- `crew_core/lib/src/runner/fake_runner.dart` + `test/runner/fake_runner_test.dart` — 测试用 fake 探查输出（Task 2 需让它含新字段以覆盖管线）。

---

## File Structure（本计划改动）

```
crew_core/lib/src/
├── models/agent_template.dart      # [改] 加 personality + principles
├── models/agent_spec.dart          # [改] 加 copyWith
├── templates/builtin_templates.dart# [改] _probeCommon 加字段 + 6 模板填预设人设
├── runner/probe_parser.dart        # [改] parseProbe 支持注入 personality/principles（可选路径）
└── engine/generation_pipeline.dart # [改] probe() 注入模板人设到 AgentSpec
crew_core/test/
├── models/agent_template_test.dart # [改] 断言预设非空
├── models/agent_spec_test.dart     # [改] copyWith
├── templates/builtin_templates_test.dart  # [改] 探查 prompt 含新字段 + 模板有人设
└── engine/generation_pipeline_test.dart   # [改] 生成的 spec 同时含探查能力 + 模板人设
```

---

### Task 1: AgentTemplate 加人设字段 + 内置预设

**Files:**
- Modify: `crew_core/lib/src/models/agent_template.dart`
- Modify: `crew_core/lib/src/templates/builtin_templates.dart`
- Modify: `crew_core/test/models/agent_template_test.dart`
- Modify: `crew_core/test/templates/builtin_templates_test.dart`

**Interfaces:**
- Produces: `AgentTemplate.personality`（`String`，默认 `''`）、`AgentTemplate.principles`（`List<String>`，默认 `const []`）；6 个内置模板均填入预设。

- [x] **Step 1: 先写测试（红）**
  - `agent_template_test.dart`：构造带 `personality`/`principles` 的模板，断言字段可读；不传时取默认。
  - `builtin_templates_test.dart`：断言 `kBuiltinTemplates` 中每个模板 `personality` 非空且 `principles` 非空（`isNotEmpty`）。
- [x] **Step 2: 加字段**（`agent_template.dart` 构造器加 `this.personality = ''`, `this.principles = const []`）。
- [x] **Step 3: 填 6 个内置模板预设**（示例，可细化，测试只要求非空）：
  - `ios-dev` 小i — personality: `严谨、重性能与体验，偏保守不冒进`；principles: `['主线程不做阻塞 IO', '启动/内存敏感，改动先量化影响', '不引入未经验证的三方依赖']`
  - `android-dev` 小安 — personality: `务实、兼容性意识强`；principles: `['兼容低版本与碎片化机型', '警惕内存泄漏与 ANR', '权限/混淆改动先评估影响面']`
  - `frontend` 小前 — personality: `注重交互细节与可访问性，追求简洁`；principles: `['组件可复用、状态可预测', '关注包体积与首屏性能', '不破坏无障碍与响应式']`
  - `backend` 小后 — personality: `稳健，以数据一致性与可用性为先`；principles: `['接口幂等、失败可重试', '动数据库先想迁移与回滚', '边界输入一律校验']`
  - `python` 小P — personality: `简洁，重可读性与可测试性`；principles: `['显式优于隐式', '有类型标注与测试再上线', '依赖锁定版本']`
  - `pm` 产品 — personality: `全局视角，善协调与拆解需求`；principles: `['先对齐目标与验收标准再拆任务', '按目录把活派给对应专家', '关注跨端数据流一致性']`
- [x] **Step 4:** `dart test test/models/agent_template_test.dart test/templates/builtin_templates_test.dart` 通过；全量 `dart test` 全绿。Commit。

**Acceptance:**
- `AgentTemplate` 有 `personality`/`principles`，默认值向后兼容。
- 6 个内置模板全部有非空人设与判断标准。

---

### Task 2: 探查 prompt 请求能力维度

**Files:**
- Modify: `crew_core/lib/src/templates/builtin_templates.dart`（`_probeCommon`）
- Modify: `crew_core/lib/src/runner/fake_runner.dart`（让 fake 输出含新字段，供管线测试）
- Modify: `crew_core/test/templates/builtin_templates_test.dart`
- Modify: `crew_core/test/runner/fake_runner_test.dart`（若断言了 fake 输出结构）

**Interfaces:**
- Produces: `_probeCommon` 在 JSON 字段清单中新增 `techStack`(数组)、`sdks`(数组)、`difficulties`(重难点数组)；`FakeRunner` 默认输出含这三个字段。

- [x] **Step 1: 先写测试（红）**
  - `builtin_templates_test.dart`：断言每个模板 `probePrompt` 文本包含 `techStack`、`sdks`、`difficulties`（确认 prompt 会请求这些字段）。
  - 若走 `FakeRunner`：断言其默认输出 JSON 解析出的 `AgentSpec` 的 `techStack/sdks/difficulties` 非空。
- [x] **Step 2:** 在 `_probeCommon` 的字段说明里加：`techStack(字符串数组：技术栈/框架)、sdks(字符串数组：用到的 SDK/三方库)、difficulties(字符串数组：重难点)`。保持"只输出一个 JSON 对象、不要输出 JSON 以外内容"。
- [x] **Step 3:** 更新 `FakeRunner` 的默认探查输出，补上这三个字段的样例值（供 `generation_pipeline_test` 覆盖）。
- [x] **Step 4:** `dart test` 全绿。Commit。

**Acceptance:**
- 探查 prompt 明确请求 `techStack/sdks/difficulties`。
- 走 FakeRunner 的管线测试里，生成的 `AgentSpec` 这三个字段有值（证明"探查→解析"链路通）。
- 注：真实 LLM 行为不做单测；本任务只验证"prompt 请求 + 解析回填"链路。

---

### Task 3: probe() 注入模板人设 + AgentSpec.copyWith

**Files:**
- Modify: `crew_core/lib/src/models/agent_spec.dart`（加 `copyWith`）
- Modify: `crew_core/lib/src/runner/probe_parser.dart`（可选：`parseProbe` 支持注入人设）
- Modify: `crew_core/lib/src/engine/generation_pipeline.dart`（`probe()` 注入）
- Modify: `crew_core/test/models/agent_spec_test.dart`
- Modify: `crew_core/test/engine/generation_pipeline_test.dart`

**Interfaces:**
- Produces: `AgentSpec copyWith({...})`（至少覆盖 `personality`/`principles`，建议全字段，P2 合并也会用）；`probe()` 产出的 `AgentSpec` 带上模板预设的 `personality`/`principles`（覆盖 probe JSON 同名字段）。

**实现方式（二选一，推荐 A）：**
- **A（推荐）**：给 `AgentSpec` 加 `copyWith`；`probe()` 里 `parseProbe(...)` 后 `spec.copyWith(personality: template.personality, principles: template.principles)`（仅当模板值非空时覆盖）。`copyWith` 将来 P2 专家池 merge 也用得上。
- **B**：给 `parseProbe` 加可选命名参数 `String? personality, List<String>? principles`，`probe()` 传入模板值；非空则覆盖 JSON 解析值。

- [x] **Step 1: 先写测试（红）**
  - `agent_spec_test.dart`：`copyWith` 只改传入字段、其余不变；不传参返回等价副本。
  - `generation_pipeline_test.dart`：用一个带非空 `personality/principles` 的模板 + FakeRunner（返回含 `techStack/sdks/difficulties` 的探查 JSON）跑 `generate()`，断言结果 spec **同时**含：模板人设（personality/principles）+ 探查能力（techStack/sdks/difficulties）。
- [x] **Step 2:** 实现 `copyWith`（全字段，均可选）。
- [x] **Step 3:** 在 `probe()`（`generation_pipeline.dart:64` 附近）注入模板人设，模板值非空才覆盖。
- [x] **Step 4:** `dart test` 全绿。Commit。

**Acceptance:**
- `copyWith` 语义正确（改指定字段、其余不变）。
- `generate()` 出的每个 `AgentSpec` 同时带模板人设 + 探查能力。
- 模板人设为空时不覆盖 probe 值（不回归旧行为）。
- 渲染验证：该 spec 经 `renderAgentBody` 后正文含"## 人格 / ## 判断标准 / ## 技术栈 / ## SDK / ## 重难点"（可在管线测试后追加一条断言，或复用 agent_body 测试）。

---

### Task 4（可选，低优先）: source / github 静态探测

**Files:**
- Modify: `crew_core/lib/src/analysis/repo_analyzer.dart`
- Modify: `crew_core/test/analysis/repo_analyzer_test.dart`
- Modify: `crew_core/lib/src/engine/generation_pipeline.dart`（把探测到的 github 注入 spec）

**Interfaces:**
- Produces: `RepoAnalyzer` 读取 repo 的 `.git/config` 得到 remote URL → 填 `AgentSpec.github`；`source` 保持默认 `private`（是否开源由用户/GUI 决定，不靠启发式猜）。

- [x] **Step 1:** 测试：给一个含 `.git/config`（带 `[remote "origin"] url = ...`）的临时目录，断言解析出 URL。
- [x] **Step 2:** 实现读取（读文件即可，**不**起子进程 `git`，保持纯 Dart + 可测）。
- [x] **Step 3:** `probe()` 把 URL 经 `copyWith(github: url)` 注入。`dart test` 全绿。Commit。

**Acceptance:** 有 git remote 时 `github` 被填；无则留空、`source` 默认 `private`。

> 时间紧可跳过 Task 4——Task 1-3 已让"人格 + 能力"两维度全部接通。

---

## 明确不做（边界）

- ❌ 不实现专家池 / 提炼 / `distill`（P2/P3，见 `specs/2026-07-16-crew-expert-pool-design.md`）。
- ❌ 不改 `Runner` 接口、不改 `crew.yaml`/`CrewConfig`。
- ❌ 本计划不改 `crew_gui`（见下方跟进）。
- ❌ Task 4 不起 `git` 子进程（只读 `.git/config`）。

---

## crew_gui 跟进（本计划之外，单独排期）

`AgentTemplate` 新增 `personality/principles` 后，`crew_gui` 的**自定义专家编辑**（`experts_page.dart` / `template_repository.dart`）需要：
- 编辑表单支持填人格/判断标准；
- 自定义模板持久化（template_repository）需序列化这两个字段，避免存回本地库时丢失。

此项不在本 crew_core 计划内，验收时单独确认。

---

## 验收（由 Claude 负责，实现完成后执行）

实现方（glm-5.2）完成、用户通知后，Claude 按下列清单验收：

1. **测试全绿**：`cd crew_core && dart test` 全通过、无跳过。
2. **Task 1**：`AgentTemplate` 有 `personality/principles`；6 个内置模板全部非空。
3. **Task 2**：`_probeCommon` 请求 `techStack/sdks/difficulties`；FakeRunner 管线产出的 spec 这三字段有值。
4. **Task 3**：`copyWith` 语义正确；`generate()` 出的 spec **同时**含模板人设 + 探查能力；模板人设为空不覆盖；`renderAgentBody` 正文出现对应 section。
5. **同源一致**：Claude/Codex 正文仍一致（共用 `renderAgentBody`）。
6. **约束合规**：无新依赖、无 `package:flutter`、无库内 `DateTime.now()`、barrel 导出完整、向后兼容（旧 `parseProbe` 调用不回归）。
7. **边界合规**：未碰 Runner 接口 / `CrewConfig` / `crew_gui`；Task 4（若做）只读 `.git/config` 不起子进程。

验收通过后，Claude 更新本文件把任务 `- [ ]` 勾为 `- [x]` 并记录验收结论。

---

## 验收结论（Claude，2026-07-16）

**通过 ✅** —— 提交 `140061b`。`cd crew_core && dart test` = **64 passed, 0 skipped**。四个任务（含可选 Task 4）全部完成。

| 验收项 | 结论 |
|--------|------|
| 1. 测试全绿 | ✅ 64 通过，无跳过 |
| 2. Task 1 模板人设 | ✅ `AgentTemplate` 有 `personality/principles`（默认值兼容）；`builtin_templates_test` 断言 6 个内置模板人设/判断标准全非空 |
| 3. Task 2 探查字段 | ✅ `_probeCommon` 请求 `techStack/sdks/difficulties`；测试断言每个 probePrompt 含三字段；FakeRunner 输出已补字段 |
| 4. Task 3 注入 + copyWith | ✅ `copyWith` 全字段；`probe()` 经 `copyWith` 注入模板人设（`isNotEmpty ? … : null` 保证空模板不覆盖 probe 值）；pipeline 测试断言 spec 同时含人设 + 能力，且 `renderAgentBody` 正文出现 `## 人格 / 判断标准 / 技术栈 / SDK / 重难点`；另一例证明空模板保留 probe 值 |
| 5. 同源一致 | ✅ 共用 `renderAgentBody`，未改动 |
| 6. 约束合规 | ✅ 无新依赖、无 `package:flutter`、无库内 `DateTime.now()`；`copyWith` 随 `AgentSpec` 导出；`parseProbe` 旧调用不回归 |
| 7. 边界合规 | ✅ 提交仅动 `crew_core`；未碰 `Runner` 接口 / `CrewConfig` / `crew_gui`；Task 4 只读 `.git/config`（`repo_analyzer.dart:51 gitRemoteUrl`）不起子进程，三种情况（有 origin / 无 config / 无 origin）均有测试 |

**非阻塞的可选优化（留给后续）：**
- `repo_analyzer.dart:52` `File('${p.join(...)}')` 的字符串插值包裹多余（`p.join` 已返回 String），可直接 `File(p.join(...))`。纯风格，无功能影响。

**待办跟进（本计划之外，已在文档"crew_gui 跟进"标注）：**
- `crew_gui` 自定义专家编辑需支持填 `personality/principles` 且 `template_repository` 持久化这两字段——否则自定义专家人设会丢。下次做 GUI 时确认。
