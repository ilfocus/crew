# Crew CLI 接线：publish / use-expert Implementation Plan

> **For agentic workers:** TDD 逐任务。分两部分：**Part A（crew_core 基础，GUI 也复用）** 与 **Part B（新 crew_cli 包）**。每任务：先测 → 实现 → commit。步骤用 `- [ ]` 跟踪。

**Goal:** 把 P2 专家池引擎（`plans/2026-07-16-crew-expert-pool-p2.md`，已完成）暴露成命令行：
- `crew publish` —— 把一个已生成 workspace 里的 agent 提炼发布成专家（可选并入领域专家）。
- `crew use-expert` —— 从专家池调一个领域专家，实例化进目标 workspace。
- `crew list-experts` —— 列出池中专家。
同时补上真实的 `CliRunner.distill`。

**关键缺口（实现前必读）:** 发布需要把 workspace 里的 **结构化 `AgentSpec` + 分层记忆** 读回来，但当前 `emit` 只写了渲染后的 `.claude/agents/*.md`（`agent_body`）与 `memory/**`，**没有存结构化 spec**。因此 Part A 必须先：①生成时持久化 `AgentSpec` JSON；②提供"读 workspace → (AgentSpec, ExpertMemory)"的 Reader。

**已就绪基础:** `Expert`/`ExpertMemory`/`ExpertPool`/`publishProject`/`mergeIntoDomain`/`instantiate`/`deriveProjectId`（提交 `fd740aa`）；`Runner.distill` 接口（`runner.dart:21`）；`CliRunner`（`cli_runner.dart`，distill 目前抛 `UnimplementedError`）。

## Global Constraints

- crew_core 仍：无 `package:flutter`、仅 `yaml`/`path`、无库内 `DateTime.now()`/硬编码 HOME。
- **池路径解析放在 crew_cli**（`~/.crew/experts` 从 HOME 解析），crew_core 的 `ExpertPool` 只收 `Directory`。
- 版本号/时间戳由 crew_cli 传入（如用 git 或 `--version`；CLI 层可用 `DateTime.now()`，crew_core 不可）。
- crew_cli 可有自己的依赖（允许 `args`）。

---

# Part A — crew_core 基础（GUI 接线也依赖）

### Task A1: 生成时持久化 AgentSpec + WorkspaceReader

**Files:**
- Modify: `crew_core/lib/src/engine/generation_pipeline.dart`（`renderAll` 增写 `.crew/specs/<name>.json`）
- Create: `crew_core/lib/src/expert/workspace_reader.dart`
- Modify: barrel
- Create: `crew_core/test/expert/workspace_reader_test.dart`
- Modify: `crew_core/test/engine/generation_pipeline_test.dart`

**Interfaces:**
```dart
// renderAll 额外产出（非记忆，可覆盖）：每个 spec 一份
//   FileArtifact('.crew/specs/<name>.json', jsonEncode(spec.toJson()))

class WorkspaceAgent { final AgentSpec spec; final ExpertMemory memory; }
class WorkspaceReader {
  final Directory root;
  WorkspaceReader(this.root);
  /// 读 crew.yaml + .crew/specs/*.json + memory/<name>/ → 每个 agent 的 (spec, memory)
  Future<List<WorkspaceAgent>> readAgents();
  Future<WorkspaceAgent?> readAgent(String name);
}
```
- `ExpertMemory` 从 `memory/<name>/` 反读：`index`=MEMORY.md，`notes`=project-notes.md，`solved`=solved/ 下非 README 文件，`playbooks`=playbooks/ 下非 README 文件，`projects`=空（workspace 里没有）。

- [x] **Step 1: 测试（红）**
  - 管线测试：`generate`+`emit` 后 `.crew/specs/<name>.json` 存在且 `AgentSpec.fromJson(jsonDecode(...))` 等价还原。
  - `workspace_reader_test`：构造一个含 crew.yaml、`.crew/specs/ios.json`、`memory/ios/{MEMORY.md,project-notes.md,solved/x.md,playbooks/y.md}` 的临时目录 → `readAgent('ios')` 返回正确 spec + memory（solved/playbooks 各 1 条，忽略 README.md）。
- [x] **Step 2:** `renderAll` 增写 spec JSON（`isMemory:false`）。
- [x] **Step 3:** 实现 `WorkspaceReader`（读文件；`solved/playbooks` 跳过 `README.md`）。
- [x] **Step 4:** barrel 导出。全量 `dart test` 绿。Commit。

**Acceptance:** 生成落 spec JSON 并可还原；Reader 正确重建 (spec, memory)，跳过模板 README。

### Task A2: 真实 CliRunner.distill

**Files:**
- Modify: `crew_core/lib/src/runner/cli_runner.dart`
- Modify: `crew_core/test/runner/cli_runner_test.dart`

**Interfaces:** `distill({required String prompt})` 用与 `probe` 相同的 headless 调用（`_run(tool, _args(prompt))`，workingDir 用 `'.'` 或不传），返回 `RunnerResult(stdout, exitCode)`。

- [x] **Step 1: 测试** 用注入的 `ProcessRunner` fake：断言 `distill` 用正确 `tool`+`_args(prompt)` 调用、把 stdout/exitCode 封成 `RunnerResult`（复用现有 `cli_runner_test` 的 fake 手法）。
- [x] **Step 2:** 实现（去掉 `UnimplementedError`）。
- [x] **Step 3:** 全量绿。Commit。

**Acceptance:** `distill` 走 CLI、返回结果；用 fake ProcessRunner 可测，不依赖真实 CLI。

---

# Part B — crew_cli 包

### Task B1: 包脚手架 + 池路径

**Files:**
- Create: `crew_cli/pubspec.yaml`（`dependencies: crew_core: {path: ../crew_core}`, `args: ^2.5.0`；`dev: test`）
- Create: `crew_cli/bin/crew.dart`（子命令分发）
- Create: `crew_cli/lib/src/pool_path.dart`（`Directory defaultPoolDir()` 解析 `~/.crew/experts`，`--pool` 覆盖）
- Create: `crew_cli/test/pool_path_test.dart`

- [x] **Step 1:** pubspec + 空 `bin/crew.dart`（打印用法）+ `defaultPoolDir()`（读 `Platform.environment['HOME']`/`USERPROFILE`）。
- [x] **Step 2:** 测试：`defaultPoolDir()` 在给定 HOME 下拼出 `<home>/.crew/experts`（用可注入的 env 或包装函数以便测）。
- [x] **Step 3:** `cd crew_cli && dart pub get && dart test` 绿。Commit。

**Acceptance:** 包可跑；池路径解析正确且可被 `--pool` 覆盖。

### Task B2: `crew publish`

**Files:**
- Create: `crew_cli/lib/src/commands/publish.dart`
- Modify: `crew_cli/bin/crew.dart`
- Create: `crew_cli/test/publish_test.dart`

**命令:** `crew publish --agent <name> [--workspace <path=cwd>] [--retention full|experience-only|none] [--source opensource|private] [--domain <d>] [--pool <dir>]`

**流程:**
1. `WorkspaceReader(workspace).readAgent(name)` → (spec, memory)。
2. 探测 git remote：`RepoAnalyzer().gitRemoteUrl(spec.repos.first)`（若有）。
3. `publishProject(spec, memory, retention, source, gitRemoteUrl, workspacePath, version)` → ProjectExpert（`none` 时提示并退出）。
4. `pool.saveProject(expert)`。
5. 若给了 `--domain`：`pool.loadDomain(d)` 或建空壳 → `mergeIntoDomain(domain, project, runner: CliRunner(tool), version)` → `pool.saveDomain(merged)`。
6. 打印结果（projectId、写入路径、是否并入领域）。

- [x] **Step 1: 测试**（用临时 workspace + 临时 pool + FakeRunner 注入）：
  - `experience-only` 发布 → pool 中 project 专家的 spec 无 keyFiles（复用引擎已验证的语义，这里测命令编排）。
  - 带 `--domain quant` → domain 专家被创建且 `learnedProjectIds` 含该项目。
  - 注：命令内部要允许注入 `Runner`/`pool`/`env` 以便测（把纯逻辑放 `runPublish({required deps})`，`bin` 只做参数解析）。
- [x] **Step 2:** 实现。
- [x] **Step 3:** 绿。Commit。

**Acceptance:** publish 编排正确；retention/domain 行为符合；可注入依赖单测。

### Task B3: `crew use-expert` + `crew list-experts`

**Files:**
- Create: `crew_cli/lib/src/commands/use_expert.dart`、`list_experts.dart`
- Modify: `crew_cli/bin/crew.dart`
- Create: `crew_cli/test/use_expert_test.dart`、`list_experts_test.dart`

**use-expert:** `crew use-expert --domain <d> --into <workspacePath> --name <agentName> --repos <p1,p2> [--pool <dir>]`
1. `pool.loadDomain(d)`（不存在报错）。
2. `instantiate(domain, agentName, newRepos)` → InstantiatedAgent。
3. 把 `memorySeed` 写进 `<into>/`（复用 `WritePlanner`，记忆受保护）；spec 可另写 `.crew/specs/<agentName>.json` 便于将来再发布。
4. 打印写入清单。

**list-experts:** `crew list-experts [--pool <dir>]` → 读 `pool.list()`，打印 kind/id-or-domain/learnedCount/version 表。

- [x] **Step 1: 测试**：
  - use-expert：预置一个 domain 专家的 pool → 执行 → 目标 workspace 出现 `memory/<name>/domain-notes.md`、`playbooks/`、**无 solved/**（L1 不带）。
  - list-experts：pool 有 1 project + 1 domain → 输出含两者标识。
- [x] **Step 2:** 实现。
- [x] **Step 3:** 绿。Commit。

**Acceptance:** use-expert 只带 L2 种子进目标 workspace（无 L1）；list 正确。

---

## 明确不做（边界）

- ❌ 不做 GUI 接线（见 `plans/2026-07-16-crew-gui-expert-pool.md`）。
- ❌ 不改专家池引擎语义（publishProject/merge/instantiate 已定稿，只编排调用）。
- ❌ 不做 `regen`/其它 CLI 子命令（本计划只 publish/use-expert/list-experts）。
- ❌ ApiRunner 仍不实现。

## 验收（由 Claude 负责）

1. `cd crew_core && dart test` 与 `cd crew_cli && dart test` 全绿、无跳过。
2. **A1**：生成落 `.crew/specs/*.json` 可还原；`WorkspaceReader` 重建 (spec,memory) 正确、跳过 README。
3. **A2**：`CliRunner.distill` 走 CLI、fake 可测、不再抛 UnimplementedError。
4. **B1**：池路径解析 + `--pool` 覆盖。
5. **B2**：publish 编排（retention/domain/git remote 注入）正确，依赖可注入单测。
6. **B3**：use-expert 种子无 L1、记忆受保护；list-experts 正确。
7. **约束合规**：crew_core 仍无 flutter/新依赖/库内时钟/HOME；池路径与时间戳在 crew_cli 层。

验收通过后，Claude 勾选任务并记录结论。

---

## 验收结论（Claude，2026-07-17）

**通过 ✅** —— 提交 `bc53743`。`crew_core` **173 passed**、`crew_cli` **16 passed**。

| 阶段 | 结论 |
|------|------|
| **A1 spec 持久化 + Reader** | ✅ `generation_pipeline_test`：`renderAll persists .crew/specs/<name>.json`（fromJson 还原）；`workspace_reader_test`：读 spec+memory 重建，`solved/playbooks` 跳过 `README.md`，projects 恒空 |
| **A2 CliRunner.distill** | ✅ 真实实现（`cli_runner.dart` 去掉 UnimplementedError），注入 ProcessRunner fake 可测 |
| **B1 脚手架/池路径** | ✅ `crew_cli` 包可跑；`pool_path.dart` 用 `HOME`/`USERPROFILE` 解析（**在 cli 层，非 crew_core**），`--pool` 可覆盖 |
| **B2 publish** | ✅ `runPublish` 编排 Reader→gitRemote→publishProject→saveProject→(domain)merge；依赖可注入；agent 缺失抛 ArgumentError |
| **B3 use-expert/list** | ✅ `use_expert_test`：写 seed + spec JSON、**无 solved/ 目录（L1 不带）**、记忆已存不覆盖；`list_experts` 正确 |
| 约束合规 | ✅ crew_core 仍无 flutter/新依赖/库内时钟/HOME（`grep` 确认 clean）；池路径与时间戳在 crew_cli 层 |

**非阻塞观察：** `bin/crew.dart` 的真实 CLI 端到端（拉起 `claude`/`codex` distill）未做进程级测试——符合本计划边界（distill 真实行为不单测，Fake+解析已覆盖）。
