# IELTS Free V0.1 — 测试报告（TEST-REPORT-v0.1）

> 作者：QA 工程师 **严过关** ｜ 团队任务 `software-ielts-free` #4
> 对应架构：`docs/ARCHITECTURE-v0.1.md` §2.1 / §5 / §6 / §7 T05 / §9 ｜ 需求：`docs/PRD-v0.1.md` §3.1 P0 FR-001~FR-092、§9 Q-8/Q-9 ｜ 用户书：`docs/BRIEF.md` #111
> 日期基准：报告基于当前工作区快照（`D:/workbuddyai/ielts_free`）

---

## 0. 执行环境与诚实声明（务必先读）

| 项目 | 状态 |
|---|---|
| Flutter SDK | ❌ 本机**不存在** |
| Dart SDK | ❌ 本机**不存在** |
| Android SDK / gradle | ❌ 本机**不存在** |
| `flutter test` / `flutter analyze` / `dart format` | ❌ **从未执行**（无法执行） |
| Python 3.13.12（含 `sqlite3`） | ✅ 可用（`C:/Users/Administrator/.workbuddy-ai/binaries/python/versions/3.13.12/python.exe`） |

**声明：本报告中所有标注「已执行」的结论，均来自 Python 3.13.12 对真实文件的真实运行输出（见第 2 节，含原始 stdout）。**
**凡是需要 Flutter/Dart 才能得到的结论（`flutter analyze` 结果、`flutter test` 通过率、widget/integration 测试实际执行、CI 实际运行），本报告一律列入第 3 节「未验证结论」，绝不臆造。**

---

## 1. 测试资产清单（Test Inventory）

### 1.1 总览

| 指标 | 数值 |
|---|---|
| 测试文件总数 | **17** |
| 测试用例总数 | **153**（`test()` 147 + `testWidgets()` 6） |
| 测试框架 | `flutter_test` + `sqflite_common_ffi`（**无 mock**，真实 SQLite） |
| 时间可控 | 全部算法测试注入 `FixedClock`（`lib/core/services/clock_service.dart`） |

### 1.2 逐文件清单

| # | 文件 | 用例 | 覆盖需求（FR） | 说明 |
|---|---|---|---|---|
| 1 | `test/helpers/test_database.dart` | — (helper) | FR-005/006 | FFI 工厂初始化 + `runMigrations` 接线；`:memory:` 与临时文件库 |
| 2 | `test/helpers/fixtures.dart` | — (helper) | — | `answerSample` / `vocabWord` 工厂 |
| 3 | `test/smoke_test.dart` | 4 | FR-002/003 | 主题构建（M3 明/暗）、Design Token、常量接线 |
| 4 | `test/core/services/adaptive/memory_service_test.dart` | 14 | **FR-033/034/035** | L0–L6 升降级、clamp、连续错误（wrongCount≥2）间隔减半、UTC |
| 5 | `test/core/services/adaptive/skill_score_service_test.dart` | 17 | **FR-060** | 四因子 C×DF×CF×RF、平滑 0.7raw+0.3prev、clamp 0–100、空样本回退、窗口 |
| 6 | `test/core/services/adaptive/priority_service_test.dart` | 14 | **FR-062** | EF/SI/Recency/Difficulty 四因子、EF=1 边界、排序、并列 |
| 7 | `test/core/services/adaptive/difficulty_service_test.dart` | 14 | **FR-063** | 窗口<3 不动、R1(>85%)、R2(<60%)、R3(连续错 3)优先 |
| 8 | `test/core/services/adaptive/daily_plan_service_test.dart` | 13 | **FR-070/071** | Σ分钟不变式(30/60/90/120)、5 分钟下限、itemCountFor、弱科加权、退化输入；含 **1 个 skip 用例记录 P2-1** |
| 9 | `test/core/services/adaptive/phase_service_test.dart` | 9 | **FR-072/073** | 91/90/89/31/30/29/null 边界 |
| 10 | `test/core/services/adaptive/mastery_service_test.dart` | 8 | **FR-053** | −0.20 / +0.30、阈值 0.80、重入 |
| 11 | `test/core/services/adaptive/streak_service_test.dart` | 8 | **FR-020** | 同日不变、次日+1、断档重置、回滚不变 |
| 12 | `test/core/services/grading_service_test.dart` | 25 | **FR-032/041/044** | 7 词汇题型、归一化、TFNG、MC、Summary Completion、模糊匹配边界 |
| 13 | `test/core/database/migration_test.dart` | 3 | **FR-083 / NFR-30** | v1→v2 真实升级保留 8 表数据、无表被删、新列默认值、新索引、FK、no-op、append-only 守卫 |
| 14 | `test/core/database/schema_consistency_test.dart` | 5 | FR-005/006 | 期望表/索引/列；`memory_level` CHECK(0–6)；内容库 schema 对齐 |
| 15 | `test/core/database/content_database_test.dart` | 7 | **FR-006/090** | readOnly、`integrity_check`、300 词/8 篇/80 题、题型分布、写被拒、SHA256 对 manifest |
| 16 | `test/integration/learning_loop_test.dart` | 6 | **FR-064 / PRD G-2** | **闭环**：错答→错题→能力分→难度/优先级→每日任务变化→重做→掌握度↑；事务原子性 |
| 17 | `test/shared/widgets/shared_widgets_test.dart` | 6 | FR-020 | 共享组件（Empty/Error/Loading/SectionCard/LinearProgressBar/SkillBar） |

> `test/smoke_test.dart` 为工程骨架期既有文件；其余 16 个为本次 T05 QA 交付。

### 1.3 关键测试设计说明

- **A1 算法（#4–#11）**：8 个纯函数算法全部用 `FixedClock`，断言精确数值而非「大致范围」；`daily_plan` 覆盖 Σminutes 不变式与 5 分钟下限两个不变量。
- **A2 数据层（#13–#15）**：迁移测试用「关闭 v1 → 以 version=2 重新打开」触发真实 `onUpgrade`，seed 8 张表后逐表比对行数与关键字段；内容库测试以只读 URI 打开真实 `assets/seed/ielts_content_v1.db`。
- **A3 闭环（#16）**：**零 mock**，直接构造真实 `SubmitAnswerUseCase` + 真实内存 SQLite，验证跨表副作用链；并用 `DROP TABLE learning_statistics` 强制事务回滚，证明「无半行残留」。
- **A4 widget（#17）**：6 个 `testWidgets` 覆盖共享组件渲染/交互。

---

## 2. 已实际执行的验证（REAL EXECUTED — 含原始输出）

### V1. 内容库完整性（FR-006 / FR-090 / Q-1）

命令：`python .qa_scratch/verify_content.py`

```
== 1. Content DB file vs manifest SHA256 ==
  file sha256    : 98b871a9cd58ce4b5a27fcfd539c187bc5ecc8f606abf9f87fec32788bc78607
  manifest sha256: 98b871a9cd58ce4b5a27fcfd539c187bc5ecc8f606abf9f87fec32788bc78607
  MATCH          : True

== 2. Open read-only + integrity_check ==
  integrity_check: ok
  user_version   : 1
  foreign_key_chk: empty (ok)
  tables         : ['content_metadata','reading_options','reading_passages','reading_questions','sqlite_sequence','vocabulary','vocabulary_topics']

== 3. Row counts vs manifest ==
  vocabulary           = 300   (manifest 300 ✓)
  reading_passages     = 8     (manifest 8   ✓)
  reading_questions    = 80    (manifest 80  ✓)
  reading_options      = 96
  vocabulary_topics    = 462
  content_metadata     = 1

== 4. Reading question type distribution ==
  MC                     = 24
  SUMMARY_COMPLETION     = 24
  TFNG                   = 32

== 5. Write attempt must fail (read-only) ==
  write blocked    -> OK: attempt to write a readonly database
```

**结论：✅ PASS。** 文件哈希与 manifest `checksum` 一致；`integrity_check=ok`；300/8/80 与 Q-1 完全吻合；题型覆盖 FR-041 最小集（TFNG 32 / MC 24 / SUMMARY_COMPLETION 24）；只读约束在 SQLite 层真实生效。

### V2. 内容 schema 与流水线 schema 一致性（FR-006）

```
== kContentSchemaSql == content_pipeline/schema.sql ? ==
  dart stmt count    : 16
  pipeline stmt count: 16
  IDENTICAL          : True
```

**结论：✅ PASS。** 运行期 `schema_content.dart` 与内容构建流水线 `content_pipeline/schema.sql` **逐语句完全一致**（16/16），不存在「构建库与读取库结构漂移」风险。

### V3. 用户库 v1→v2 迁移真实执行（FR-083 / NFR-30）

命令：`python .qa_scratch/verify_migration.py`（DDL 逐字提取自 `schema_user.dart`，v2 步骤逐字提取自 `migrations.dart`，在真实 sqlite3 上执行）

```
== v1 statements parsed from schema_user.dart : 34
== v2 statements parsed from migrations.dart  : 3
     - ALTER TABLE user_profile ADD COLUMN font_scale REAL NOT NULL DEFAULT 1.0
     - ALTER TABLE user_profile ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'
     - CREATE INDEX IF NOT EXISTS idx_ua_user_correct ON user_answers(user_id, is_correct)

== BEFORE (v1) ==  15 tables, row counts: {users:1, user_profile:1, study_goal:1, daily_tasks:1,
                    vocabulary_reviews:1, skill_scores:1, user_answers:1, mistakes:1, learning_statistics:1, ...}
== APPLY v1 -> v2 ==
== AFTER (v2) ==   row counts identical to BEFORE

== ASSERTIONS ==
  tables preserved + counts unchanged : True
  profile  unchanged : True (7.5, 90) -> (7.5, 90)
  score    unchanged : True (62.0, 12) -> (62.0, 12)
  mistake  unchanged : True (3, 0.4) -> (3, 0.4)
  review   unchanged : True (2,) -> (2,)
  streak   unchanged : True (6,) -> (6,)
  font_scale/theme_mode present : True
  defaults applied to existing row : (1.0, 'system')
  idx_ua_user_correct present : True
  foreign_key_check : empty (ok)
  user_version      : 2
  append-only (no DROP/DELETE in DDL) : True

RESULT: PASS
```

**结论：✅ PASS。** v1→v2 升级后**用户数据零丢失**（15 表行数、关键字段全部不变），新列以安全默认值补齐，新索引创建成功，外键完好，DDL 全程无 `DROP/DELETE`（append-only 保证成立）。

### V4. 每日任务算法穷举扫描（FR-070/071）——发现缺陷

命令：`python .qa_scratch/sweep3.py`（2,923,000 组输入：dm 15–180 × 7 目标分 × 8 能力集 × 6 优先级集 × 6 弱项 × 11 剩余天数）

```
=== dm>=15 ===
sum != dailyMinutes  : 0          ← Σ分钟不变式：全部成立 ✅
any bucket < 5 min   : 809        ← 5 分钟下限：809 组违反 ❌

=== minimal repro dm=18 ===
  buildPlan(8.0, {vocab:90, reading:10}, 29, 18, {reading:5.0}, None)
    -> {'reading': 3, 'mistakes': 10, 'vocabulary': 5}   sum 18
```

命令：`python .qa_scratch/per_dm.py`

```
dm values (>=15) that can violate the 5-min floor: [18, 19, 24]
Are the onboarding values 30/60/90/120 affected? NO
```

**结论：⚠️ 发现 P2-1（见第 4 节）。** Σminutes 不变式 100% 成立；但**每日 5 分钟下限**在 `dailyMinutes ∈ {18,19,24}` 时会被破坏，共 809 组输入。根因定位见 P2-1。

### V5. DAO 列名交叉核对（防拼写错误）

命令：`python .qa_scratch/colcheck.py`（解析 `schema_user.dart` 全部 15 表列集合，扫描 `lib/**` 全部 snake_case 字符串字面量）

```
=== snake_case string literals NOT matching any schema column ===
  'app_settings' / 'content_metadata' / 'daily_tasks' / 'learning_sessions' /
  'learning_statistics' / 'skill_scores' / 'study_goal' / 'study_plan' /
  'user_answers' / 'user_profile' / 'vocabulary_reviews' / 'vocabulary_topics'
      → 全部为【表名】（DAO/仓库/SQL 中引用表，非列）
  'daily_target_minutes' / 'font_scale' / 'theme_mode' / 'notifications_enabled' /
  'sound_enabled' / 'local_user' / 'ielts_free'
      → 全部为【配置键/常量/包名】（非数据库列）
```

**结论：✅ PASS。** 未发现任何**拼写错误的列引用**；所有「未匹配」命中均可解释为表名或非 schema 常量。

### V6. 离线红线审计（BRIEF 强制验收项）

```
=== A. network imports in lib/ ===
  (none)                      ← 无 package:http / dio / grpc / HttpClient / Socket
=== B. Android INTERNET permission ===
  android/app/src/main/AndroidManifest.xml    → (no uses-permission)   ✅ 主清单无联网权限
  android/app/src/debug/AndroidManifest.xml   → INTERNET（仅调试构建）
  android/app/src/profile/AndroidManifest.xml → INTERNET（仅 profile 构建）
=== C. pubspec dependencies ===
  flutter_riverpod, go_router, sqflite, sqflite_common_ffi, path, path_provider,
  intl, collection, crypto, uuid, logging
  → 无 http / dio / firebase / google_fonts / 任何联网或云 SDK
```

**结论：✅ PASS（静态层）。** 源码与**发布用主清单**均无联网能力；INTERNET 仅存在于 debug/profile（开发期）。

### V7. 禁用模式扫描

```
=== D. print/TODO/FIXME/UnimplementedError in lib/ ===
  (none)                      ✅
=== E. hardcoded Color(0x outside theme.dart ===
  (none outside theme.dart)   ✅（硬编码色值仅集中在 lib/app/theme.dart，共 20 处）
```

**结论：✅ PASS。** 与 `analysis_options.yaml`（`avoid_print: error`、`unused_import: error`）要求一致。

### V8. Dart 测试文件结构自检

命令：`python .qa_scratch/dartcheck.py`

```
NO main() in test\helpers\fixtures.dart
NO main() in test\helpers\test_database.dart
checked 17 files; issues=2
```

**结论：✅ PASS。** 17 个测试文件的括号/引号配平全部通过；唯二无 `main()` 的是两个 helper 文件（符合预期，非测试入口）。

### V9. CI 配置评审

` .github/workflows/tests.yml`：`runs-on: ubuntu-latest` → `flutter pub get` → `dart format`(continue-on-error) → `flutter analyze` → `flutter test`。
**结论：⚠️ 见 P1-1（潜在 CI 失败风险，未能本地验证）。**

---

## 3. 未验证结论清单（UNVERIFIED — 需在具备 Flutter 环境处补验）

> 以下项目**本机无法执行**，因此**不作为通过结论**，请勿在验收时当作已验证。

| # | 未验证项 | 原因 | 补验方式 |
|---|---|---|---|
| U1 | `flutter analyze` 是否 0 error/warning | 无 Flutter/Dart SDK | CI 或本地 `flutter analyze` |
| U2 | 153 个用例是否全部通过 | 无 Flutter SDK，无法 `flutter test` | CI 或本地 `flutter test` |
| U3 | widget 测试（#17）与 integration 测试（#16）实际运行结果 | 同上 | 同上 |
| U4 | 算法测试的**精确数值断言**是否与实现完全吻合 | 仅 Python 复刻了 `daily_plan` 分配器；其余 7 算法为「按架构规格书写断言」 | `flutter test test/core/services/adaptive/` |
| U5 | `dart format` 格式合规 | 无 dart | CI（当前 continue-on-error） |
| U6 | CI 在 ubuntu-latest 上 `flutter test` 能否加载 `libsqlite3` | 无网络/无 CI 环境 | 见 P1-1 |
| U7 | Android/Windows 真机断网运行（BRIEF #111-1） | 无构建产物 | 构建后真机断网验收 |

**风险提示**：U4 中，`daily_plan` 之外 7 个算法的断言是基于 `docs/ARCHITECTURE-v0.1.md §5` 规格 + 源码阅读书写，**未经过 Dart 运行器验证**。若首次 `flutter test` 出现失败，请按第 5 节路由规则判断是「测试断言错（QA 修）」还是「实现错（Engineer 修）」。

---

## 4. 问题清单（Findings）

### P2-1 ｜每日任务分配器破坏「每项 ≥5 分钟」下限

- **严重级**：P2（低影响；**当前 UI 不可达**）
- **文件/行**：`lib/core/services/adaptive/daily_plan_service.dart`
  - 调用点 L150（`_fixSum(...)`）
  - 定义 L304–339
  - 关键缺陷行 **L327–331**（把低于下限的桶抬到 `minTaskMinutes`）与 **L336–337**（把盈余/亏空**再次全部**加到 `largest` 桶）
- **触发条件**：`dailyMinutes ∈ {18, 19, 24}`（非 5 的倍数且 <30）
- **复现（已真实执行）**：
  ```
  buildPlan(targetBand: 8.0, skillScores: {vocabulary:90, reading:10},
            daysRemaining: 29, dailyMinutes: 18,
            priorities: {reading:5.0}, weakest: null)
    → {reading: 3, mistakes: 10, vocabulary: 5}   // reading=3 < 5 ❌
  ```
  穷举扫描：809 组输入违反下限，涉及 dm ∈ {18,19,24}。
- **根因**：`_fixSum` 先做安全网抬升（L327–331 保证各桶 ≥5），但随后 L336–337 为凑齐 Σ 又把差额**全部加到 `largest` 桶**，可能把 `largest` 重新压回 <5；抬升与再平衡未做二次校验。
- **修复建议**（供 Engineer 参考，二选一）：
  1. 把最终再平衡改为「把差额分摊到**仍有余量**的桶」并在每次调整后重新校验下限；
  2. 或在 L336 的最终调整后**再次执行** L327–331 的抬升并迭代直到收敛（有界循环）。
- **可达性判定**：`study_plan_generator.dart:87` 传入 `goal.dailyStudyMinutes`，而该值仅来自 Onboarding（`step_daily_minutes.dart:13 = [30,60,90,120]`）与设置（`settings_controller.dart:107 = [30,60,90,120]`）。**{18,19,24} 无法经正常 UI 产生**，故定级 P2。
- **路由**：**Engineer（Alex）** —— 测试断言（Σ=dm 且每项 ≥5）符合架构不变量，实现未满足 → 源码缺陷。

### P1-1 ｜CI（ubuntu-latest）可能因缺少 libsqlite3 导致数据层/集成测试失败

- **严重级**：P1（CI 红；未本地验证）
- **文件/行**：`.github/workflows/tests.yml` L13（`runs-on: ubuntu-latest`）、L27–28（`flutter pub get`）、L37–38（`flutter test`）
- **现象推断**：本次交付的数据层与集成测试通过 `sqflite_common_ffi` 加载 `libsqlite3.so`。GitHub `ubuntu-latest` 镜像默认**不保证**存在 `libsqlite3-dev`（提供 `.so` 软链），`flutter test` 可能报 `Failed to load dynamic library 'libsqlite3.so'`。
- **依据**：源码 `test/helpers/test_database.dart` 显式使用 `ffi.databaseFactoryFfi`；pubspec 依赖 `sqflite_common_ffi: ^2.3.3`。
- **修复建议**：在 L27 前插入
  ```yaml
  - name: Install SQLite dev libs
    run: sudo apt-get update && sudo apt-get install -y libsqlite3-dev
  ```
  （Android/iOS 走原生 sqflite 不受影响；此步仅为桌面/CI 测试服务。）
- **路由**：**Engineer（Alex）** —— CI 配置缺陷。**注意：本条为推断，需在真实 CI 运行确认后关闭。**

### 观察项（非缺陷）

- **O-1**：`test/smoke_test.dart` 为骨架期既有文件，与本次 T05 全套件并存，无冲突。
- **O-2**：`pubspec.yaml` 含 `mocktail`，但本次所有关键路径测试**均未使用 mock**（真实 SQLite + 真实 use case），符合「闭环必须真跑」要求。
- **O-3**：`analysis_options.yaml` 开启 `strict-casts/inference/raw-types` 且把 `avoid_print/unused_import/unused_local_variable` 设为 error —— 有利于数据层正确性，但也意味着任何一处小瑕疵都会让 `flutter analyze` 失败（需 U1 验证）。

---

## 5. 智能路由决策（Smart Routing）

| 编号 | 问题 | 判定依据 | 路由 |
|---|---|---|---|
| P2-1 | daily_plan `_fixSum` 5 分钟下限被破坏 | 断言符合架构不变量，实现未满足 | **→ Engineer（Alex）** |
| P1-1 | CI 缺 libsqlite3-dev 风险 | 环境/配置缺陷 | **→ Engineer（Alex）**（待 CI 复现确认） |
| U1–U7 | 需 Flutter 环境才能运行的项 | 环境受限，非代码缺陷 | **→ QA（本机无法补验）**，移交 CI/本地补验 |

**无 P0 缺陷。** 所有已执行验证中，除 P2-1 外全部 PASS。

---

## 6. BRIEF #111 最终验收映射

| BRIEF #111 验收项 | 对应测试资产 | 当前状态 |
|---|---|---|
| 1. **断网测试**：启动/首页/词汇/阅读/听力/写作/口语/错题/统计/计划 | V6 离线审计（源码+主清单无联网）✅；真机断网运行 = **U7 未验证** | ⚠️ 静态通过，运行时待验 |
| 2. **数据测试**：重开后学习记录/错题/词汇记忆/收藏/笔记/计划仍在 | `learning_loop_test.dart`（写路径+持久化）✅（U2 待跑）；`migration_test.dart` ✅ | ⚠️ 代码就绪，待 `flutter test` |
| 3. **更新测试**：旧版→新版用户数据不丢失 | V3 迁移真实执行 **PASS**；`migration_test.dart` | ✅ 已实证（Python） |
| 4. **发布测试**：Release 含 APK/Windows/Source/Checksum/README/Notes | 不在本次 QA 范围（属构建/发布） | ➖ 非 QA 项 |

**P0 功能覆盖（FR-001~FR-092）**：算法 FR-060/062/063/064、词汇 FR-033/034/035、错题 FR-050~053、每日任务 FR-070~073、迁移 FR-083、内容 FR-006/090、判分 FR-032/041/044 均已有测试用例覆盖（见 §1.2）。FR-080（崩溃恢复自动保存）**仅经代码评审**（`session_autosave_service.dart` 设计合理），**未写自动化测试**（依赖 Flutter 定时器/生命周期，需 widget 或真机验证）。

---

## 7. 闭环是否成立？（FR-064 核心结论）

**测试层面：闭环成立。**
`test/integration/learning_loop_test.dart` 用真实 `SubmitAnswerUseCase` + 真实内存 SQLite（**零 mock**）串起了完整链路：

```
答题(错) → user_answers 落库 → mistakes 分类入库(wrong_count 累加) →
skill_scores 变化(脱离 40.0 回退值, sample_count=3) →
daily_tasks 进度推进 + payload.priority 出现且 >1.0 →
重新 buildPlan 后词汇桶 priority 与上一次【可观测地不同】 →
答对重做 → mastery 上升(>0) → statistics 计数(4/1)
```
并额外验证：重复错答只增 `wrong_count` 不重复建错题；`DROP TABLE` 强制失败时事务**整体回滚**（无半行残留）。

**该闭环的运行时通过与否，取决于 U2（`flutter test` 尚未执行）。** 代码逻辑与断言已就绪，结论待运行器确认。

---

## 8. 交付物清单

| 类型 | 路径 |
|---|---|
| 测试代码（17 文件 / 153 用例） | `ielts_free/test/**`、`ielts_free/test/integration/**` |
| 本报告 | `ielts_free/docs/TEST-REPORT-v0.1.md` |
| 验证脚本（可复现，无需 Flutter 工具链） | `ielts_free/tool/verify/*.py`（含 `README.md` 说明用法） |

## 9. 给团队的一句话总结

**已用真实工具证明**：内容库 300/8/80 且哈希吻合、v1→v2 迁移零丢数据、离线红线干净、禁用模式干净、schema 双源一致。
**发现 1 个 P2 缺陷（daily_plan 5 分钟下限，UI 不可达）与 1 个 P1 CI 风险（libsqlite3）**，均路由 Engineer。
**153 个用例已就绪但受环境所限未运行**——`flutter analyze`/`flutter test` 的最终绿灯需在具备 Flutter 的环境补验（U1–U5）。

---

## 附录：缺陷修复与复验（由主理人于交付前追加）

本报告提出的两个问题已在交付前修复，并由主理人独立复验。

### P2-1 —— `_fixSum` 破坏「每项 ≥5 分钟」下限

**修复**：`lib/core/services/adaptive/daily_plan_service.dart` 重写 `_fixSum`（新增 `_bucketCount` / `_sumOf` / `_largestBucket` 辅助）。
新算法：① 显式抬高下限；② 若总和超出，贪心地从「分钟数最多**且扣减后仍 ≥5**」的桶扣减，`take = min(excess, reducible)`，保证永不越过目标值、也不跌破下限；③ 若总和不足，差额加到最大桶。
前置条件 `桶数 × 5 ≤ target` 由 `_bucketCount` 保证，使循环必然终止于 `sum == target`。

**主理人独立复验**（`tool/verify/verify_daily_plan_floor.py`，1:1 移植新算法 + 对照旧算法）：

```
cases evaluated            : 2,167,448
NEW algorithm violations   : 0
OLD algorithm violations   : 204,516

examples of OLD failures (sum was still correct, floor was broken):
  target= 10 in={'vocabulary': 6, 'reading': 6} -> {'vocabulary': 4, 'reading': 6}
  target= 10 in={'vocabulary': 6, 'reading': 7} -> {'vocabulary': 6, 'reading': 4}

RESULT: PASS - new algorithm upholds both invariants
```

→ **不变量 1（Σ == target）与不变量 2（每项 ≥ min）在 216 万组输入上 100% 成立**；旧算法在同样输入上有 20.4 万组违规，证明该检查确实能捕获此类缺陷。

**回归测试**：`test/core/services/adaptive/daily_plan_service_test.dart` 已固化 QA 报告的原始复现输入，并新增 `dailyMinutes ∈ {18,19,24}` 循环断言。

**已知取舍**：当 `dailyMinutes` 不是 5 的倍数（如 18）时，「所有值都是 5 的倍数」与「精确求和」数学上不可兼得，按设计**优先保证两条不变量**。Onboarding 与设置页的预设预算（30/60/90/120）均为 5 的倍数，不受影响。

### P1-1 —— CI 缺少 `libsqlite3-dev`

**修复**：在 `.github/workflows/tests.yml` 与 `.github/workflows/release.yml` 中、`flutter pub get` 之前插入
`sudo apt-get update && sudo apt-get install -y libsqlite3-dev`。

**复验**：`grep -rln "flutter test"` 与 `grep -rln "libsqlite3-dev"` 的**文件集合完全一致**（均为 `tests.yml` + `release.yml`），无遗漏。
`android.yml` / `windows.yml` 只做构建不跑测试，无需改动。

### 复验后仍未解除的未验证项

U1 `flutter analyze`、U2 153 个用例实跑、U3 widget/integration 实跑、U4 算法精确数值断言、U5 `dart format`、U6 CI 实跑、U7 真机断网运行 —— **均需具备 Flutter 工具链的环境**。
以上修复的结论同样**不构成编译通过证明**。

---

## 附录二：静态分析实跑结果（主理人补录，交付前）

附录一列出的 **U1（`flutter analyze` 未执行）已解除**。

构建环境无法派生子进程（`CreateFile failed 231 - 所有管道范例都在使用中`），导致 `flutter analyze` / `dart analyze` 均不可用。改用 `tool/analyze/`（`package:analyzer` 的 `AnalysisContextCollection`，**进程内运行、不派生子进程**）执行等价的类型检查。

### 首次运行：发现 75 个真实编译错误

这是本报告最重要的发现 —— **在无编译器环境下，源码中存在 75 个编译错误而未被察觉**。

| 类别 | 数量 | 根因 |
| --- | --- | --- |
| `TextTheme.caption` / `.label` / `.headline` 不存在 | 52 处 / 24 文件 | Material 3 移除了 `caption`；`label`、`headline` 从来不是 `TextTheme` 的成员 |
| `DatabaseException` 与 sqflite 同名冲突 | 2 | 项目自定义异常类与 sqflite 导出名冲突，调用点无法解析 |
| `difficultyWindow` 局部变量自引用 | 1 | 局部变量遮蔽同名类字段后，在自身初始化式中引用自己 |
| 测试相对 import 路径少一层 | 3 文件 | `test/core/database/` 下误写 `../helpers/`，应为 `../../helpers/` |
| `library` 指令位于 import 之后 | 1 | 语法错误 |
| 未使用的 import / 未引用的私有构造 | 10+ | 警告级 |

### 修复后结果

```
Analyzing: D:\workbuddyai\ielts_free
Files analyzed : 197
Errors         : 0
Warnings       : 0
Infos          : 2
RESULT: NO ERRORS
```

**197 个文件（lib 179 + test 17 + 工具 1）全部通过类型检查，0 error / 0 warning。**

### 仍未验证

`flutter test` 依然无法在本环境执行 —— 测试运行器必须派生子进程。153 个用例的**运行时**绿灯仍需在具备正常子进程能力的环境中补验（用户本机 PowerShell，或 CI）。

**U1 已解除**：源码在类型层面已确认正确，不再存在编译错误。

---

## 附录三：`flutter test` 首次真实运行结果（2026-10-02）

### 环境前置问题的解决

本报告附录一/二提到的环境限制已被逐一解决，`flutter test` 最终**真实跑通**：

| 障碍 | 解决方案 |
| --- | --- |
| 机器无 Flutter | 装 Flutter 3.47.5 stable + Dart 3.13.4 到 `D:\flutter`（走 `storage.flutter-io.cn` 镜像） |
| 机器无 Git（Flutter 依赖它读 engine 版本） | 装 Git 2.55 到 `D:\Git` |
| `flutter pub get` 崩在 `_preloadPubCache` | 删除 `$FLUTTER_ROOT/.pub-preload-cache` |
| `package:sqlite3` 从 GitHub 下载原生库超时（架构 R2） | 在 `pubspec.yaml` 用 `hooks.user_defines.sqlite3.url_pattern` 换到镜像，**sha256 校验仍生效** |

### 首次运行结果

```
+150 -4: Some tests failed.
```

**153 个用例：150 通过 / 4 失败**（含 setUpAll/tearDownAll 计数为 154）。

### 4 处失败的根因与修复（全部为测试代码自身问题）

| # | 文件 | 根因 | 定性 |
| --- | --- | --- | --- |
| 1 | `test/core/database/content_database_test.dart` | 使用相对路径打开 DB；`sqflite_common_ffi` 会将其解析到 `.dart_tool/sqflite_common_ffi/databases/` 下 | 测试缺陷 |
| 2 | 同上（`tearDownAll`） | `late Database db` 在 setUpAll 失败后未初始化，产生误导性二次报错 | 测试缺陷 |
| 3 | `test/core/services/adaptive/streak_service_test.dart` | 基准 `DateTime.utc(2026,6,15,12)` 在 **UTC+8** 下为当地 20:00，`+6h` **跨过午夜**变成次日，streak 由 1 变 2 | 测试缺陷（时区依赖） |
| 4 | `test/core/services/grading_service_test.dart` | 例子 `mitigate`→`mitgitate` 是**字母对调**，标准 Levenshtein 距离为 **2**，超出容错阈值 1 | 测试缺陷（例子选取） |

**第 4 条特别说明**：判错是**符合规格的正确行为**。ARCHITECTURE §5 明确写「拼写题用编辑距离容错 1 个字符」，即标准 Levenshtein；字母对调在雅思拼写中确实是错误。因此修复方向是**把边界固化为正式用例**（对调必须判错），而非放宽算法。

### 修复内容

1. **`content_database_test.dart`** —— `dbPath`/`manifestPath` 改用 `p.absolute(...)` 绝对路径；`late Database db` → `Database? db`，`tearDownAll` 改 `await db?.close()`，避免级联失败。
2. **`streak_service_test.dart`** —— 该用例改用**本地时间**基准 `DateTime(2026, 6, 15, 9)`，`+6h` = 当地 15:00，任何时区与 DST 下均不跨天。
3. **`grading_service_test.dart`** —— 用例 ④ 重写为四个边界：单字符**插入** `mitigatte`、**替换** `mitigete`、**删除** `mitigat` 三者应判对且 `MatchKind.fuzzy`；**对调** `mitgitate` 应判错且 `MatchKind.incorrect`。

### 修复后的脚本级真实验证

```
levenshtein(mitigate, mitigatte) = 1  ->  isCorrect=true  matchKind=fuzzy
levenshtein(mitigate, mitigete)  = 1  ->  isCorrect=true  matchKind=fuzzy
levenshtein(mitigate, mitigat)   = 1  ->  isCorrect=true  matchKind=fuzzy
levenshtein(mitigate, mitgitate) = 2  ->  isCorrect=false matchKind=incorrect

base (local)    = 2026-06-15 09:00:00.000
base+6h (local) = 2026-06-15 15:00:00.000
second -> streak=1 date=2026-06-15 changed=false    ASSERT changed==false ? true
```

静态检查（进程内分析器，QA 沙箱跑不了 `dart analyze`，由主理人补做）：

```
Files analyzed : 197
Errors         : 0
Warnings       : 0
```

### 修复后的复跑结果 —— **全部通过**

```powershell
cd D:\workbuddyai\ielts_free; flutter test
```

```
00:05 +159: All tests passed!
```

**`All tests passed!`** —— 159 项全部通过，0 失败。

（计数 159 > 原始 153，因为修复过程中把用例 ④ 从 1 条拆成了 4 条边界断言，并计入 `setUpAll` / `tearDownAll` 回调。）

至此，附录一列出的 **U2（153 个用例实跑）已解除**：测试套件在真实 `flutter test` 下全绿。

### 四项验收状态（BRIEF 第一百一十一条）

| 验收项 | 状态 | 证据 |
| --- | --- | --- |
| 1. 断网测试 | ⚠️ 静态通过，真机待验 | 主 manifest 无 `INTERNET`；`lib/` 无任何联网 import；pubspec 无联网依赖。真机飞行模式验收需在设备上执行 |
| 2. 数据测试 | ✅ 通过 | `flutter test` 全绿，含 `migration_test`（v1→v2 不丢数据）、`content_database_test`（只读打开 + 写入被拒 + 计数）、`learning_loop_test`（闭环） |
| 3. 更新测试 | ✅ 通过 | `migration_test` 实测 15 表 / 行数 / 字段值零丢失，`user_version` 正确，DDL 无 `DROP`/`DELETE` |
| 4. 发布测试 | ⏸ 未执行 | 需产出 APK / Windows 包，依赖 Android SDK 与 Visual Studio，本次未安装 |

### 仍未闭环的项

- **U1 `flutter analyze`**：源码已用等价的进程内分析器验证为 0 error / 0 warning，但官方命令未在项目目录跑过。建议补跑一次。
- **U7 真机断网运行**：需在 Android 设备或 Windows 桌面上实际断网验收。`flutter run -d windows` 还需要 Visual Studio C++ 工具链，`flutter build apk` 还需要 JDK + Android SDK。
- **U6 CI 实跑**：`.github/workflows/*.yml` 已就绪，需推送到 GitHub 后由 Actions 验证。

---

## 附录四：路径迁移与官方工具链最终验证（2026-10-02）

### 重大发现：Dart 分析服务器在含非 ASCII 字符的项目路径下必然崩溃

`flutter analyze` 在 `D:\雅思\workbuddyai\ielts_free` 下反复崩溃：

```
Analyzing ielts_free...
analysis server exited with code 255 and output:
[stderr] #7  LspByteStreamServerChannel.listen.<anonymous closure> ...
```

**对照实验（决定性）** —— 两个**代码完全相同**的最小 Flutter 项目（`pubspec.yaml` + 10 行 `lib/main.dart`），只有路径不同：

| 路径 | 结果 |
| --- | --- |
| `D:\analyze_probe_ascii`（纯 ASCII） | ✅ `No issues found! (ran in 5.9s)` |
| `D:\雅思\analyze_probe_cn`（含中文） | ❌ `analysis server exited with code 255` |

**结论：这是 Dart 分析服务器的真实缺陷 —— 项目路径含非 ASCII 字符时崩溃。与被测代码无关。**
`flutter test` 不受影响，只有 `flutter analyze` 与 IDE 分析会中招。

**处置**：项目迁移至纯 ASCII 路径 **`D:\workbuddyai\ielts_free`**（同盘符 `mv`，瞬时完成）；
删除 `build/` 与 `.dart_tool/` 后重跑 `pub get`（二者均含绝对路径）；更新文档中的旧路径引用；
README 新增小节「If `flutter analyze` exits with code 255」记录成因与修法。

### 官方工具链最终结果

```
flutter analyze  →  28 issues found. (ran in 6.2s)   ← 全部 info 级，0 error / 0 warning
flutter test     →  All tests passed!                ← 159 项全绿
```

### lint 清零 —— 已确认

28 条 `info` 已全部清理，**用户复跑确认**：

```
Analyzing ielts_free...
No issues found! (ran in 5.9s)
```

| 规则 | 条数 | 处理 |
| --- | --- | --- |
| `prefer_const_constructors` | 17 | 给构造调用加 `const` |
| `prefer_const_declarations` | 7 | `final` → `const` |
| `unnecessary_import` | 2 | 删除多余 import |
| `prefer_function_declarations_over_variables` | 2 | 闭包赋值改写为局部函数声明 |

约束：只做风格清理，**不改变任何运行时行为**，**不使用 `// ignore:` 压制**（已确认 0 处）。

清理后进程内分析器复核：**196 文件 / 0 errors / 0 warnings / 0 infos**。

### 方法论修正（重要）

进程内分析器（`AnalysisContextCollection`）能**可靠捕获 error / warning**（它曾准确找出 75 个编译错误），
但 **lint 规则覆盖不全** —— 官方 `flutter analyze` 多报出 26 条 `prefer_const_*` 类 lint。

**因此：它可作为「类型检查」的替代，但不可作为「lint 清洁度」的替代。**
此前报告中「0 errors / 0 warnings」的表述依然准确，但不应据此断言「0 issues」。

### 最终验收状态

**官方工具链双双全绿：**

```
flutter analyze  →  No issues found! (ran in 5.9s)
flutter test     →  All tests passed!          (159 项)
```

| 验收项 | 状态 |
| --- | --- |
| 1. 断网测试 | ⚠️ 静态通过（manifest 无 `INTERNET`、无联网 import、无联网依赖），真机待验 |
| 2. 数据测试 | ✅ **通过**（`flutter test` 全绿） |
| 3. 更新测试 | ✅ **通过**（`migration_test` 实测不丢数据） |
| 4. 发布测试 | ⏸ 未执行（需 Android SDK + Visual Studio） |

> 附录一列出的未验证项 U1（`flutter analyze`）与 U2（测试实跑）**均已解除**。
> 剩余 U6（CI 实跑）与 U7（真机断网）属用户侧环境依赖，非代码问题。
