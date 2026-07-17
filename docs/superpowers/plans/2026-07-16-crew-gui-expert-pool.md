# Crew GUI 接线：提炼入池 / 调用专家 Implementation Plan

> **For agentic workers:** TDD 逐任务。**全部在 `crew_gui`**。前置依赖：`plans/2026-07-16-crew-cli-publish-use.md` 的 **Part A**（`WorkspaceReader`、生成落 `.crew/specs/*.json`、真实 `CliRunner.distill`）必须先完成——GUI 发布/调用复用这些 crew_core 能力。

**Goal:** 在桌面 GUI 里把专家池用起来：
- **提炼入池**：对一个已生成的 workspace，一键把某 agent 提炼发布成专家（可并入领域专家）。
- **调用专家**：浏览专家池，把领域专家实例化进一个目标目录。

**依赖检查（实现前确认已具备）:** `WorkspaceReader`、`publishProject`、`mergeIntoDomain`、`instantiate`、`ExpertPool`、`CliRunner.distill`（均来自 crew_core，前置计划完成后可用）。

**现状锚点:**
- `crew_gui/lib/app_scaffold.dart` — 三 Tab（新建/专家/项目）侧边栏；`CliRunner` 已在此直接用于 AI refine（可参照其构造方式）。
- `crew_gui/lib/ui/home_page.dart` — 项目列表（`ProjectStore` + `ProjectEntry.path`）。
- `crew_gui/lib/services/pipeline_factory.dart` — runner 构造范式。
- `crew_gui/lib/models/project_entry.dart` — 项目条目（含 path）。

## Global Constraints

- 仅动 `crew_gui`（crew_core 能力由前置计划提供）。
- **池路径解析在 GUI 层**（`~/.crew/experts`，从 HOME），不进 crew_core。
- 所有涉及 IO/CLI 的逻辑走**可注入的 service**，widget 测试用 fake，不碰真实文件系统/CLI。
- 版本号/时间戳由 GUI 层传入（GUI 可用 `DateTime.now()`）。
- 保持现有 Material 风格（`_SidebarItem`、`_SectionTitle`、Card/ListTile）。

---

### Task 1: ExpertPoolService

**Files:**
- Create: `crew_gui/lib/services/expert_pool_service.dart`
- Create: `crew_gui/test/services/expert_pool_service_test.dart`

**Interfaces:**
```dart
class ExpertPoolService {
  final ExpertPool pool;               // 注入（测试用临时目录）
  final Runner Function() runnerFactory; // 造 CliRunner 供 distill（可注入 Fake）
  ExpertPoolService(this.pool, {required this.runnerFactory});

  /// 默认池目录：~/.crew/experts（HOME 解析在此，非 crew_core）
  static ExpertPoolService defaultForTool(String cliTool);

  Future<List<ExpertSummary>> list();

  /// 提炼一个 workspace 里的 agent 入池
  Future<PublishOutcome> publish({
    required String workspacePath,
    required String agentName,
    required String retention,   // full|experience-only|none
    required String source,      // opensource|private
    String? domain,              // 非空则并入领域专家
    required int version,
  });

  /// 把领域专家实例化到目标目录
  Future<List<String>> useExpert({  // 返回写入路径清单
    required String domain,
    required String intoPath,
    required String agentName,
    required List<String> repos,
  });
}
```
- `publish` 内部：`WorkspaceReader(workspacePath).readAgent(agentName)` → `RepoAnalyzer().gitRemoteUrl` → `publishProject` → `pool.saveProject` →（domain 非空）`mergeIntoDomain(..., runner: runnerFactory())` → `pool.saveDomain`。
- `useExpert` 内部：`pool.loadDomain` → `instantiate` → `WritePlanner` 写 seed 到 `intoPath`。

- [x] **Step 1: 测试**（临时 pool + FakeRunner + 造一个含 `.crew/specs`+memory 的临时 workspace）：
  - `publish(experience-only, domain:'quant')` → `list()` 出现 project + domain 专家；domain.learnedProjectIds 含该项目。
  - `useExpert('quant', into=tmp, ...)` → 目标目录出现 `memory/<name>/domain-notes.md`、`playbooks/`、**无 solved/**。
- [x] **Step 2:** 实现（`defaultForTool` 解析 HOME；纯逻辑可注入）。
- [x] **Step 3:** `flutter test test/services/expert_pool_service_test.dart` + 全量绿。Commit。

**Acceptance:** service 编排正确、依赖可注入；调用产物无 L1。

---

### Task 2: 提炼入池 UI（项目列表触发）

**Files:**
- Modify: `crew_gui/lib/ui/home_page.dart`（项目条目加"提炼专家"动作）
- Modify: `crew_gui/lib/app_scaffold.dart`（注入 `ExpertPoolService`）
- Create/Modify: `crew_gui/test/ui/home_page_publish_test.dart`

**交互:**
- 项目列表每个条目 trailing 加一个"提炼专家"按钮 → 打开对话框：
  - 选 agent（从该 workspace 的 crew.yaml / `.crew/specs` 列出）
  - retention 单选（full / experience-only / none）
  - source 单选（opensource / private）
  - 可选 domain 文本框（填了就并入领域专家）
  - 确认 → 调 `ExpertPoolService.publish(...)`，成功 toast，失败提示。

- [x] **Step 1: 测试**（widget，注入 fake `ExpertPoolService`）：点"提炼专家" → 选 agent + experience-only + domain=quant + 确认 → 断言 service.publish 被以正确参数调用，UI 显示成功。
- [x] **Step 2:** 实现对话框 + 接线。
- [x] **Step 3:** `flutter test` 全绿。Commit。

**Acceptance:** 能从项目列表提炼入池；参数正确传递；成功/失败反馈。

---

### Task 3: 专家池浏览 + 调用到目录

**Files:**
- Create: `crew_gui/lib/ui/expert_pool_page.dart`
- Modify: `crew_gui/lib/app_scaffold.dart`（加"专家池" Tab）
- Create: `crew_gui/test/ui/expert_pool_page_test.dart`

**交互:**
- 侧边栏新增"专家池" Tab（`_NavTab.pool`，`Icons.workspace_premium` 之类）。
- 页面列出 `ExpertPoolService.list()`：project / domain 分组，显示 id/domain、learnedCount、version。
- 领域专家条目有"应用到目录"动作 → 选目标目录（`DirectoryPicker`）+ 填 agentName/repos → 调 `useExpert(...)`，成功后可"用 CLI 打开"（复用 `WorkspaceOpener`）。

- [x] **Step 1: 测试**（widget，注入 fake service + fake picker）：list 显示预置的 domain 专家；点"应用到目录"→ 选目录 → 确认 → 断言 `useExpert` 被以正确参数调用。
- [x] **Step 2:** 实现页面 + Tab + 接线。
- [x] **Step 3:** `flutter test` 全绿。Commit。

**Acceptance:** 专家池可浏览；领域专家可实例化到指定目录。

---

## 明确不做（边界）

- ❌ 不改 crew_core（能力由前置 CLI 计划的 Part A 提供）。
- ❌ 不把"调用专家"深度嵌进创建向导（本计划先做独立"专家池"页；向导内选专家作为后续增强）。
- ❌ 不做池的删除/编辑/版本回滚（先只 浏览/提炼/调用）。

## 验收（由 Claude 负责）

1. `cd crew_gui && flutter test` 全绿、无跳过（前置 crew_core 计划亦须先绿）。
2. **Task 1**：`ExpertPoolService` 编排正确、可注入；publish→list 可见、useExpert 产物无 L1。
3. **Task 2**：项目列表提炼对话框参数正确传给 service；反馈正确。
4. **Task 3**：专家池 Tab 列表正确；应用到目录调用 `useExpert` 参数正确。
5. **边界合规**：仅动 `crew_gui`；池路径在 GUI 层解析；widget 测试不碰真实 FS/CLI。

验收通过后，Claude 勾选任务并记录结论。

---

## 验收结论（Claude，2026-07-17）

**通过 ✅** —— 提交 `bc53743`。`cd crew_gui && flutter test` = **56 passed**。

| 任务 | 结论 |
|------|------|
| **Task 1 ExpertPoolService** | ✅ `expert_pool_service_test`：`publish(experience-only, domain)` → list 出现 project+domain；`useExpert` 写记忆文件**无 solved/**；缺失 domain 返回错误 |
| **Task 2 提炼入池 UI** | ✅ `publish_dialog_test`：retention 默认 experience-only 可切 full；对话框参数传给 service |
| **Task 3 专家池页** | ✅ `expert_pool_page_test`：列表显示预置 project+domain；`app_scaffold` 加第 4 个 Tab |
| 边界合规 | ✅ 仅动 `crew_gui`；池路径 GUI 层解析；widget 测试用 fake service |

**非阻塞观察：** `publish_dialog_test` 运行时有一条非致命 `hitTestWarning`（点击目标可能部分离屏），测试通过但建议后续在该 widget 测试里用 `ensureVisible`/滚动消除警告。不影响验收。
