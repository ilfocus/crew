# Crew GUI 专家人格编辑接线 Implementation Plan

> **For agentic workers:** 用 TDD 逐任务实现。每个任务：先写/改测试 → 实现到测试通过 → commit。步骤用 `- [ ]` 复选框跟踪。**本计划全部在 `crew_gui`**。前置：`crew_core` 的 `AgentTemplate` 已有 `personality/principles`（提交 `140061b`）。

**Goal:** 让 GUI 的专家编辑支持填写并持久化 `personality`（人格）与 `principles`（判断标准）。当前断点：`AgentTemplate` 已有这两字段，但 GUI 的序列化、克隆、编辑表单都**没带**它们 → 自定义专家的人设一保存就丢，克隆内置模板也丢人设。

**根因（实现前先确认）:**
- `crew_gui/lib/services/template_repository.dart:6` `agentTemplateToJson` / `:16` `agentTemplateFromJson` 未含 `personality/principles`。
- 同文件 `:77` `cloneBuiltin` 未拷贝 `personality/principles`。
- `crew_gui/lib/ui/experts_page.dart:175` `_buildFromForm` 未构造 `personality/principles`；`ExpertEditPage` 无对应输入框。

**Tech Stack:** Flutter/Dart；测试 `flutter test`。

## Global Constraints

- **向后兼容**：`agentTemplateFromJson` 读旧 JSON（无这两字段）时取默认（`''` / `const []`），不得抛异常——已存的自定义模板文件不能读崩。
- 不改 `crew_core`（`AgentTemplate` 已就绪）。
- 保持现有编辑页交互风格（`_SectionTitle` 分区、`TextField` + `OutlineInputBorder`）。

## 现状锚点（实现前先读）

- `crew_gui/lib/services/template_repository.dart` — 序列化 + `cloneBuiltin`。
- `crew_gui/lib/ui/experts_page.dart` — `ExpertEditPage` 表单 + `_buildFromForm`。
- `crew_gui/test/services/template_repository_test.dart` — 序列化测试。
- `crew_gui/test/ui/experts_page_test.dart` — 编辑页 widget 测试。

---

### Task 1: template_repository 序列化 + 克隆带上人设

**Files:**
- Modify: `crew_gui/lib/services/template_repository.dart`
- Modify: `crew_gui/test/services/template_repository_test.dart`

**Interfaces:**
- Produces: `agentTemplateToJson`/`agentTemplateFromJson` 往返包含 `personality`(String)/`principles`(List<String>)；`cloneBuiltin` 拷贝这两字段。

- [ ] **Step 1: 先写测试（红）**
  - 往返：构造带 `personality`/`principles` 的 `AgentTemplate` → `agentTemplateToJson` → `agentTemplateFromJson`，断言两字段无损。
  - 兼容：`agentTemplateFromJson({...无 personality/principles...})` 不抛异常，取默认（`''`/空）。
  - 克隆：`cloneBuiltin(内置模板)` 保留 `personality`/`principles`。
- [ ] **Step 2:** `agentTemplateToJson` 加 `'personality': t.personality, 'principles': t.principles`。
- [ ] **Step 3:** `agentTemplateFromJson` 加解析：`personality: (j['personality'] as String?) ?? ''`、`principles: (j['principles'] as List?)?.map((e)=>e.toString()).toList() ?? const []`。
- [ ] **Step 4:** `cloneBuiltin` 补 `personality: t.personality, principles: List.from(t.principles)`。
- [ ] **Step 5:** `cd crew_gui && flutter test test/services/template_repository_test.dart` 通过；全量 `flutter test` 全绿。Commit。

**Acceptance:**
- 序列化往返含人设；旧 JSON 无字段可读（默认值）；`cloneBuiltin` 不丢人设。

---

### Task 2: 编辑页人格 / 判断标准输入

**Files:**
- Modify: `crew_gui/lib/ui/experts_page.dart`
- Modify: `crew_gui/test/ui/experts_page_test.dart`

**Interfaces:**
- Produces: `ExpertEditPage` 新增"人格"单行输入与"判断标准"输入（逗号或换行分隔的列表）；`_buildFromForm` 把两者写入 `AgentTemplate`；保存后经 `updateCustom` 持久化。

- [ ] **Step 1: 先写测试（红）**（widget test）
  - 打开 `ExpertEditPage`（新建自定义），在人格框输入文本、判断标准框输入 `a, b`，点保存 → 断言 `repository` 里对应模板的 `personality` == 输入、`principles` == `['a','b']`。
  - 打开一个带人设的模板 → 断言两个输入框回显初始值。
- [ ] **Step 2:** `_ExpertEditPageState` 加 `_personalityCtrl`、`_principlesCtrl`，`initState` 用 `t.personality` / `t.principles.join(', ')` 初始化，`dispose` 释放。
- [ ] **Step 3:** 在 build 里"基本信息"之后加一个 `_SectionTitle('人格与判断标准')` 分区：
  - 人格：单行 `TextField`（`_personalityCtrl`，hint 如 `严谨、重性能`）。
  - 判断标准：多行 `TextField`（`_principlesCtrl`，hint `逗号或换行分隔，如：主线程不做 IO, 依赖锁版本`）。
- [ ] **Step 4:** `_buildFromForm` 加：
  - `personality: _personalityCtrl.text.trim()`
  - `principles: _principlesCtrl.text.split(RegExp(r'[,\n]')).map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList()`
- [ ] **Step 5:** `flutter test test/ui/experts_page_test.dart` 通过；全量 `flutter test` 全绿。Commit。

**Acceptance:**
- 编辑页可填/回显人格与判断标准；保存后持久化正确（往返到 `TemplateRepository`）。
- 现有编辑页测试不回归。

---

## 明确不做（边界）

- ❌ 不改 `crew_core`。
- ❌ 不动探查/生成管线（人设注入已在 `140061b` 做好）。
- ❌ 不做专家池/提炼（见 `plans/2026-07-16-crew-expert-pool-p2.md`）。

## 验收（由 Claude 负责）

1. `cd crew_gui && flutter test` 全绿、无跳过。
2. Task 1：`template_repository_test` 覆盖人设往返 + 旧 JSON 兼容 + `cloneBuiltin` 保留。
3. Task 2：`experts_page_test` 覆盖填写→保存→持久化 + 回显。
4. 边界合规：仅动 `crew_gui`；旧自定义模板文件仍可读。

验收通过后，Claude 勾选任务并记录结论。
