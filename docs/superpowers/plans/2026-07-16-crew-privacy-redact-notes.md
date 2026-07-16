# Crew 隐私加固：experience-only 去路径 Implementation Plan

> **For agentic workers:** TDD，单任务，**全部在 `crew_core`**。先测 → 实现 → commit。

**Goal:** 补上 P2 验收记录的非阻塞隐私缺口——`publishProject` 的 `experience-only` 档目前抹掉了 `keyFiles/coordinates/repos/solved`，但 `memory.notes`（project-notes，L1）与 `playbooks` 内容**原样保留**；若其中写了绝对路径 / `~/路径` / `file.ext:行号`，跨客户复用领域专家时仍可能带出私有项目的路径信息。本计划对 `experience-only` 的 `notes` 与 `playbooks` 内容做**路径脱敏**。

**现状锚点:** `crew_core/lib/src/expert/publisher.dart:38` 的 `experience-only` 分支（当前保留 `workspaceMemory.notes` 与 `workspaceMemory.playbooks` 原文）。

## Global Constraints

- 纯 Dart、无新依赖（正则用 `dart:core` 的 `RegExp`）、无库内 `DateTime.now()`。
- **只影响 `experience-only`**；`full` 档行为不变（完整保留，因为 full 是私有档、不对外发布）。
- 脱敏是"防误泄"的启发式，不追求 100%；宁可多替换，不可漏私有路径。

---

### Task 1: redactPaths 工具 + 接入 publisher

**Files:**
- Create: `crew_core/lib/src/expert/redact.dart`
- Modify: `crew_core/lib/src/expert/publisher.dart`
- Modify: barrel `crew_core/lib/crew_core.dart`
- Create: `crew_core/test/expert/redact_test.dart`
- Modify: `crew_core/test/expert/publisher_test.dart`

**Interfaces:**
```dart
/// 把文本里的路径类 token 替换为占位符 '‹path›'，用于跨项目发布前脱敏。
/// 覆盖：
///  - 绝对 unix 路径：/Users/...、/home/...、/opt/... 等以 / 开头的路径段
///  - home 路径：~/...
///  - windows 路径：C:\...
///  - 带行号的文件引用：foo/bar.dart:123、Core/BMApm.swift:279
String redactPaths(String input);
```

- [ ] **Step 1: 测试 `redact_test`（红）**
  - `redactPaths('关联目录：/Users/bm/app/ios')` → 不含 `/Users/bm/app/ios`，含 `‹path›`。
  - `~/bm_app/ios`、`C:\proj\x`、`Core/BMApm.swift:279` 均被替换。
  - 普通文本（无路径）原样返回；`https://github.com/foo/bar`（URL）**不应**被误伤成路径（保留 URL——用边界/前缀规则避免命中 `//` 后的 host 段）。
- [ ] **Step 2: 实现 `redactPaths`**（几条 `RegExp` 顺序替换；先处理 URL 保护再处理路径，或用不匹配 `://` 前缀的规则）。
- [ ] **Step 3: 测试 publisher（红）** 扩 `publisher_test`：`experience-only` 发布时，若 `notes` 含 `/Users/...`、`playbooks` 某条 content 含 `foo.dart:12`，发布后对应文本被脱敏（不含原路径、含 `‹path›`）；`full` 档保持原文不变。
- [ ] **Step 4: 接入 publisher** —— `experience-only` 分支里对 `notes` 调 `redactPaths`，对每个 playbook 的 `content` 调 `redactPaths`（`path` 字段是记忆文件名，保留）。
- [ ] **Step 5:** barrel 导出 `redactPaths`；全量 `dart test` 绿。Commit。

**Acceptance:**
- `redactPaths` 覆盖四类路径、保留 URL、无路径文本不变。
- `experience-only` 发布后 `notes` 与 `playbooks` 内容不含原始路径；`full` 档不受影响。
- 现有 publisher 测试不回归。

---

## 明确不做（边界）

- ❌ 不改 `full` / `none` 档语义。
- ❌ 不做语义级脱敏（人名/密钥等）——本计划只针对文件路径。
- ❌ 不改 merge/instantiate（它们消费的是已脱敏的 experience-only 专家）。

## 验收（由 Claude 负责）

1. `cd crew_core && dart test` 全绿、无跳过。
2. `redact_test`：四类路径命中、URL 保留、纯文本不变。
3. `publisher_test`：`experience-only` 的 notes/playbooks 脱敏；`full` 不变；无回归。
4. 约束合规：无新依赖、`redactPaths` 已从 barrel 导出。

验收通过后，Claude 勾选任务并记录结论。
