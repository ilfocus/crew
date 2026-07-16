# Crew 专家池与提炼 (P2) Implementation Plan

> **For agentic workers:** 用 TDD 逐任务实现，分 4 阶段（B1→B4），每阶段一组任务。每个任务：先写测试 → 实现到通过 → commit。步骤用 `- [ ]` 跟踪。**本计划全部在 `crew_core`**（纯 Dart，可用 FakeRunner + 临时目录完整单测）。CLI/GUI 接线是后续，不在本计划。

**Goal:** 实现设计规格 `specs/2026-07-16-crew-expert-pool-design.md` 的引擎层——**全局专家池 + 提炼/发布/调用**：把在 workspace 里学成的 agent（记忆已由前序任务分层沉淀）提炼成持久、可复用、会成长的 **Expert**，支持跨项目聚合为**领域专家**，并能反过来实例化进新 workspace。

**先读规格**：本计划的模型/管线/隐私/布局全部以该 spec 为准，尤其 §2（三类实体）、§3（L1/L2 分层）、§4（隐私）、§5（池布局）、§6（三条管线）、§7（distill）、§8（数据模型）、§10（project-id）。

**已就绪的基础（前序提交）:**
- `AgentSpec` 全字段 + `toJson/fromJson` + `copyWith`（`140061b`）——直接复用为 Expert 的 spec 部分。
- 记忆分层结构（`solved/`、`playbooks/`、召回索引）——Expert 记忆沿用同结构。
- `RepoAnalyzer.gitRemoteUrl(repoPath)`——project-id 归一化的输入源。
- `Runner` 抽象 + `FakeRunner` + JSON 抽取（`probe_parser.dart` 的 `_extractFirstJsonObject` 可复用思路）。

**Architecture:** 池以**中性 JSON**（`expert.json`）为单一事实源，另渲染人类可读视图（`IDENTITY.md`/`COMPETENCE.md`/`memory/**`）。提炼 = LLM `distill`（复用 Runner）把 L1 抽象成 L2。所有管线纯函数式、副作用集中在 `ExpertPool`（文件读写）与 `Runner`（LLM）。

## Global Constraints

- 纯 Dart，不依赖 `package:flutter`；依赖仅 `yaml`/`path`；测试 `package:test`。
- **池根路径可注入**：`ExpertPool(rootDir)`，测试用临时目录；默认 `~/.crew/experts` 由调用方（CLI/GUI）传入，**库内不硬编码 HOME、不调 `DateTime.now()`**（版本号/时间戳由调用方传入）。
- **记忆保护**：合并/发布绝不静默丢弃已有专家记忆；冲突走去重/修正，不覆盖。
- **隐私**（spec §4）：`retention` 决定保留范围；`private` + `experience-only` 时**不得**把 L1 具体代码/路径写进领域专家。
- 新增对外类型从 `crew_core/lib/crew_core.dart` barrel 导出。
- 每源文件单一职责，小而聚焦。

## File Structure（本计划新增）

```
crew_core/lib/src/
├── models/
│   ├── expert.dart              # Expert + ExpertKind + ExpertMemory + MemoryEntry + ProjectRef + ExpertMeta
│   └── expert_summary.dart      # 池索引条目
├── expert/
│   ├── project_id.dart          # deriveProjectId(gitRemoteUrl?, path)
│   ├── expert_pool.dart         # 文件系统池：save/load/list（副作用集中处）
│   ├── expert_pool_adapter.dart # expert.json ↔ IDENTITY/COMPETENCE/memory 渲染
│   ├── publisher.dart           # publishProject（含隐私闸门）
│   ├── merger.dart              # mergeIntoDomain（去重 + distill + projects 索引）
│   └── instantiator.dart        # DomainExpert → workspace seed（AgentSpec + 记忆产物）
└── runner/
    ├── runner.dart              # [改] 增 distill 任务
    ├── fake_runner.dart         # [改] distill 返回 canned L2
    └── distill_parser.dart      # 解析 distill 输出 → { domainNotes, playbooks[] }
crew_core/test/ …                # 与 src 镜像
```

---

## 阶段 B1：模型 + 序列化 + project-id

### Task B1.1: Expert 数据模型 + expert.json 往返

**Files:**
- Create: `crew_core/lib/src/models/expert.dart`
- Modify: `crew_core/lib/crew_core.dart`（导出）
- Create: `crew_core/test/models/expert_test.dart`

**Interfaces（对齐 spec §8.1）:**
```dart
enum ExpertKind { project, domain }

class MemoryEntry { final String path; final String content; }      // solved/playbooks 单条
class ProjectRef  { final String id;   final String summary; }      // domain 学过的项目索引

class ExpertMemory {
  final String index;            // MEMORY.md
  final String notes;            // project-notes(L1) 或 domain-notes(L2)
  final List<MemoryEntry> solved;
  final List<MemoryEntry> playbooks;
  final List<ProjectRef> projects; // 仅 domain 非空
}

class ExpertMeta {
  final String source;      // opensource | private
  final String github;      // opensource 时
  final String retention;   // full | experience-only | none
  final String projectId;   // project 专家；domain 可空串
  final int version;
  final List<String> learnedProjectIds; // domain
}

class Expert {
  final ExpertKind kind;
  final String domain;      // domain 专家的领域名；project 可空串
  final AgentSpec spec;     // 复用现有 AgentSpec（含 personality/principles/techStack/...）
  final ExpertMemory memory;
  final ExpertMeta meta;
  Map<String,dynamic> toJson();
  factory Expert.fromJson(Map<String,dynamic>);
}
```

- [ ] **Step 1:** 测试：构造填满的 project Expert 与 domain Expert（含 projects/learnedProjectIds）→ `toJson`→`fromJson` 全字段无损（spec 内部复用其 `toJson/fromJson`）。缺省字段容错。
- [ ] **Step 2:** 实现全部模型 + 序列化。`kind` 用字符串 `"project"|"domain"` 存取。
- [ ] **Step 3:** barrel 导出。`dart test test/models/expert_test.dart` + 全量绿。Commit。

**Acceptance:** 两种 Expert 往返无损；缺省容错；`spec` 段复用 `AgentSpec` 序列化。

### Task B1.2: project-id 归一化

**Files:**
- Create: `crew_core/lib/src/expert/project_id.dart`
- Modify: barrel
- Create: `crew_core/test/expert/project_id_test.dart`

**Interfaces（spec §10）:**
```dart
/// 首选归一化 git remote URL；无则用绝对路径 FNV hash。
String deriveProjectId({String? gitRemoteUrl, required String path});
```
- [ ] **Step 1:** 测试：
  - `git@github.com:Foo/Bar.git`、`https://github.com/foo/bar` → 归一化到同一 id（去协议/去 `.git`/小写/去 `git@`→host 形式，统一成 `github.com/foo/bar`）。
  - 无 URL → 路径 hash 稳定（同路径同 id，不同路径不同）。
- [ ] **Step 2:** 实现（hash 复用 `write_planner.dart` 的 FNV-1a 思路，避免新依赖）。
- [ ] **Step 3:** 全量绿。Commit。

**Acceptance:** ssh/https 同仓归一为同 id；无 remote 走稳定路径 hash。

---

## 阶段 B2：文件系统池 + 渲染适配器

### Task B2.1: ExpertPoolAdapter（expert.json ↔ 可读视图）

**Files:**
- Create: `crew_core/lib/src/expert/expert_pool_adapter.dart`
- Modify: barrel
- Create: `crew_core/test/expert/expert_pool_adapter_test.dart`

**Interfaces:** 给定一个 `Expert`，产出 `List<FileArtifact>`（相对专家目录）：
- `expert.json`（中性事实源，`isMemory:false`）
- `IDENTITY.md`（人格 + 判断标准 + 角色；复用 `renderAgentBody` 的人格/判断标准片段思路或独立小渲染）
- `COMPETENCE.md`（project：坐标/模块/关键文件/techStack/sdks/difficulties/github；domain：领域说明）
- `memory/MEMORY.md`、`memory/{project-notes|domain-notes}.md`、`memory/solved/*`、`memory/playbooks/*`、（domain）`memory/projects/*`，**记忆类 `isMemory:true`**

- [ ] **Step 1:** 测试：project Expert 渲染出上述文件；`expert.json` 能被 `Expert.fromJson(jsonDecode(...))` 还原为等价对象（往返一致）；记忆文件 `isMemory:true`。domain Expert 渲染出 `domain-notes.md` 与 `projects/`。
- [ ] **Step 2:** 实现渲染。
- [ ] **Step 3:** 全量绿。Commit。

**Acceptance:** 渲染 + `expert.json` 回读一致；project/domain 各自文件齐全；记忆受保护标记正确。

### Task B2.2: ExpertPool 文件系统读写 + 索引

**Files:**
- Create: `crew_core/lib/src/expert/expert_pool.dart`
- Create: `crew_core/lib/src/models/expert_summary.dart`
- Modify: barrel
- Create: `crew_core/test/expert/expert_pool_test.dart`

**Interfaces（spec §5 布局）:**
```dart
class ExpertPool {
  final Directory root;                       // 可注入（测试用临时目录）
  ExpertPool(this.root);
  Future<void> saveProject(Expert e);         // projects/<meta.projectId>/…
  Future<void> saveDomain(Expert e);          // domains/<domain>/…
  Future<Expert?> loadProject(String projectId);
  Future<Expert?> loadDomain(String domain);
  Future<List<ExpertSummary>> list();         // 读 pool.yaml 或扫描目录
}
```
- **记忆保护**：`saveXxx` 复用 `WritePlanner`（`isMemory` 已存在则 skip），避免覆盖专家运行期新增记忆。
- `pool.yaml` 维护 `{kind, id/domain, learnedCount, version}` 索引。

- [ ] **Step 1:** 测试（临时目录）：`saveProject`→`loadProject` 往返等价；`saveDomain`→`loadDomain` 往返；`list()` 返回已存专家摘要；重复 save 不覆盖已存记忆文件（造一个已存 `solved/x.md`，save 后内容不变）。
- [ ] **Step 2:** 实现（渲染走 B2.1 adapter；落盘走 `WritePlanner.plan/apply`；`expert.json` 读回构建 Expert）。
- [ ] **Step 3:** 全量绿。Commit。

**Acceptance:** 存取往返一致；`list()` 正确；记忆不被覆盖；布局对齐 spec §5。

---

## 阶段 B3：distill + 发布 + 合并

### Task B3.1: Runner.distill + FakeRunner + 解析

**Files:**
- Modify: `crew_core/lib/src/runner/runner.dart`
- Modify: `crew_core/lib/src/runner/fake_runner.dart`
- Create: `crew_core/lib/src/runner/distill_parser.dart`
- Modify: barrel
- Create/Modify: `crew_core/test/runner/distill_parser_test.dart`、`fake_runner_test.dart`

**Interfaces（spec §7）:**
```dart
// Runner 增：
Future<RunnerResult> distill({required String prompt});  // 输入含 L1 语料的 prompt，返回 JSON 文本

// 解析：
class DistillResult { final String domainNotes; final List<MemoryEntry> playbooks; }
DistillResult parseDistill(String rawOutput);  // 抽第一个 JSON：{domainNotes, playbooks:[{path,content}]}
```
- `FakeRunner.distill` 返回固定 L2 JSON（供 B3.3 测试）。
- **CliRunner.distill 可先抛 `UnimplementedError` 或走 headless prompt**——真实 CLI 接线不在本计划验收范围（标注 TODO）；本计划只保证接口 + Fake + 解析可测。

- [ ] **Step 1:** 测试：`parseDistill` 抽取/解析正确；容错（无 JSON 抛 FormatException，与 `parseProbe` 一致）。`FakeRunner.distill` 返回可解析 JSON。
- [ ] **Step 2:** 实现。
- [ ] **Step 3:** 全量绿。Commit。

**Acceptance:** `Runner` 接口含 distill；Fake 可用；解析健壮。

### Task B3.2: Publisher（agent → ProjectExpert，含隐私闸门）

**Files:**
- Create: `crew_core/lib/src/expert/publisher.dart`
- Modify: barrel
- Create: `crew_core/test/expert/publisher_test.dart`

**Interfaces（spec §6②、§4）:**
```dart
/// 把一个 workspace agent 的 spec + 记忆提炼为 ProjectExpert。
/// retention 控制保留范围（spec §4）：
///  - full           : 完整 L1（坐标/关键文件/solved 原文）
///  - experience-only: 去具体（清空 keyFiles/coordinates 具体路径、solved 只留抽象），仅保留可迁移信息
///  - none           : 返回 null（不发布）
Expert? publishProject({
  required AgentSpec spec,
  required ExpertMemory workspaceMemory,
  required String retention,
  required String source,       // opensource|private
  String gitRemoteUrl,          // 传入用于 projectId + github
  required String workspacePath,
  required int version,         // 调用方传入，避免库内时钟
});
```
- [ ] **Step 1:** 测试：
  - `full` → Expert 保留完整 spec + 记忆；`projectId` 由 `deriveProjectId` 得出；`source=opensource` 时 `github` 落入 meta。
  - `experience-only` → keyFiles/coordinates 具体信息被清除（断言不含原始路径），仅保留 techStack/difficulties 等可迁移面。
  - `none` → 返回 null。
- [ ] **Step 2:** 实现（纯函数，无 IO）。
- [ ] **Step 3:** 全量绿。Commit。

**Acceptance:** 三档 retention 行为正确；`experience-only` 确实不含 L1 具体代码/路径（隐私）。

### Task B3.3: Merger（ProjectExpert → DomainExpert，去重 + distill + 索引）

**Files:**
- Create: `crew_core/lib/src/expert/merger.dart`
- Modify: barrel
- Create: `crew_core/test/expert/merger_test.dart`

**Interfaces（spec §6②、§3）:**
```dart
/// 把一个 ProjectExpert 并入 DomainExpert（不存在则以传入的空壳新建）。
///  - 运行 runner.distill 把该项目 L1 抽象成 L2（domainNotes/playbooks），并入 domain 记忆
///  - solved/playbooks 去重（按 path/关键词）
///  - projects[] 追加该项目摘要；learnedProjectIds 追加 projectId（已存则跳过，幂等）
Future<Expert> mergeIntoDomain({
  required Expert domain,          // 现有或空壳 domain expert
  required Expert project,         // 待并入的 project expert
  required Runner runner,
  required int version,            // 调用方传入
});
```
- [ ] **Step 1:** 测试（FakeRunner）：
  - 空壳 domain + 一个 project → 得到含 distill 出的 `domain-notes`/playbooks、`projects` 有 1 条、`learnedProjectIds` 含该 id。
  - 再并入**同一** projectId → 幂等（projects/learnedProjectIds 不重复增长）。
  - 并入**第二个**不同 project → projects 增到 2；playbooks 去重（相同 path 不重复）。
- [ ] **Step 2:** 实现（distill 调用 + 合并/去重逻辑）。
- [ ] **Step 3:** 全量绿。Commit。

**Acceptance:** 聚合正确、幂等、去重；L2 由 distill 产出并入 domain；符合"领域专家 = 多项目抽象聚合"。

---

## 阶段 B4：调用（DomainExpert → workspace seed）

### Task B4.1: Instantiator

**Files:**
- Create: `crew_core/lib/src/expert/instantiator.dart`
- Modify: barrel
- Create: `crew_core/test/expert/instantiator_test.dart`

**Interfaces（spec §6③）:**
```dart
/// 把领域专家实例化成新 workspace 里的一个 agent 种子。
/// 带上：L2 领域经验(domain-notes) + playbooks + projects 索引（作为"我做过这些项目"参考）
/// 不带：任何单个项目的 L1（避免误套 + 泄漏）
class InstantiatedAgent {
  final AgentSpec spec;                 // 领域专家人设 + 领域能力，repos 指向新项目
  final List<FileArtifact> memorySeed;  // memory/<name>/ 下的初始记忆（L2 + playbooks + projects 索引），isMemory:true
}
InstantiatedAgent instantiate({
  required Expert domain,
  required String agentName,
  required List<String> newRepos,
});
```
- [ ] **Step 1:** 测试：
  - 产出的 `spec` 含领域专家人设/判断标准；`repos == newRepos`。
  - `memorySeed` 含 domain-notes 与 playbooks；**不含**任何 project 的 L1 solved 原文/具体路径（断言）。
  - `projects` 索引以只读参考形式出现（如 `memory/<name>/projects.md`）。
  - 记忆产物 `isMemory:true`。
- [ ] **Step 2:** 实现（纯函数）。
- [ ] **Step 3:** 全量绿。Commit。

**Acceptance:** 实例化只带 L2/playbooks/项目索引、不带 L1；产物可直接进 workspace 且受记忆保护。

---

## 明确不做（边界）

- ❌ CLI（`crew publish` / `crew use-expert`）与 GUI 接线——本计划只做引擎，接口留给后续 CLI/GUI 计划调用。
- ❌ `CliRunner.distill` 真实 CLI 落地（B3.1 允许 TODO/占位；验收只覆盖接口 + Fake + 解析）。
- ❌ 云端同步 / 多人共享 / 专家评分（spec §14 YAGNI）。
- ❌ 自动判定项目所属领域（domain 由调用方指定）。

## 验收（由 Claude 负责，分阶段可分批验）

按 B1→B4 顺序，每阶段验收其任务的 Acceptance；全部完成后统一核对：

1. **测试全绿**：`cd crew_core && dart test` 全通过、无跳过。
2. **B1**：Expert/ProjectRef/... 往返无损；project-id ssh/https 归一 + 路径 hash 兜底。
3. **B2**：`ExpertPoolAdapter` 渲染 + `expert.json` 回读一致；`ExpertPool` 存取/`list` 正确、记忆不被覆盖、布局对齐 spec §5。
4. **B3**：`Runner.distill` + Fake + `parseDistill` 可用；Publisher 三档 retention 正确（`experience-only` 无 L1 具体信息）；Merger 聚合幂等去重、L2 由 distill 并入。
5. **B4**：Instantiator 只带 L2/playbooks/项目索引、不带 L1，产物 `isMemory:true`。
6. **约束合规**：无新依赖、无 `package:flutter`、无库内 `DateTime.now()`/硬编码 HOME（版本/时间/根路径均调用方传入）；barrel 导出完整。
7. **边界合规**：未做 CLI/GUI 接线；未违反 YAGNI 清单。

验收通过后，Claude 勾选任务并记录结论。
