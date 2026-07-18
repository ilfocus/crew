# Crew — Agent 内容结构重构（设计文档）

- 状态：草案（结构与四项关键决策已确认，待写落地实施文档 plans/）
- 日期：2026-07-18
- 作者：bimol@ponyft.com + Claude
- 关联：`docs/superpowers/specs/2026-07-16-crew-expert-pool-design.md`（专家池设计，本文修订其 §5 布局与 §8 数据模型）

---

## 1. 概述与动机

专家池设计（关联文档 §5）把内容分成两类平级实体：`projects/<id>/`（ProjectExpert）和 `domains/<domain>/`（DomainExpert），每个实体各自带一份 `IDENTITY.md` + `AgentSpec`（含 personality）。

从"一个能做事的 agent 应该具备什么"重新审视，这套结构有三个问题：

1. **「自我」被复制、会漂移。** personality / 说话做事风格 / 判断品味本属于**这个人**，与它学过哪个项目、精通哪个领域无关。但现在它嵌在**每一个** ProjectExpert 和 DomainExpert 的 `AgentSpec` 里。一个 agent 学了 5 个项目，就有 5 份 personality 副本，改一处不同步、多份会漂移。
2. **两类关键内容完全没有建模。**
   - **人物关系**（了解用户喜好、与协作 agent 的分工关系）——无字段。
   - **工具使用**（可用的 skill / mcp 清单与调用偏好）——无字段。
3. **记忆没分短期 / 长期。** `ExpertMemory` 只有 index / notes / solved / playbooks，没有短期（近期上下文、可淘汰）与长期（沉淀）之分。

一个能做事做项目的 agent，应具备五个方面：

1. **个性** —— 说话做事风格
2. **人物关系** —— 了解用户喜好、与协作 agent 的关系
3. **记忆** —— 短期记忆 + 长期记忆
4. **专业技能** —— 专业技能 + 项目经验
5. **工具使用** —— skill / mcp

本文的核心判断：**1 / 2 / 3 / 5 属于 agent 本体（天生就有），4 里的「领域」属于"成为专家"才有的内容，「项目」属于"实际接了活"才有的内容。** 据此把平铺的两类实体重构为**以 agent 为主体、domain 与 project 挂在其下**的三层结构。

---

## 2. 三层归属模型

| 层 | 是什么 | 何时存在 | 承载 |
|----|--------|----------|------|
| **Agent（本体）** | 一个"有自我的个体" | 始终存在 | 个性(1) / 关系(2) / 记忆(3) / 工具(5) |
| **Domain（专家身份）** | agent 在某领域的可迁移经验 | 成长为该领域专家后（可多个） | 专业技能(4) 的领域部分（L2） |
| **Project（工作履历）** | agent 在某具体项目干过的活 | 实际接了该项目后（可多个） | 专业技能(4) 的项目部分（L1） |

- **Agent** 是主体，personality / 关系 / 记忆 / 工具**只存一份**。
- **Domain** 与 **Project** 只存各自的"增量"，不再复制自我。
- **Domain → Project 是引用关系，且多对多**：项目正文只存一份在 `projects/`，domain 侧仅做"学过哪些项目"的索引（延续关联文档 §2 的"DomainExpert 由多个 ProjectExpert 聚合而来"，但物理上不重复存正文）。**同一 project 可被多个 domain 索引**——一个项目往往同时属于多个领域（详见 §2.2）。

### 2.1 agent-id 的语义：一个"个体"，不是一个"角色"

**agent 对标现实中的一个人，不是一个职位。** "iOS 工程师"是角色（role），不是身份（identity）：

- 可以有**多个** iOS 工程师 agent，就像现实中多个 iOS 工程师——即便 role 相同，他们在**个性、记忆、专业深度、做过的项目**上各不相同，是不同的个体。
- "iOS 工程师"和"iOS 专家"是**两个不同的 agent**（专业深度/领域掌握不同）。

因此：

- **`agent-id` 是"个体"的稳定唯一标识**，一 agent 一 id，跨其所有 domain/project 不变。
- **`role` 是 `AgentCore` 的一个普通字段**，可重复（多个 agent 同 role）；`role` ≠ `id`。
- **id 取值**：人类可读 slug（个体的名字/代号，如 `ios-lin`、`ios-junior`、`quant-max`），由用户在创建/发布时指定。避免用 role 直接当 id（会撞车）。

### 2.2 一个 project 可归属多个 domain

同一项目往往横跨多个领域，只是**关注的方面不同**：

- **同一 agent 内**：一个既懂 iOS 又懂量化的 agent，做的某项目同时触及两个领域 → 该 `project-id` 同时被 `domains/ios/projects.md` 与 `domains/quant/projects.md` 引用（多对多）。
- **跨 agent**：现实中同一个项目，iOS 工程师和 Android 工程师都参与过——项目内容是同一个，各自记的只是不同方面。因 `project-id` 全局稳定（关联文档 §10：归一化 git remote），同一 `project-id` 可同时出现在多个 agent 的 `projects/` 下，各自持有本方面的 L1。这让"同一项目、不同视角"可被交叉识别。

```
Agent（个性/关系/记忆/工具）
 ├── domains/  ← 成为专家才有：L2 可迁移经验（可多个领域）
 └── projects/ ← 实际工作才有：L1 项目经验（可多个项目）
        ▲
        └── domains/<d>/projects.md 以引用方式指向这里
```

---

## 3. 目录结构

全局、跨 workspace（默认 `~/.crew`，可配置）。专家以中性可序列化格式存放，实例化进 workspace 时才由 Adapter 渲染（延续"同源一致"）。

```
~/.crew/
├── pool.yaml                         # 池索引：agents 清单（id / 掌握 domains / 学过 projects 数 / 版本）
└── agents/
    └── <agent-id>/                   # ← 主体：一个「有自我的个体」（id=个体代号，非角色；见 §2.1）
        │
        ├── agent.json                # 中性格式：AgentCore + meta（可实例化 / 可提炼）
        │
        │  ── 1/2/3/5：agent 天生就有，跨 domain / project 不变 ──
        ├── IDENTITY.md               # 1 个性：说话/做事风格、价值观、角色定位、判断品味
        ├── RELATIONSHIPS.md          # 2 关系：用户画像&喜好 + 协作 agent 名单&分工
        ├── TOOLS.md                  # 5 工具：可用 skill / mcp 清单 + 调用偏好/边界
        ├── memory/                   # 3 记忆（属于"这个人"，跨项目）
        │   ├── MEMORY.md             #   召回索引
        │   ├── short-term.md         #   短期：近期会话/临时上下文，可滚动淘汰
        │   └── long-term/            #   长期：沉淀下来的语义/情景/程序记忆
        │
        │  ── 4-领域：作为"专家"才有的内容（可多个 domain）──
        ├── domains/
        │   └── <domain>/             # quant / web3 / live …
        │       ├── domain.json
        │       ├── EXPERTISE.md      # L2 领域经验/套路/判断标准（可迁移）
        │       ├── playbooks/        # L2 领域程序记忆
        │       └── projects.md       # 该领域学过哪些项目 → 引用 ../../projects/<id>（多对多）
        │
        │  ── 4-项目：实际接了活才有的内容（可多个 project）──
        └── projects/
            └── <project-id>/
                ├── project.json
                ├── COMPETENCE.md     # L1 项目坐标/模块/关键文件:行/git/SDK/重难点
                └── memory/           # L1 项目记忆
                    ├── project-notes.md   # 语义
                    ├── solved/            # 情景（一问题一文件）
                    └── playbooks/         # 程序（本项目专属套路）
```

workspace 内 `<workspace>/memory/<agent>/`（主设计已有）不变，仍是"出勤实例"的就地记忆，提炼时同步回本结构。

---

## 4. 内容归属明细

### 4.1 Agent 本体（1 / 2 / 3 / 5）

| 方面 | 落点 | 内容 |
|------|------|------|
| 1 个性 | `IDENTITY.md` | 说话/做事风格、价值观、角色定位、判断品味与质量红线（通用部分） |
| 2 关系 | `RELATIONSHIPS.md` | 用户画像与喜好；与其它 agent 的协作关系、分工、交接约定 |
| 3 记忆 | `memory/` | `short-term.md`（近期、可淘汰，见 §4.4）；`long-term/`（沉淀）；`MEMORY.md`（召回索引） |
| 5 工具 | `TOOLS.md` | 可用 skill / mcp 清单、调用偏好、使用边界 |

### 4.2 Domain（4 的领域部分，L2 可迁移）

`domains/<domain>/`：`EXPERTISE.md`（重难点/常见坑/SDK 选型/架构套路/领域判断标准）、`playbooks/`（可迁移套路）、`projects.md`（该领域学过的项目索引，引用 `projects/`）。

### 4.3 Project（4 的项目部分，L1 绑定项目）

`projects/<project-id>/`：`COMPETENCE.md`（项目坐标/模块结构/关键文件:行/git/用到的 SDK/项目特有重难点）、`memory/`（`project-notes.md` 语义、`solved/` 情景、`playbooks/` 项目专属程序）。

> L1/L2 切分（关联文档 §3）不变：迁移只带 L2；L1 绑死项目。本文只改变它们的**物理归属**——都收进 agent 之下。

### 4.4 短期记忆的淘汰

`short-term.md` 是可自动淘汰的近期上下文，规则：

- **收工时归并**：收工蒸馏（关联文档 §6 管线①）时，把短期里值得沉淀的条目提炼进 `long-term/`（语义/情景/程序各归其位），其余作废。
- **容量上限**：短期超过阈值（按条数或字节，落地文档定默认值）时，最旧的先被归并/丢弃（FIFO）。
- **长期只增不自动删**：长期记忆的修正/删除仍走人工或收工蒸馏的"过时即改"约定，不做自动淘汰。

---

## 5. 数据模型拆分

现状 `AgentSpec`（`crew_core/lib/src/models/agent_spec.dart`）把三种性质的字段压在一起，按本文拆成三个模型，各归其位：

| 新模型 | 归属 | 由 `AgentSpec` 迁入的字段 | 新增字段 |
|--------|------|---------------------------|----------|
| **`AgentCore`** | Agent 本体 | `name` / `displayName` / `role` / `personality` / `principles`（通用部分） | `relationships`、`tools`（skill/mcp） |
| **`DomainExpertise`** | Domain | — | `domain` / 领域级 `principles` / `playbooks` / `notes` |
| **`ProjectCompetence`** | Project | `repos` / `coordinates` / `moduleStructure` / `keyFiles` / `dataflow` / `techStack` / `sdks` / `difficulties` / `github` / `source` | — |

记忆模型 `ExpertMemory` 相应拆分：

- **Agent 级**：`index` + `shortTerm` + `longTerm`（新增短期/长期切分）。
- **Domain 级**：`notes`(L2) + `playbooks`(L2) + `projects`(引用列表)。
- **Project 级**：`notes`(L1) + `solved`(L1) + `playbooks`(L1)。

`agent.json` / `domain.json` / `project.json` 各自是对应层的中性搬运单元；`IDENTITY/RELATIONSHIPS/TOOLS/EXPERTISE/COMPETENCE/memory/**` 是渲染视图，由 Adapter 保持同源。

---

## 6. 与现状代码的改动面

- **models/**：`AgentSpec` 拆为 `AgentCore` / `DomainExpertise` / `ProjectCompetence`；`Expert` 重构为 `Agent`（持有 `domains` 与 `projects` 列表）；`ExpertMemory` 增短期/长期切分。
- **expert/expert_pool.dart**：`saveProject` / `saveDomain` 由写 `root/projects/…`、`root/domains/…` 改为写 `root/agents/<id>/projects/…`、`root/agents/<id>/domains/…`；`list()` 扫描根改为 `root/agents/`；load/delete 同步。
- **expert/expert_pool_adapter.dart**：渲染物从"每个 expert 一份 IDENTITY+COMPETENCE"改为"agent 一份 IDENTITY/RELATIONSHIPS/TOOLS/memory + 每个 domain 一份 EXPERTISE + 每个 project 一份 COMPETENCE"。
- **expert/workspace_reader.dart**：反向读回按新布局；memory 读取增短期/长期。
- **expert/merger.dart / instantiator.dart / publisher.dart**：合并/实例化/发布按 agent 主体 + 增量子层重写。
- **CLI / GUI**：专家池列表、详情、编辑页按"agent → domains/projects"的层级展示；新增 `crew migrate`（§7 自动迁移）。

> 具体拆分与迁移的实施顺序另立落地文档（`plans/`），本文只定结构与归属。

---

## 7. 自动迁移（旧平铺数据 → 新层级）

旧结构 `~/.crew/experts/projects/<id>/` 与 `domains/<domain>/` 里，personality/role 等本体字段散落在各 `expert.json`。**提供一次性自动迁移命令**（`crew migrate`，幂等、先备份 `~/.crew/experts.bak/`）：

1. 按 name/personality 聚类归并出 agent 本体，落 `agents/<id>/`（去重自我）；无法自动判定归属的冲突项，留一份 + 在迁移报告中列出待用户指认。
2. 旧 ProjectExpert → `agents/<id>/projects/<project-id>/`（COMPETENCE + L1 记忆原样搬入）。
3. 旧 DomainExpert → `agents/<id>/domains/<domain>/`（L2 经验搬入；其 `projects` 索引改为引用新 `projects/`，多对多）。
4. `RELATIONSHIPS.md` / `TOOLS.md` / `memory/short-term.md` 无旧数据，初始化为模板空档。
5. 迁移后打印报告（迁移了几个 agent/domain/project、哪些需人工指认），旧目录保留在 `.bak` 以便回滚。

---

## 8. 关键决策

1. **主体是 agent，不是 expert。** "专家"是 agent 的一种状态（掌握了某 domain），不是独立实体。
2. **自我只存一份。** 个性/关系/记忆/工具挂在 agent 本体，domain/project 只存增量，杜绝复制与漂移。
3. **domain ↔ project 引用而非拷贝。** 项目正文单一真源在 `projects/`，domain 侧只做索引。
4. **补齐关系(2)与工具(5)。** 新增 `RELATIONSHIPS.md` / `TOOLS.md`。
5. **记忆分短期/长期。** agent 本体记忆切成 `short-term` / `long-term`，对齐"短期+长期"的心智模型。
6. **L1/L2 迁移语义不变。** 只改物理归属，不改"迁移只带 L2"的规则。

---

## 9. 已确认的决策（原开放问题）

1. **agent-id = 个体代号，非角色。** agent 对标一个人；role 是可重复字段，id 是稳定唯一 slug（用户创建/发布时指定）。见 §2.1。
2. **一个 project 可归属多个 domain（多对多）。** 同一项目常横跨多领域，只是关注面不同；`project-id` 全局稳定，同一项目还可跨 agent 出现，各持本方面 L1。见 §2.2。
3. **提供自动迁移。** `crew migrate` 一次性把旧平铺数据搬入新层级，幂等、先备份、出报告。见 §7。
4. **短期记忆自动淘汰。** 收工归并进长期 + 容量上限 FIFO；长期不自动删。见 §4.4。

### 待落地文档细化（非阻塞）

- 短期记忆容量阈值的默认值（条数/字节）。
- 迁移中 agent 聚类的判定细则（何时算"同一个体"、冲突指认的交互）。

---

## 10. YAGNI / 暂不做

- 关系图谱可视化 / agent 间自动协商分工。
- 短期记忆的自动摘要压缩。
- 跨 agent 的记忆共享。
