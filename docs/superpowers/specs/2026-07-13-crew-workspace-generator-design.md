# Crew — 设计文档（需求 + 技术）

- 状态：草案（已通过 brainstorm 评审，待细化实现计划）
- 日期：2026-07-13
- 作者：bimol@ponyft.com + Claude

---

## 1. 概述

**Crew** 是一个跨端桌面工具，用来**把一队"专家 agent"装配到你的一组代码目录上，一键生成一个可协作的 agent 工作空间目录**。

生成的工作空间就是形如 `/Users/bm/bm/apm_project` 的目录：包含每个专家 agent 的定义（`.claude/agents/*.md`、`.codex/agents/*.toml`）、一套记忆系统（`memory/<agent>/`）、以及团队级说明文档（`CLAUDE.md`/`AGENTS.md`/`ONBOARDING.md`）和工具配置（`.mcp.json`/`.codex/config.toml`）。

生成完成后，用户用 **Claude Code 或 Codex 打开该目录**，即可跟"产品经理(PM)"agent 对话来推进具体开发工作。**Crew 本身不运行 agent 对话循环**——它只负责"装配 + 生成"这一步（生成期会调用 LLM 去理解代码库）。

### 设计动机
手工维护 `apm_project` 这类多 agent、多目录的协作工作空间很繁琐：要为每个专家写带项目坐标/技术栈/模块结构/关键文件行号的定义，要建记忆目录，要保证 `.claude` 与 `.codex` 两套格式内容一致，还要写团队级数据流说明。Crew 把这套装配工作产品化、自动化。

### 非目标（本项目明确不做）
- **不**实现自己的 agent 对话运行时来"干活"（写业务代码由 Claude Code/Codex 完成）。
- **不**做代码托管、CI/CD、任务管理。
- 移动端**不**承担"创建/生成"能力（见 §11 物理限制），仅作配套端。

---

## 2. 领域模型（术语）

| 概念 | 说明 |
|------|------|
| **Workspace** | 一个生成的工作空间目录（如 `apm_project`）。聚合：关联的代码目录集合 + 一队 Agent + 记忆系统 + 工具配置 + `crew.yaml`。 |
| **Repo** | 关联进 Workspace 的一个本地代码目录（1..N 个）。 |
| **Agent** | 一个专家角色实例，隶属某 Workspace，关联 0..N 个 Repo。PM 类型关联全部 Repo。 |
| **AgentTemplate** | 内置角色库条目（iOS/Android/前端/后端/Python/PM…），含：角色名、花名规则、职责描述、探查重点(prompt)、默认关联规则。用户可新建自定义模板并存回本地库复用。 |
| **AgentSpec** | 生成引擎的**统一中间表示**：探查一个 Repo 后产出的结构化数据（项目坐标、技术栈、模块结构、关键文件:行、数据流、记忆约定等）。由 Adapter 渲染成各目标格式。 |
| **Runner** | 生成期调用 LLM 的方式。`CliRunner`（默认，拉起本地 `claude`/`codex`）或 `ApiRunner`（Anthropic API key）。 |
| **OutputAdapter** | 把 AgentSpec / 团队信息渲染成某个目标格式（Claude / Codex / 文档 / MCP）。 |

---

## 3. 需求

### 3.1 功能需求（Functional Requirements）

- **FR-1 关联目录**：用户可为一个 Workspace 选择 1..N 个本地代码目录。
- **FR-2 选择 agent**：用户从**内置角色库**勾选所需专家，并可**新建自定义角色**（角色名 + 职责 + 探查重点），自定义角色可存回本地库复用。
- **FR-3 PM 角色**：Workspace 默认包含一个产品经理(PM)agent，关联全部 Repo，负责全局理解与协调。
- **FR-4 agent↔目录关联**：系统对每个 agent 与 Repo 做**自动分配**（静态探测 + LLM 兜底判断）；用户可在 UI 中**手动覆盖**任意关联。
- **FR-5 生成工作空间**：点击"创建"后，生成引擎产出：
  - **FR-5a** 每个选中的输出目标下的 agent 定义（`.claude/agents/<name>.md` 与/或 `.codex/agents/<name>.toml`），内容源自同一 AgentSpec，保持一致。
  - **FR-5b** 记忆系统：`memory/<agent>/` 目录 + `MEMORY.md` 索引 + 初始 `project-notes.md`。
  - **FR-5c** 团队级文档：`CLAUDE.md`、`AGENTS.md`、`ONBOARDING.md`（含团队构成、各端职责、跨目录数据流、协作约定）。
  - **FR-5d** 工具配置：`.mcp.json` 与/或 `.codex/config.toml`。
  - **FR-5e** `crew.yaml`：记录本 Workspace 的关联关系、选中 agent、模板版本、输出目标等元数据。
- **FR-6 输出目标可选**：创建时用户勾选生成 Claude、Codex、或两者（架构预留其他目标）。
- **FR-7 Runner 可选**：默认用 `CliRunner`（本地 claude/codex）；用户可切换为 `ApiRunner`（配 Anthropic key）。
- **FR-8 生成预览与确认**：落盘前展示"将写入/覆盖的文件清单"，用户确认后才写。
- **FR-9 一键打开**：生成完成后，可一键用 Claude Code / Codex 打开该 Workspace 目录。
- **FR-10 项目管理**：列出已创建的 Workspace，可重新打开、查看、删除记录。
- **FR-11 重生成/增量**：基于 `crew.yaml` 支持后续 `regen` 或新增 agent，**保留用户手改内容和已有记忆目录**（不覆盖记忆、对手改文件走合并/提示策略）。

### 3.2 非功能需求（Non-Functional Requirements）

- **NFR-1 跨端**：MVP 支持 Windows / macOS 桌面；架构不阻断未来 Linux 与移动端配套。
- **NFR-2 无损与幂等**：重复生成对未变输入结果稳定；绝不静默覆盖用户手改或记忆内容。
- **NFR-3 无需额外密钥即可用**：默认 `CliRunner` 复用用户已有的 claude/codex 登录/订阅，不强制配置 API key。
- **NFR-4 核心与 UI 解耦**：`crew_core` 为纯 Dart 包，不依赖 Flutter，可被 GUI 与 CLI 共用、可独立单测。
- **NFR-5 可扩展**：新增输出目标 = 新增一个 OutputAdapter；新增角色 = 新增一个模板；新增 Runner = 实现 Runner 接口。三者互不影响。
- **NFR-6 生成可观测**：生成过程有分步进度与日志，失败可定位到具体 agent/Repo/步骤。

---

## 4. 用户流程（MVP 主闭环）

```
新建 Workspace
  → 选代码目录 (1..N)
  → 选 agent（内置库勾选 + 新建自定义 + PM）
  → agent↔目录关联（自动分配，可手动调整）
  → 选输出目标（Claude / Codex / 两者）与 Runner
  → 点"创建"
      ├─ 引擎：每个 agent 探查其 Repo → AgentSpec
      ├─ 引擎：PM 汇总全局
      ├─ 预览将写入/覆盖的文件清单 → 用户确认
      └─ Adapter 渲染落盘 + 建记忆系统 + 写文档/配置 + crew.yaml
  → 完成：提示 + 一键用 Claude Code / Codex 打开
```

---

## 5. 技术架构

技术栈：**Flutter + Dart**。一套 Dart 代码覆盖 桌面 GUI + CLI + 未来移动端；生成引擎为纯 Dart 共享包。

### 5.1 模块分解

```
crew/
├── crew_core/        # 纯 Dart 包（GUI/CLI 共用，无 Flutter 依赖）
│   ├── models/       # Workspace, Repo, Agent, AgentTemplate, AgentSpec, CrewConfig
│   ├── engine/       # GenerationPipeline：编排 探查 → 汇总 → 预览 → 渲染落盘
│   ├── runner/       # Runner 接口 + CliRunner(claude/codex) + ApiRunner(Anthropic)
│   ├── adapters/     # ClaudeAdapter, CodexAdapter, DocsAdapter, McpAdapter
│   ├── templates/    # 内置角色库 + 自定义模板加载/存储
│   └── analysis/     # 轻量静态探测（Podfile/build.gradle/package.json… → 自动关联候选）
├── crew_gui/         # Flutter app：创建向导 + 项目管理（桌面为主）
└── crew_cli/         # Dart bin（P2）：crew new / add-agent / regen（复用 crew_core）
```

### 5.2 生成管线（GenerationPipeline）

```
输入: Workspace(Repos, Agents, 关联关系, 输出目标, Runner)
 1. analyze()   静态探测每个 Repo（语言/框架/构建文件）→ 关联候选（供 UI 自动分配）
 2. probe()     对每个 (Agent, 其关联 Repos) 用 Runner 派探查任务 → AgentSpec[]
 3. synthesize() PM 汇总所有 AgentSpec → 团队画像（构成/数据流/协作约定）
 4. plan()      计算将写入/覆盖的文件清单 → 返回给 UI 预览确认
 5. emit()      各 OutputAdapter 渲染 AgentSpec/团队画像 → 落盘
                + 建 memory/<agent>/ + MEMORY.md + project-notes
                + 写 CLAUDE.md/AGENTS.md/ONBOARDING.md/配置 + crew.yaml
```

- 步骤 1、2 可对多个 Repo/Agent **并发**执行（受并发上限约束）。
- 步骤 4 是**硬确认闸口**：未确认不进入 emit。
- 步骤 5 对记忆目录与用户手改文件走**保护策略**（见 §8）。

### 5.3 Runner 抽象

```dart
abstract class Runner {
  /// 在 workingDir 下就 prompt 跑一次探查，返回结构化结果文本（供解析为 AgentSpec）。
  Future<RunnerResult> probe({
    required String workingDir,
    required String prompt,
    required AgentTemplate template,
  });
}
```
- `CliRunner`：headless 拉起本地 CLI（如 `claude -p "<prompt>"` / `codex exec "<prompt>"`），采集 stdout。默认。
- `ApiRunner`：用 Anthropic API key 直连，自建最小 fs/grep 工具循环产出 AgentSpec。
- 选择由 Workspace 配置决定；两者产出同一 `AgentSpec` 结构，对下游透明。

### 5.4 OutputAdapter 抽象

```dart
abstract class OutputAdapter {
  String get target; // "claude" | "codex" | "docs" | "mcp"
  Iterable<FileArtifact> render(GenerationResult result);
}
```
- `ClaudeAdapter` → `.claude/agents/<name>.md`（frontmatter: name/description + 正文）
- `CodexAdapter` → `.codex/agents/<name>.toml`（name/description/developer_instructions）+ `.codex/config.toml`
- `DocsAdapter` → `CLAUDE.md` / `AGENTS.md` / `ONBOARDING.md`
- `McpAdapter` → `.mcp.json`（及 codex 侧 mcp 配置）
- **关键**：所有 Adapter 消费同一 `AgentSpec`/团队画像 → 保证多格式**同源一致**。

---

## 6. 数据模型

### 6.1 AgentSpec（中间表示）
```
AgentSpec {
  name            # 角色标识（ios/android/...）
  displayName     # 花名（如"小i"）
  role            # 职责一句话
  repos[]         # 关联目录路径
  coordinates     # 项目坐标：主工程/关键路径/分支/技术栈
  moduleStructure # 模块结构（目录 → 说明）
  keyFiles[]      # 关键文件:行 + 用途
  dataflow        # 在系统中的位置 / 与其他 agent 的上下游关系
  memoryConvention# 记忆读写约定（开工前读、收工后写）
  conventions[]   # 工作约定
}
```

### 6.2 crew.yaml（Workspace 元数据，落在工作空间根）
```yaml
version: 1
name: apm
createdAt: 2026-07-13
repos:
  - path: ~/bm_app/ios
  - path: ~/bm_app/android
  - path: ~/bm_platform_apm-admin
  - path: ~/bm_platform/apm_stack_analysis
targets: [claude, codex]
runner: cli            # cli | api
agents:
  - name: ios
    template: ios-dev@1
    repos: [~/bm_app/ios]
  - name: android
    template: android-dev@1
    repos: [~/bm_app/android]
  - name: platform
    template: backend@1
    repos: [~/bm_platform_apm-admin]
  - name: parser
    template: python@1
    repos: [~/bm_platform/apm_stack_analysis]
  - name: pm
    template: pm@1
    repos: [<all>]
```

### 6.3 生成产物清单（对齐参考项目 apm_project）
```
<workspace>/
├── .claude/agents/<name>.md          # 每个 agent（当 target 含 claude）
├── .codex/agents/<name>.toml         # 每个 agent（当 target 含 codex）
├── .codex/config.toml                # codex MCP/配置（当 target 含 codex）
├── .mcp.json                         # MCP 配置（当 target 含 claude）
├── memory/<name>/MEMORY.md           # 每个 agent 的记忆索引
├── memory/<name>/project-notes.md    # 初始记忆
├── CLAUDE.md                         # 团队级说明（claude）
├── AGENTS.md                         # 团队级说明（codex/通用）
├── ONBOARDING.md                     # 上手说明
└── crew.yaml                         # Crew 元数据
```

---

## 7. 关键设计决策

1. **AgentSpec 统一中间表示**：探查产物先落成结构化数据，再由多 Adapter 渲染 → 保证 `.claude`/`.codex` 同源一致、加新目标格式代价低。
2. **Runner 双实现、对下游透明**：默认 CLI（复用用户订阅、零额外配置），可切 API。产出统一。
3. **自动关联 = 静态探测候选 + LLM 兜底 + UI 可覆盖**：静态探测（识别 Podfile/build.gradle/package.json 等）给快速候选，LLM 处理歧义，用户永远能手动改。
4. **crew.yaml 驱动可重生成**：把关联关系/选中 agent/模板版本沉淀为声明式元数据，支撑 `regen`/增量加 agent。
5. **落盘前硬确认 + 保护策略**：预览文件清单 → 确认后写；记忆目录与用户手改文件不被静默覆盖。

---

## 8. 错误处理与保护策略

- **Runner 失败**（CLI 未安装/未登录、API key 无效、探查超时）：定位到具体 (agent, repo)，可**重试该项**而非整体失败；其余 agent 结果保留。
- **目录不可读/不存在**：创建前校验路径，给出可修复的错误。
- **重生成保护**：
  - `memory/**` 一律**不覆盖**（记忆是运行期资产）。
  - 用户手改过的生成文件：检测差异 → 提示"覆盖 / 跳过 / 生成 `.new` 供对比"。
  - 全新文件直接写。
- **部分失败可续**：管线记录已完成步骤，支持从失败点续跑。

---

## 9. 测试策略

- **crew_core 单测**（纯 Dart，无需 UI/网络）：
  - Adapter 渲染：给定固定 AgentSpec → 断言产出的 `.md`/`.toml`/文档内容（黄金文件对比参考 apm_project 结构）。
  - 静态探测 `analysis`：给定样例目录 → 断言语言/框架识别与关联候选。
  - `crew.yaml` 序列化/反序列化往返一致。
  - 重生成保护：模拟已存在手改文件/记忆目录 → 断言保护行为。
- **Runner**：用 FakeRunner（返回固定 AgentSpec）测管线编排；CliRunner/ApiRunner 各做一层薄集成测试（可标记为需环境）。
- **GUI**：创建向导关键交互 widget 测 + 一条端到端"选目录→选agent→生成到临时目录"冒烟测。

---

## 10. 内置角色库（初始集）

iOS 开发 / Android 开发 / 前端 / 后端 / Python / 产品经理(PM)。每个模板含：默认花名规则、职责描述、探查重点 prompt、默认关联规则（如 iOS→含 `*.xcworkspace`/`Podfile` 的目录）。用户新增自定义角色存本地模板库复用。

---

## 11. 路线图与物理限制

### 分阶段
- **MVP**：`crew_core` + `crew_gui` 桌面创建闭环 —— 选目录、选/自定义 agent、自动+手动关联、双格式输出、记忆系统初始化、预览确认、一键打开、项目管理、重生成保护。
- **P2**：`crew_cli`（`crew new` / `add-agent` / `regen`）。
- **P3**：工作台内嵌对话（codex 样式，直接在 GUI 里跟 PM 对话）。
- **P4**：移动端配套（浏览已建项目、对话、远程触发）。

### 物理限制（与框架无关，需在产品上明确）
"选本地目录 → 派 agent 读代码 → 拉起 CLI 生成" 需要**任意本地文件访问 + 启动子进程**，这是**桌面能力**；手机 App 处于沙箱，无法随意读本地目录或拉起 CLI。因此**创建/生成永远是桌面能力**，移动端只作配套端（P4）。

---

## 12. YAGNI / 暂不做

- 自研 agent 对话运行时（交给 Claude Code/Codex）。
- 多用户/云端同步/团队协作。
- 除 Claude/Codex 外的具体输出目标（架构预留，不预先实现）。
- 移动端的创建能力（物理限制）。
```
