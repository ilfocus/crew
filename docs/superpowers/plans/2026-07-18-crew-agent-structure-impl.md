# Crew — Agent 内容结构重构 实施计划（交付 GLM-5.2 实现）

> **For agentic workers (GLM-5.2):** 用 TDD 逐任务实现，分 7 阶段（A→G）。每个任务：**先写测试 → 实现到通过 → `cd crew_core && dart test` 全绿 → commit**。步骤用 `- [ ]` 跟踪。A–F 全在 `crew_core`（纯 Dart，临时目录 + FakeRunner 可完整单测）；G 才碰 `crew_cli` / `crew_gui`。

**先读设计**：本计划实现 `docs/superpowers/specs/2026-07-18-crew-agent-content-structure.md`。所有结构/归属/决策以该 spec 为准，尤其 §2.1（agent-id）、§2.2（project 多归属）、§3（目录）、§4.4（短期记忆淘汰）、§5（模型拆分）、§7（自动迁移）。也需读 `specs/2026-07-16-crew-expert-pool-design.md` §3（L1/L2）、§4（隐私）、§10（project-id）——这两条语义**不变**，本计划只改物理归属。

---

## 0. 核心思路与边界

### 0.1 关键区分：workspace 侧 vs 池侧

- **`AgentSpec`（`crew_core/lib/src/models/agent_spec.dart`）是 workspace 侧 probe 产物，保持不动。** workspace 生成器、`WorkspaceReader`、probe 管线继续用它。
- **池侧的 `Expert / ExpertMemory / ExpertMeta`（`models/expert.dart`）被本计划的新模型取代。** 池侧改为"以 agent 为主体、domain/project 为子层"。
- **`Publisher` 是两侧的桥**：把 workspace 的 `AgentSpec` + 记忆拆解映射到池侧的 `AgentCore` + `ProjectCompetence` + agent 记忆。

### 0.2 目标目录布局（spec §3）

```
<poolRoot>/
├── pool.yaml
└── agents/<agent-id>/
    ├── agent.json            # AgentCore + AgentMemory + AgentMeta（self 的单一事实源）
    ├── IDENTITY.md           # 视图：core.personality/role/principles
    ├── RELATIONSHIPS.md      # 视图：core.relationships
    ├── TOOLS.md              # 视图：core.tools
    ├── memory/
    │   ├── MEMORY.md         # memory.index
    │   ├── short-term.md     # memory.shortTerm
    │   └── long-term/<*>     # memory.longTerm 每条一文件
    ├── domains/<domain>/
    │   ├── domain.json       # DomainExpertise 的单一事实源
    │   ├── EXPERTISE.md      # 视图
    │   ├── playbooks/<*>     # L2
    │   └── projects.md       # 视图：projects 引用（多对多）
    └── projects/<project-id>/
        ├── project.json      # ProjectCompetence 的单一事实源
        ├── COMPETENCE.md     # 视图
        └── memory/
            ├── project-notes.md
            ├── solved/<*>
            └── playbooks/<*>
```

> 每层各存一份 `*.json`（单一事实源）+ 若干 `.md`/记忆文件（渲染视图），延续现有"中性 JSON + Adapter 渲染视图"的做法。`project-id` 内含 `/`（如 `github.com/foo/bar`）→ 映射为嵌套目录（沿用现有 `ExpertPool` 的递归扫描思路）。

### 0.3 全局约束（沿用现有 P2 计划）

- 纯 Dart，不依赖 `package:flutter`；依赖仅 `yaml`/`path`；测试 `package:test`。
- **库内不调 `DateTime.now()`、不硬编码 HOME**；version/根路径由调用方注入。
- **记忆保护**：save/merge 绝不静默覆盖已存记忆文件（复用 `WritePlanner` 的 `isMemory` skip）。
- **隐私**（专家池 spec §4）：`retention` 语义不变；`experience-only` 不得把 L1 具体代码/路径写进可迁移层。
- 新增对外类型从 `crew_core/lib/crew_core.dart` barrel 导出；每源文件单一职责。

### 0.4 明确不做

- ❌ 不动 `AgentSpec` 及 workspace 生成/probe 管线。
- ❌ 不做云端同步 / 多人共享 / 关系图谱可视化（spec §10 YAGNI）。
- ❌ `CliRunner.distill` 真实 CLI 落地仍是既有 TODO，本计划不覆盖（Fake + 解析可测即可）。

---

## Phase A：池侧新模型 + 序列化

> 复用现有 `MemoryEntry` / `ProjectRef` / `KeyFile`（`models/expert.dart`、`models/agent_spec.dart`），不重复定义。

### Task A1: AgentCore + AgentMemory + AgentMeta

**Files:** Create `crew_core/lib/src/models/agent_core.dart`、`models/agent_memory.dart`；Modify barrel；Create `crew_core/test/models/agent_core_test.dart`。

**Interfaces:**
```dart
class AgentCore {
  final String id;            // 稳定唯一 slug（个体代号，spec §2.1）
  final String name;          // 机器名（= workspace agent name）
  final String displayName;
  final String role;          // 角色，可重复；≠ id
  final String personality;   // 1 个性
  final List<String> principles;
  final String relationships;  // 2 关系：自由 markdown（用户画像 + 协作 agent）
  final List<String> tools;    // 5 工具：skill/mcp id 清单
  // toJson / fromJson（缺省容错，全字段默认空）
}

class AgentMemory {           // 3 记忆（agent 本体，跨项目）
  final String index;         // MEMORY.md
  final String shortTerm;     // short-term.md
  final List<MemoryEntry> longTerm; // long-term/<path>
}

class AgentMeta {
  final int version;
  // 预留：createdAtVersion 等；本期只 version
}
```
- [x] **Step 1:** 测试：填满字段 `toJson→fromJson` 无损；缺字段容错（默认空串/空列表）。
- [x] **Step 2:** 实现三模型 + 序列化。
- [x] **Step 3:** barrel 导出，全量绿，commit。

### Task A2: DomainExpertise + ProjectCompetence

**Files:** Create `models/domain_expertise.dart`、`models/project_competence.dart`；barrel；测试镜像。

**Interfaces:**
```dart
class DomainExpertise {         // 4-领域，L2 可迁移
  final String domain;
  final String notes;           // EXPERTISE.md 正文
  final List<String> principles; // 领域判断标准
  final List<MemoryEntry> playbooks; // L2
  final List<ProjectRef> projects;   // 引用 project-id（多对多，spec §2.2）
}

class ProjectCompetence {       // 4-项目，L1 绑定项目
  final String projectId;
  final List<String> repos;
  final String coordinates;
  final String moduleStructure;
  final List<KeyFile> keyFiles;
  final String dataflow;
  final List<String> techStack;
  final List<String> sdks;
  final List<String> difficulties;
  final String github;
  final String source;          // opensource | private
  final String retention;       // full | experience-only
  // L1 记忆：
  final String notes;           // project-notes
  final List<MemoryEntry> solved;
  final List<MemoryEntry> playbooks;
  final List<String> domains;   // 反向索引：该项目归属哪些领域（多对多，可空）
}
```
- [x] **Step 1:** 测试：两模型 `toJson→fromJson` 无损 + 缺省容错；`projects` / `domains` 多对多列表正确往返。
- [x] **Step 2:** 实现。
- [x] **Step 3:** barrel、全量绿、commit。

### Task A3: Agent 聚合模型

**Files:** Create `models/agent.dart`；barrel；测试镜像。

**Interfaces:**
```dart
/// 池侧主体：一个「有自我的个体」+ 其掌握的领域 + 干过的项目。
class Agent {
  final AgentCore core;
  final AgentMemory memory;
  final List<DomainExpertise> domains;
  final List<ProjectCompetence> projects;
  final AgentMeta meta;
  // toJson/fromJson 仅覆盖 core+memory+meta（domains/projects 各自独立落盘，见 Phase C）
  // 提供便捷方法：Agent copyWith(...)、withProject(ProjectCompetence)、withDomain(DomainExpertise)
}
```
- [x] **Step 1:** 测试：`agent.json`（core+memory+meta）往返；`withProject`/`withDomain` 按 id/domain 去重替换（同 projectId 覆盖而非追加）。
- [x] **Step 2:** 实现。
- [x] **Step 3:** barrel、全量绿、commit。

**Acceptance（Phase A）:** 五个新模型往返无损、缺省容错；多对多列表正确；`Agent.withProject/withDomain` 幂等去重。

---

## Phase B：AgentPoolAdapter（Agent ↔ 视图文件）

### Task B1: 渲染 Agent → FileArtifact 树

**Files:** Create `crew_core/lib/src/expert/agent_pool_adapter.dart`；barrel；Create `test/expert/agent_pool_adapter_test.dart`。

**Interface:**
```dart
class AgentPoolAdapter {
  const AgentPoolAdapter();
  /// 产出相对 <poolRoot>/agents/<id>/ 的全部工件（含 domains/、projects/）。
  List<FileArtifact> render(Agent agent);
}
```
渲染清单（对齐 §3）：
- `agent.json`（`isMemory:false`）= core+memory+meta。
- `IDENTITY.md` / `RELATIONSHIPS.md` / `TOOLS.md`（`isMemory:false`，视图）。
- `memory/MEMORY.md`、`memory/short-term.md`（`isMemory:true`）；`memory/long-term/<path>`（每条一文件，`isMemory:true`；空时写 `long-term/README.md` 模板）。
- 每个 domain：`domains/<d>/domain.json`(false) + `EXPERTISE.md`(false) + `playbooks/<*>`(true，空时 README) + `projects.md`(true，视图渲染 `projects` 引用)。
- 每个 project：`projects/<pid>/project.json`(false) + `COMPETENCE.md`(false) + `memory/project-notes.md`(true) + `memory/solved/<*>`(true，空 README) + `memory/playbooks/<*>`(true，空 README)。

> `solved/playbooks` 的 `path` 前缀处理沿用现有 `expert_pool_adapter.dart` 的 `_stripPrefix`（避免 `solved/solved/x.md`）。

- [x] **Step 1:** 测试：一个填满的 Agent（1 domain + 2 projects，其中一个 project 被两个 domain 的 `projects.md` 同时引用）渲染出上述全部文件；`agent.json`/`domain.json`/`project.json` 能 `fromJson` 还原为等价对象（往返一致）；记忆类文件 `isMemory:true`、视图类 `false`。
- [x] **Step 2:** 实现渲染（可拆私有 `_renderIdentity/_renderCompetence/_renderExpertise/_renderProjectsMd`）。
- [x] **Step 3:** 全量绿、commit。

**Acceptance:** 渲染文件齐全且布局对齐 §3；三类 `*.json` 回读一致；记忆保护标记正确；多对多引用在两个 domain 的 `projects.md` 都出现。

---

## Phase C：AgentPool（文件系统读写 + 索引）

### Task C1: AgentPool save/load/list

**Files:** Create `crew_core/lib/src/expert/agent_pool.dart`；新增 `models/agent_summary.dart`（替代/并存 `expert_summary.dart`）；barrel；Create `test/expert/agent_pool_test.dart`。

**Interfaces（对齐 §3 布局）:**
```dart
class AgentPool {
  final Directory root;                 // 可注入（测试用临时目录）
  AgentPool(this.root, {AgentPoolAdapter? adapter, WritePlanner? planner});

  Future<void> save(Agent agent);       // 写 agents/<id>/**（含 domains/ projects/）
  Future<Agent?> load(String agentId);  // 读 agent.json + 扫描 domains/ + projects/ 组装 Agent
  Future<List<AgentSummary>> list();    // 扫 agents/*/agent.json
  Future<void> delete(String agentId);  // 递归删 agents/<id>/

  // 细粒度（供管线用，避免整体重写）：
  Future<void> saveProject(String agentId, ProjectCompetence p);
  Future<void> saveDomain(String agentId, DomainExpertise d);
  Future<ProjectCompetence?> loadProject(String agentId, String projectId);
  Future<DomainExpertise?> loadDomain(String agentId, String domain);
}
```
- **记忆保护**：`save` 走 `WritePlanner.plan/apply`（`isMemory` 已存在则 skip）。
- **`load` 组装**：读 `agent.json` → core/memory/meta；扫 `domains/*/domain.json` → `List<DomainExpertise>`；递归扫 `projects/**/project.json` → `List<ProjectCompetence>`（project-id 含 `/`，需递归，参考现有 `ExpertPool._scanKind`）。
- **`pool.yaml`**：维护 `{agentId, displayName, domains:[...], projectCount, version}` 索引；`list()` 可直接扫目录（与现有 `ExpertPool.list` 同思路，允许不读 pool.yaml）。

- [x] **Step 1:** 测试（临时目录）：
  - `save(agent)` → `load(id)` 往返等价（core/memory/domains/projects 全含）。
  - `saveProject`/`saveDomain` 单独落盘、`loadProject`/`loadDomain` 回读。
  - `list()` 返回摘要（含 domains 列表、projectCount）。
  - **记忆不被覆盖**：预置一个 `projects/<pid>/memory/solved/x.md`，`save` 后其内容不变。
  - project-id 含 `/`（`github.com/foo/bar`）能正确嵌套存取。
- [x] **Step 2:** 实现。
- [x] **Step 3:** 全量绿、commit。

**Acceptance:** 存取往返一致；细粒度 API 可用；`list()` 正确；记忆不被覆盖；嵌套 project-id 正确；布局对齐 §3。

---

## Phase D：管线重写（publish / merge / instantiate）

> 三条管线（专家池 spec §6）语义不变，但主体从"独立 Expert"变为"agent 主体 + 子层"。

### Task D1: Publisher（workspace agent → agent 主体 + ProjectCompetence）

**Files:** Rewrite `crew_core/lib/src/expert/publisher.dart`；Modify `test/expert/publisher_test.dart`。

**Interface:**
```dart
class PublishOutcome2 {
  final AgentCore core;             // upsert 用（新建时用它，已存在时不覆盖 personality）
  final ProjectCompetence project;  // 本次发布的项目能力（retention=none 时整个返回 null）
}

/// 把 workspace 的 AgentSpec + 记忆，映射为「某 agent-id 的一次项目发布」。
/// - agentId 由调用方指定（哪个个体在发布，spec §2.1）
/// - retention: full | experience-only | none（none → 返回 null）
/// - experience-only: 抹去 L1 具体（keyFiles/coordinates/repos/solved + redactPaths(notes)）
PublishOutcome2? publishProject({
  required String agentId,
  required AgentSpec spec,
  required ExpertMemory workspaceMemory,
  required String retention,
  required String source,           // opensource | private
  String? gitRemoteUrl,             // → projectId + (opensource 时) github
  required String workspacePath,
  required int version,
});
```
**映射规则（AgentSpec → 新模型）:**
| AgentSpec 字段 | 去向 |
|---|---|
| name/displayName/role/personality/principles | `AgentCore` |
| repos/coordinates/moduleStructure/keyFiles/dataflow/techStack/sdks/difficulties/github/source | `ProjectCompetence` |
| workspaceMemory.notes/solved/playbooks | `ProjectCompetence` 的 L1 记忆 |

- 隐私：沿用现有 `redact.dart`；`private` 时 `github` 留空；`experience-only` 按上表抹除 L1 具体。
- 不生成 agent 记忆内容（agent memory 的 short/long term 在 save 时保留已有；首发布可空）。

- [ ] **Step 1:** 测试（迁移现有 3 档用例）：`full` 保完整；`opensource` 落 github、`private` github 留空；`experience-only` 抹 keyFiles/coordinates/repos/solved 且 notes 去路径；`none` 返回 null；`core.id == agentId`；映射分流正确（personality 进 core、keyFiles 进 project）。
- [ ] **Step 2:** 实现（纯函数、无 IO）。
- [ ] **Step 3:** 全量绿、commit。

### Task D2: Merger（ProjectCompetence → 同 agent 下 DomainExpertise，多对多）

**Files:** Rewrite `crew_core/lib/src/expert/merger.dart`；Modify `test/expert/merger_test.dart`。

**Interface:**
```dart
/// 把某 agent 的一个 ProjectCompetence 蒸馏并入其某个 DomainExpertise。
/// - runner.distill 把 L1 抽象成 L2（notes/playbooks），并入 domain（沿用现有 distill_parser）
/// - domain.projects 追加 ProjectRef(projectId, summary)（按 id 去重，幂等）
/// - 同步把 domain 名加入 project.domains（反向索引，去重）→ 返回可能被更新的 project
class MergeOutcome {
  final DomainExpertise domain;
  final ProjectCompetence project; // 反向索引已更新
}
Future<MergeOutcome> mergeIntoDomain({
  required DomainExpertise domain,     // 现有或空壳（domain 名已定）
  required ProjectCompetence project,
  required Runner runner,
});
```
- playbooks 按 path 去重；notes 追加（distill 输出本身抽象）。
- **多对多**：一个 project 可被并入多个 domain → 各 domain 的 `projects` 都含它，project 的 `domains` 反向含所有并入过的 domain。

- [ ] **Step 1:** 测试（FakeRunner）：空壳 domain + project → domain.notes/playbooks 来自 distill、`projects` 含 1 条、`project.domains` 含该 domain；同一 project 再并入**同 domain** → 幂等不重复；同一 project 并入**第二个 domain** → 两个 domain 都引用它、`project.domains` 增到 2。
- [ ] **Step 2:** 实现（distill prompt 复用现有 `_buildDistillPrompt` 思路，输入改为 ProjectCompetence 字段）。
- [ ] **Step 3:** 全量绿、commit。

### Task D3: Instantiator（AgentCore + DomainExpertise → workspace seed）

**Files:** Rewrite `crew_core/lib/src/expert/instantiator.dart`；Modify `test/expert/instantiator_test.dart`。

**Interface:**
```dart
/// 把「某 agent 的某个领域专长」实例化进新 workspace。
/// 带上：core 身份(personality/principles/role) + tools + 该 domain 的 L2(notes/playbooks/projects 索引)
/// 不带：任何 project 的 L1（solved/keyFiles/coordinates）——避免误套 + 泄漏
class InstantiatedAgent {
  final AgentSpec spec;                // 回填 workspace 侧 spec（name/repos + 可迁移字段）
  final List<FileArtifact> memorySeed; // memory/<name>/ 下，isMemory:true
}
InstantiatedAgent instantiate({
  required AgentCore core,
  required DomainExpertise domain,
  required String agentName,
  required List<String> newRepos,
});
```
- `spec` 由 core + domain 组装（personality/principles from core；techStack 等可迁移面可留空或从 domain 派生；repos=newRepos）。
- memorySeed：`MEMORY.md`(索引) + `domain-notes.md`(domain.notes) + `playbooks/<*>` + `projects.md`(只读引用) + 可选 `TOOLS.md`（core.tools）。**无 solved/**。

- [ ] **Step 1:** 测试：spec.repos=newRepos、含 core.personality；memorySeed 含 domain-notes/playbooks/projects.md，**不含 solved/ 或任何 L1 具体路径**；全部 `isMemory:true`。
- [ ] **Step 2:** 实现（纯函数）。
- [ ] **Step 3:** 全量绿、commit。

**Acceptance（Phase D）:** publish 分流+隐私正确；merge 多对多+幂等+反向索引；instantiate 只带 core+L2、不带 L1。

---

## Phase E：短期记忆淘汰（spec §4.4）

### Task E1: 记忆归并/淘汰纯函数

**Files:** Create `crew_core/lib/src/expert/memory_eviction.dart`；barrel；Create `test/expert/memory_eviction_test.dart`。

**Interface:**
```dart
/// 收工归并：把 shortTerm 里值得沉淀的条目并入 longTerm，其余作废。
/// - promote: 由调用方（或 runner 蒸馏）标出要沉淀的条目；本函数只做搬运+去重
/// - 容量上限 maxShortTermEntries：超出时最旧的先归并/丢弃（FIFO）
AgentMemory consolidate({
  required AgentMemory memory,
  required List<MemoryEntry> promoteToLongTerm, // 要沉淀的
  required List<String> dropFromShortTerm,      // 作废的（按行标识）
  int maxShortTermEntries = 50,
});
```
> 短期以"行"为条目（`short-term.md` 每行一条），long-term 以文件为条目。阈值默认 50（可调），**长期只增不自动删**。

- [ ] **Step 1:** 测试：promote 的条目进 longTerm（按 path 去重）；drop 的从 shortTerm 移除；超阈值时最旧 FIFO 归并；长期不被删。
- [ ] **Step 2:** 实现（纯函数）。
- [ ] **Step 3:** 全量绿、commit。

**Acceptance:** 归并/去重/FIFO 正确；长期不自动删。

---

## Phase F：自动迁移 crew migrate（spec §7）

### Task F1: 旧平铺布局 → 新 agents/ 布局

**Files:** Create `crew_core/lib/src/expert/migrate.dart`；barrel；Create `test/expert/migrate_test.dart`。

**背景**：旧布局 `<oldRoot>/projects/<id>/expert.json`(kind=project)、`<oldRoot>/domains/<d>/expert.json`(kind=domain)，用现有 `Expert.fromJson` 读取（**保留旧 `models/expert.dart` 只读用于迁移**）。

**Interface:**
```dart
class MigrationReport {
  final int agents, domainsMoved, projectsMoved;
  final List<String> needsManualReview; // 无法自动归属的条目
}
/// 幂等：读旧布局 → 聚类出 agent → 写新布局。先由调用方备份。
Future<MigrationReport> migratePool({
  required Directory oldRoot,
  required Directory newRoot,
  required int version,
});
```
**聚类规则（agent-id 生成，spec §2.1）:**
- 由 `Expert.spec.name` + `personality` 聚类为"同一个体"：`agentId = slug(name)`（name 相同即同一 agent；personality 冲突时留一份 + 记入 `needsManualReview`）。
- 旧 ProjectExpert → 该 agent 的 `ProjectCompetence`（spec 字段 + L1 记忆按 D1 反向映射）。
- 旧 DomainExpert → 该 agent 的 `DomainExpertise`（notes/playbooks/projects 搬入；`projects` 引用改为新 project-id）。
- 旧 DomainExpert 的 personality/role → 若该 agent 尚无 core，用它初始化 core。
- `relationships`/`tools`/`shortTerm` 无旧数据 → 空模板。

- [ ] **Step 1:** 测试（临时目录）：造旧布局（2 project + 1 domain，其中 project 的 name 相同 → 归一为 1 agent）→ migrate → 新布局下 `agents/<id>/projects/*` 与 `domains/*` 齐全、report 计数正确；**再跑一次幂等**（不重复、不报错）；personality 冲突项进 `needsManualReview`。
- [ ] **Step 2:** 实现（读用 `Expert.fromJson`，写用 `AgentPool`）。
- [ ] **Step 3:** 全量绿、commit。

**Acceptance:** 旧数据正确搬入新层级；幂等；冲突可报告；`AgentSpec` 与 workspace 侧不受影响。

---

## Phase G：CLI + GUI 接线

> 引擎（A–F）稳定后接线。改造现有 `publish` / `use-expert` / 池服务，新增 `migrate`。

### Task G1: CLI

**Files:** Modify `crew_cli/lib/src/commands/publish.dart`（`PublishOptions` 增 `agentId`；流程改为 `publishProject`(新) → `AgentPool.saveProject` →（有 `--to <domain>`）`mergeIntoDomain` → `saveDomain`+`saveProject`回写反向索引）；Modify `use_expert.dart`（`UseExpertOptions` 增 `agentId`；`AgentPool.load` → 取 domain → `instantiate`）；Create `commands/migrate.dart`（备份 `<root>` → `<root>.bak` → `migratePool` → 打印 report）；Modify `bin/`/参数解析、对应 test。
- [ ] **Step 1:** 测试：publish 建 agent+project、`--to` 触发 merge（多对多反向索引写回）；use-expert 用 agentId+domain 实例化、记忆保护生效；migrate 端到端 + 幂等 + 备份存在。
- [ ] **Step 2:** 实现。
- [ ] **Step 3:** `cd crew_cli && dart test` 全绿、commit。

### Task G2: GUI

**Files:** Modify `crew_gui/lib/services/expert_pool_service.dart`（`ExpertPool`→`AgentPool`；`list()` 返回 `AgentSummary`；publish/use 传 `agentId`；`delete` 改按 agentId/子层；新增 `migrate()`）；Modify 池/详情/编辑页（`ui/expert_pool_page.dart`、`expert_detail_page.dart`、`experts_page.dart` 等）按 **agent → domains/projects** 层级展示；对应 widget test。
- [ ] **Step 1:** 更新/新增 widget + service 测试（层级展示、发布带 agentId、迁移入口）。
- [ ] **Step 2:** 实现。
- [ ] **Step 3:** `cd crew_gui && flutter test` 全绿、commit。

**Acceptance（Phase G）:** CLI/GUI 全绿；publish/use/migrate 走新 `AgentPool`；池 UI 按 agent 层级展示。

---

## 收尾清理（Phase G 后）

- [ ] 移除旧写路径：`ExpertPool` 的 `saveProject/saveDomain` 及 `ExpertPoolAdapter`（**保留 `Expert.fromJson` 供 migrate 只读**，或迁移完成后一并删除并在 CHANGELOG 记录）。
- [ ] `expert_summary.dart` 若被 `AgentSummary` 取代则移除，更新 barrel。
- [ ] 全仓 `dart test` / `flutter test` 全绿，无跳过。

---

## 验收（由 Claude 负责，分阶段可分批验）

按 A→G 顺序验收各任务 Acceptance；全部完成后统一核对：

1. **测试全绿**：`crew_core` / `crew_cli` / `crew_gui` 各自 `dart test`/`flutter test` 全通过、无跳过。
2. **A**：五模型往返无损 + 缺省容错 + 多对多列表 + `withProject/withDomain` 幂等。
3. **B**：`AgentPoolAdapter` 渲染齐全、布局对齐 §3、三类 json 回读一致、多对多引用双现、记忆保护标记正确。
4. **C**：`AgentPool` 存取往返、细粒度 API、`list()`、嵌套 project-id、记忆不被覆盖。
5. **D**：publish 分流+隐私（experience-only 无 L1 具体）；merge 多对多+幂等+反向索引；instantiate 只带 core+L2、不带 L1。
6. **E**：短期归并/FIFO/长期不删。
7. **F**：迁移正确+幂等+冲突报告；未触及 `AgentSpec`/workspace 侧。
8. **G**：CLI/GUI 走新 `AgentPool`；层级展示；migrate 入口可用。
9. **约束合规**：无新依赖、无 `package:flutter`（core）、无库内 `DateTime.now()`/硬编码 HOME；barrel 完整；未违反 §0.4 边界。

验收通过后，Claude 勾选任务并记录结论。

---

## 验收结论（Claude，2026-07-18）

**部分通过 — 仅 Phase A/B/C 完成（3/7），D/E/F/G 未实现。** GLM-5.2 实现的 A/B/C 质量高、测试完整；`cd crew_core && dart test` = **243 passed, 0 skipped**。改动已单独提交为 `edc9b1d`（分支 `feat/agent-structure-phase-abc`，14 文件、+1946，未含会话前既有的无关改动）。

| 阶段 | 结论 |
|------|------|
| **A 池侧新模型** | ✅ AgentCore/AgentMemory/AgentMeta/DomainExpertise/ProjectCompetence + 聚合 **AgentProfile**（避开已被 workspace 侧占用的 `Agent` 名，附注释说明）+ AgentSummary；往返无损、缺省容错、多对多列表、`withProject/withDomain` 幂等去重均有真断言 |
| **B AgentPoolAdapter** | ✅ 渲染齐全对齐 §3；`agent.json`/`domain.json`/`project.json` 回读一致；`isMemory` 标记正确；`multi-many: project p1 appears in both domains projects.md` 已验 |
| **C AgentPool** | ✅ save/load/list/delete + 细粒度 saveProject/saveDomain/loadProject/loadDomain；**记忆保护真断言**（用户手改 `solved/leak.md`、`long-term/recap.md` 再次 save 保留，新条目仍写入）；嵌套 project-id `github.com/foo/bar` 正确 |
| **D 管线重写** | ❌ **未做**：`publisher/merger/instantiator` 仍是旧 `Expert` 版，未引用新模型 |
| **E 短期记忆淘汰** | ❌ **未做**：`memory_eviction.dart` 不存在 |
| **F 自动迁移** | ❌ **未做**：`migrate.dart` / `crew migrate` 不存在 |
| **G CLI+GUI 接线** | ❌ **未做**：`AgentPool` 在 lib(非 test) 中无人调用；CLI/GUI 仍接旧 `ExpertPool` |

**关键影响：** 新结构目前是**自洽但孤立的骨架**——模型/适配器/池齐备且互相打通，但无管线产出或消费 `AgentProfile`，多对多反向索引（`project.domains` ↔ `domain.projects`）无管线填充，用户实际仍走旧平铺路径。功能上尚不能端到端跑通。

**待返工（按序，即 Phase D→E→F→G）：**
1. **D**：重写 `publisher`（加 `agentId` + AgentSpec→AgentCore/ProjectCompetence 分流）、`merger`（多对多 + 填 `project.domains`）、`instantiator`（core+L2、不带 L1）。
2. **E**：新建 `memory_eviction.dart`（收工归并 + FIFO）。
3. **F**：新建 `migrate.dart` + `crew migrate`（旧平铺→新层级，幂等 + 冲突报告）。
4. **G**：CLI/GUI 切到 `AgentPool`；执行收尾清理（删旧写路径）。
