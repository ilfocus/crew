# Crew — 专家池与经验提炼（设计文档）

- 状态：草案（已通过讨论评审，待细化 P2/P3 实现计划）
- 日期：2026-07-16
- 作者：bimol@ponyft.com + Claude
- 关联：`docs/superpowers/specs/2026-07-13-crew-workspace-generator-design.md`（主设计，本文是其扩展）

---

## 1. 概述

本文在主设计（Crew = 把一队专家 agent 装配到代码目录、生成工作空间）之上，增加**两个新能力**：

1. **专家会成长**：一个 agent 在项目里干活时不断沉淀记忆（解决过的问题、项目知识、领域套路），越用越强。
2. **专家可提炼、可复用、可携带**：把在某项目里学成的 agent，连同它长出来的记忆，**提炼回一个全局专家池**，之后能被反复调用到新项目——哪怕新项目的用户不懂这个领域，专家自己知道该做什么。

核心比喻：一个做过直播项目的 iOS 工程师，会了解那个直播项目的方方面面（技术栈、重难点、关键代码、git 仓库、用到的 SDK）；下次做类似项目就能应用经验。做过多个量化项目后，他从"量化工程师"成长为"量化专家"，自带一身跨项目经验。

> **范围说明**：本能力**明显超出 MVP**（主设计 §11 的 MVP 只是单 workspace 创建闭环）。本文作为 **P2/P3 蓝图**。MVP 阶段只在 `crew_core` 里**预留钩子**（见 §11 与配套落地文档 `plans/2026-07-16-crew-expert-hooks-mvp.md`），不实现提炼/专家池本身，以避免 MVP 失控且将来不返工。

---

## 2. 领域模型扩展（三类实体）

主设计里只有 `AgentTemplate`（静态预设）与 `Agent`（workspace 实例）。本文引入第三类：**Expert（带记忆、会成长、全局持久）**。

| 概念 | 说明 | 有记忆？ | 存放位置 |
|------|------|:---:|------|
| **Template（蓝图）** | 静态预设角色，无实战。= 主设计的内置角色库（`AgentTemplate`）。 | 否 | 内置 / 本地模板库 |
| **Agent（实例）** | Template 或 Expert 被实例化进某 workspace 干活，就地长记忆。 | 就地 | `<workspace>/memory/<agent>/` |
| **Expert（专家）** | 持久、带记忆、会成长的实体，活在**全局专家池**，可跨 workspace 反复调用。 | 是 | `~/.crew/experts/**` |

**Expert 有两种（互不相同的实体）：**

| 类型 | 面向 | 记忆内容 |
|------|------|----------|
| **ProjectExpert（项目专家）** | **某一个具体项目** | **L1 项目记忆**：项目坐标 / 模块结构 / 关键文件:行 / git 仓库 / 用到的 SDK / 项目特有决策 |
| **DomainExpert（领域专家）** | **某领域的通用技能**（quant / web3 / live…） | **L2 领域记忆**：重难点清单 / 常见坑 / SDK 选型经验 / 架构套路 + "学过哪些项目"的索引 |

**关系**：DomainExpert 由多个 ProjectExpert 的经验**抽象聚合**而来。量化专家 = 学过一堆量化项目、蒸馏出跨项目通用经验。

```
Template ──实例化──▶ Agent ──提炼/发布──▶ Expert
                                            ├── ProjectExpert（记 L1，某项目）
                                            └── DomainExpert （记 L2，某领域）
                          DomainExpert ◀──抽象聚合── 多个 ProjectExpert
```

---

## 3. 记忆分层（决定经验能否迁移）

经验能不能带到新项目，全在这条切分上：

| 层 | 内容 | 可迁移 | 归属 |
|----|------|:---:|------|
| **L1 项目记忆** | 具体路径、`file:line`、该仓库 git 地址、项目特有 hack、具体决策 | ❌ 绑死该项目 | ProjectExpert |
| **L2 领域记忆** | 重难点清单、常见坑、SDK 选型、架构套路、"做量化通常要考虑 XX" | ✅ 可带到新项目 | DomainExpert |

**"项目专家成长为领域专家" 的本质 = 把一堆 L1 蒸馏出 L2**（去具体、留模式）。这一步需要跑一次 LLM（`distill` 任务，见 §7），不是简单复制。

三类记忆（沿用主 agent 记忆系统设计）在两级专家里的落法：
- **情景记忆 Episodic**（`solved/` 解决过的问题）：主要在 ProjectExpert（L1）。
- **语义记忆 Semantic**（`project-notes` 项目事实 / `domain-notes` 领域事实）：项目事实→L1；领域事实→L2。
- **程序记忆 Procedural**（`playbooks/` 套路）：项目专属套路→L1；通用套路→L2（可迁移）。

---

## 4. 隐私模型（防代码/IP 泄漏）

DomainExpert 会被跨项目、跨客户复用，必须防止把客户 A 私有项目的代码泄给客户 B。

每个 ProjectExpert / 记忆条目带来源与保留标签：

| 字段 | 取值 | 说明 |
|------|------|------|
| `source` | `opensource` / `private` | 项目来源 |
| `github` | URL（仅 opensource） | 开源项目留仓库地址 |
| `retention` | `full` / `experience-only` / `none` | 提炼时保留范围 |

规则：
- **开源项目**：默认 `retention: full`——可留 github 地址、核心代码片段。
- **用户私有项目**：**手动提炼时弹选择**——
  - `full`：保留原始坐标/代码（仅进私有专家，不对外发布）；
  - `experience-only`：只沉淀 L2 抽象经验（去掉具体代码/路径），可进公共领域专家；
  - `none`：不发布。
- **私有信息可单独记忆**：私有项目的 L1 允许存在本地私有区，但不随 DomainExpert 对外发布。

---

## 5. 全局专家池布局

专家池是**全局、跨 workspace** 的（默认 `~/.crew/experts`，可配置）。专家以**中性可序列化格式**存放（与主设计"同源一致"一致：池存中性格式，实例化进 workspace 时才由 Claude/Codex Adapter 渲染）。

```
~/.crew/experts/
├── pool.yaml                        # 池索引：所有专家清单（type/domain/学过项目数/版本）
├── projects/<project-id>/           # ProjectExpert
│   ├── expert.json                  # 中性格式：AgentSpec + meta（可实例化 / 可提炼）
│   ├── IDENTITY.md                  # 人格 + 判断标准 + 角色
│   ├── COMPETENCE.md                # L1：项目坐标/模块/关键文件:行/git/SDK/重难点
│   ├── memory/
│   │   ├── MEMORY.md                # 索引（召回入口）
│   │   ├── project-notes.md         # L1 语义记忆
│   │   ├── solved/                  # L1 情景记忆（一问题一文件）
│   │   └── playbooks/               # L1 程序记忆
│   └── meta.yaml                    # source / github / retention / project-id / 版本
└── domains/<domain>/                # DomainExpert（quant / web3 / live…）
    ├── expert.json
    ├── IDENTITY.md
    ├── memory/
    │   ├── MEMORY.md
    │   ├── domain-notes.md          # L2 领域经验（可迁移）
    │   ├── playbooks/               # L2 领域套路
    │   └── projects/                # 学过哪些项目（每条指向一个 ProjectExpert + 一句话摘要）
    └── meta.yaml                    # domain / 学过项目列表 / 版本
```

workspace 内的 `memory/<agent>/`（主设计已有）不变，是"出勤实例"的就地记忆；提炼时同步回池。

---

## 6. 三条管线

### ① 自动成长（in-workspace，无需人工）

即主 agent 记忆系统的"收工蒸馏"约定（写在 `AGENTS.md`，agent 自己触发）：
```
开工（召回）：读 memory/<agent>/MEMORY.md 索引 → 用症状关键词 grep solved/ 与 playbooks/
             → 命中 playbook 秒解；命中 solved 复用解法
收工（蒸馏）：新解决的问题 → 写 solved/<症状关键词>.md
             新学到的项目事实 → 更新 project-notes
             某类问题出现 ≥2 次 → 提炼成 playbooks/
             更新 MEMORY.md 索引；过时/错误记忆 → 改或删
```
效果：解决同类问题的耗时随次数递减——**可感知的成长**。此管线在 workspace 内，实例越用越强。

### ② 手动提炼 / 发布（`crew publish <agent>`，跨 workspace 写池子）

```
选目标：建新 ProjectExpert  |  追加进已有 DomainExpert（学新项目）
  → distill()   LLM 把 L1 抽象成 L2（去具体、留模式）        [见 §7]
  → 隐私闸门     私有项目 → 用户选 retention（full/experience-only/none）  [见 §4]
  → merge()     并入池中专家记忆（去重 / 修正 / 解冲突）
  → 更新 DomainExpert 的 projects/ 索引 + pool.yaml
```
- **开源项目**可选"自动同步回池"（无隐私风险）。
- **私有项目**必须走人工隐私闸门。
- 这正好落实"自动 + 手动"：自动 = 就地成长（①）；手动 = 决定是否发布到公共区（②）。

### ③ 调用 / 应用（把领域专家拉进新项目）

```
从池实例化 DomainExpert → workspace agent
  带上：L2 领域经验 + playbooks + "我做过这些项目"的索引
  不带：其它项目的 L1（避免误套到新项目 + 避免泄漏）
  → probe() 新项目 → 建这个项目自己的 L1
  → 专家用 L2 经验驱动新项目
```
效果：用户不懂量化，调来的量化专家凭 L2 套路/重难点清单知道该做什么。

---

## 7. distill Runner 任务

提炼（L1→L2 抽象）复用主设计的 `Runner` 抽象，新增一个任务类型，对下游透明：

```dart
// 与主设计 Runner.probe 平行，新增：
Future<RunnerResult> distill({
  required List<ProjectMemory> l1Sources, // 一个或多个项目专家的 L1 记忆
  required String prompt,                  // "抽象出领域通用经验，去掉项目具体坐标/代码"
});
```
- 输入：一个（建新）或多个（聚合）ProjectExpert 的 L1 记忆。
- 输出：结构化的 L2（domain-notes + playbooks），去具体化。
- `CliRunner` / `ApiRunner` 各实现一次，产出统一。

---

## 8. 数据模型

### 8.1 expert.json（中性可序列化格式，池的存储单元）
```jsonc
{
  "kind": "project" | "domain",
  "spec": { /* AgentSpec（含 personality/principles/techStack/sdks/difficulties/source/github） */ },
  "memory": {
    "index": "…MEMORY.md…",
    "notes": "…project-notes / domain-notes…",
    "solved":   [ { "path": "solved/xxx.md", "content": "…" } ],
    "playbooks":[ { "path": "playbooks/xxx.md", "content": "…" } ],
    "projects": [ { "id": "<project-id>", "summary": "…" } ]   // 仅 domain
  },
  "meta": { "source": "opensource|private", "github": "…", "retention": "full|experience-only|none",
            "projectId": "…", "version": 1, "learnedProjectIds": ["…"] }
}
```
> `expert.json` 是"提炼/调用"的搬运单元；`IDENTITY.md`/`COMPETENCE.md`/`memory/**` 是给人看/给 CLI 打开用的渲染视图。两者由 Adapter 保持同源。

### 8.2 solved 条目格式（为"可召回"而设计，主 agent 记忆系统同款）
```markdown
---
症状: 支付页偶发白屏，无报错
关键词: [支付, 白屏, 超时, 连接池]
时间: 2026-07-10
结果: 已修复并验证
来源: 用户报障
source: private
---
根因: 网关连接池默认 5，高峰打满
解法: 连接池调到 50，见 config/gateway.yaml:23
关联: [[playbooks/diagnose-blank]]
```
检索键是**症状/关键词**（下次只认得出现象）；`MEMORY.md` 每条一行、带关键词，供 grep 快速命中。

---

## 9. 关键设计决策

1. **Template ≠ Expert ≠ Agent**：静态蓝图、持久带记忆的专家、workspace 里的出勤实例，三者分离。
2. **专家池全局跨 workspace**：否则复用无从谈起。池存中性格式，实例化时才渲染成 Claude/Codex，沿用"同源一致"。
3. **项目专家与领域专家是两种实体**：前者针对某项目（L1），后者针对通用技能（L2）。
4. **L1/L2 分层是经验迁移的关键**：迁移只带 L2；L1 绑定项目、不跨项目套用。
5. **自动成长 + 手动发布**：自动 = workspace 内收工蒸馏；手动 = 决定是否发布到公共区（私有走隐私闸门）。
6. **隐私分档**：开源留 github/代码；私有提炼时用户选保留范围，`experience-only` 只带走抽象经验。
7. **distill 复用 Runner 抽象**：新增一个任务类型，不动 Runner 双实现结构。

---

## 10. project-id 识别（合并的正确性依赖它）

同一项目再次学习能否正确合并，取决于 id 稳定：
- **首选**：归一化的 git remote URL（去协议/去 `.git`/小写），同一仓库跨机器可识别为同一项目。
- **兜底**（无 git remote）：本地绝对路径的 hash。
- `meta.yaml.projectId` 记录，`merge()` 按它判断"新建 vs 追加"。

> 本项为推荐默认，实现时如需调整以此为准并在落地文档中记录。

---

## 11. 与 crew_core 的映射（P2/P3 改动面）

- **models/**：新增 `Expert`（`ExpertKind.project|domain`）、`ExpertPool`；`AgentSpec` 增 `personality/principles/techStack/sdks/difficulties/source/github` + `toJson/fromJson`（**MVP 钩子已做**，见 §12）。
- **engine/**：新增 `distill`（L1→L2）、`publish`/`merge`（写池）、`instantiate`（池→workspace）三段管线。
- **runner/**：`Runner` 增 `distill` 任务；`CliRunner`/`ApiRunner` 各实现一次。
- **adapters/**：新增 `ExpertPoolAdapter`（中性 `expert.json` ↔ `IDENTITY/COMPETENCE/memory` 渲染）。实例化进 workspace 仍用现有 `ClaudeAdapter`/`CodexAdapter`。
- **配置**：全局池路径（`~/.crew/experts`，可配）。
- **CLI（P2）**：`crew publish <agent> [--to <domain>] [--retention …]`、`crew use-expert <domain>`。

---

## 12. MVP 阶段只做的"钩子"（不返工的最小前置）

见配套落地文档 `plans/2026-07-16-crew-expert-hooks-mvp.md`。要点：
1. **记忆系统分层**：`MemoryAdapter` 产出 `MEMORY.md`（召回索引格式）+ `project-notes.md` + `solved/` + `playbooks/`（含条目模板）。
2. **AgentSpec 扩展 + 中性序列化**：加 `personality/principles/techStack/sdks/difficulties/source/github` 字段 + `toJson/fromJson` 往返（将来 `expert.json` 的核心）。
3. **成长约定内置**：`agent_body` / `AGENTS.md` 渲染出"开工召回 + 收工蒸馏"约定，让自动成长（管线①）当场可跑。

这三样让"专家会成长"在 MVP 就能感知，且为 P2/P3 的"提炼/专家池"铺好数据与格式，届时不返工。

---

## 13. 路线图

- **MVP**：只做 §12 钩子（记忆分层 + AgentSpec 扩展/序列化 + 成长约定）。
- **P2**：`crew_cli` 增 `publish`/`use-expert`；实现 `ExpertPool` + `publish/merge/instantiate` + `distill`（先支持 CliRunner）。
- **P3**：领域专家聚合/去重/冲突消解成熟化；隐私闸门 UI；池的浏览/管理界面。

## 14. YAGNI / 暂不做

- 专家池的云端同步 / 多人共享（先本地全局池）。
- 专家能力评分 / 排行。
- 自动判定项目所属领域（先由用户在 publish 时指定 domain）。
- 跨语言/跨框架的经验自动迁移校验。
