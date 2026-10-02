# IELTS Free —— V0.1 MVP 产品需求文档（PRD）

> 文档版本：v0.1（MVP 范围）
> 事实来源：`docs/BRIEF.md`（唯一事实来源）。本文档与 BRIEF 冲突时以 BRIEF 为准。
> 撰写人：产品经理 许清楚
> 范围声明：**V0.1 MVP 只做闭环验证**，严格对齐 BRIEF 第九十四条。听力 / 写作 / 口语属 P1，仅列入需求池并标注 V0.2，**本文档不为它们设计页面**。

---

## 0. 项目信息

| 项 | 值 |
| --- | --- |
| 项目名称 | IELTS Free（Free Offline IELTS Learning App） |
| 项目代号 | `ielts_free` |
| 语言 | 简体中文（技术标识符 / 字段名 / 代码用英文） |
| 技术栈（优先） | Flutter + Dart；Riverpod；go_router；Drift + SQLite；just_audio；Material 3；成熟图表库（BRIEF 第七条） |
| V0.1 交付平台 | Android（`IELTS-Free-Android.apk`）+ Windows（`IELTS-Free-Windows.zip`） |
| 环境约束 | 构建机无 Flutter/Android SDK/VS 工具链，本次交付**完整可构建源码 + GitHub Actions CI**，不本地打包 |
| 核心理念 | AI + Agent 负责开发阶段生产内容；App 负责本地交付和自适应学习 |

### 原始需求复述（V0.1）

用户下载安装后**完全断网**也能使用全部核心学习功能：本地 SQLite 内容库（只读）+ 本地用户库（读写）+ 本地自适应算法。不接服务器、不接实时 AI、不接广告、无付费墙。V0.1 必须实现 **Dashboard / Vocabulary / Reading / Mistakes / Adaptive Engine**，并最先证明这条闭环：

```
学习 → 答题 → 错误 → 错题 → 能力更新 → 下一次训练变化
```

---

## 1. 产品目标

### 1.1 一句话目标

> **证明「纯离线 + 本地自适应」的完整学习闭环在真实设备上可跑通、可留存、可复用**——用户装完 App、断网，也能「打开就知道今天学什么」，做完题后系统自动收错题、更新能力、并让下一次训练发生变化。

### 1.2 成功标准（可验证）

| 编号 | 成功标准 | 验证方式 | 对应 BRIEF |
| --- | --- | --- | --- |
| G-1 | 完全断网（飞行模式）下，Onboarding→Dashboard→Vocabulary→Reading→Mistakes→Study Plan 全部可打开、可操作、无崩溃 | 手动断网测试 + E2E 自动化 | 第六十三 / 六十四条、一百一十一条 |
| G-2 | 完成 1 次完整闭环：做题→提交→记录→自动生成错题→能力分数变化→下一次每日任务内容变化 | Integration Test + 手动演示 | 第七十七 / 七十八条、九十四条 |
| G-3 | 关闭 App 重开后，学习记录 / 错题 / 词汇记忆等级 / 能力分数 / 每日任务 全部仍在 | E2E 测试 | 第七十九条、一百一十一条 |
| G-4 | 词汇记忆等级算法、能力评分、难度自适应、训练优先级、每日任务算法均有 Unit Test 通过 | `flutter test` | 第七十六条 |
| G-5 | 数据库可从 DB v1 升级到 DB v2 且**不丢用户数据** | Migration 测试 | 第七十一~七十五条 |
| G-6 | 首次启动冷启动 ≤ 3 秒（中端机），首页不在启动时一次性加载整库 | 手动 + 性能打点 | 第六十二条、九十九 / 一百条 |

---

## 2. 目标用户与核心场景

### 2.1 用户画像

- **主用户**：备考雅思的学生 / 在职备考者，网络不稳定或想省钱，希望「免费、离线、长期可用」。
- **次用户**：通勤 / 无网环境（地铁、飞机、校园网限制）下的碎片化学习者。

### 2.2 用户故事

| 编号 | 用户故事 |
| --- | --- |
| US-1 | As a 首次安装的用户，I want 在 5 步内完成设置并看到「今天学什么」，so that 我不用纠结怎么开始，装完就能学。 |
| US-2 | As a 断网通勤的用户，I want 在无网络下完成词汇复习和阅读练习，so that 我的碎片时间也能被利用、不被网络限制。 |
| US-3 | As a 备考用户，I want 做错题后系统自动收集并按错误类型分类，so that 我能清楚看到自己薄弱点并针对性训练。 |
| US-4 | As a 长期使用者，I want 系统根据我的正确率和错题自动调整下次训练难度与任务量，so that 我不用自己规划也能持续进步。 |
| US-5 | As a 注重隐私的用户，I want 所有数据只存在本地、且能一键导出或删除，so that 我不用担心隐私与数据丢失。 |

### 2.3 核心场景（主流程）

```
首次启动 → Onboarding 五步 → 生成学习画像(五维初始分)
  → Dashboard「今天应该学什么」→ 点「今日任务」开始
  → 词汇学习(卡片) → 词汇练习(7 类之一) → 提交
  → 阅读做题 → 提交 → 自动判分 + 解析
  → 错题自动入库(Mistakes) → 能力分数更新 → 训练优先级更新
  → 回到 Dashboard → 今日任务清单已变化 → 关闭 App → 重开 → 数据仍在
```

---

## 3. 需求池（Requirements Pool）

优先级定义：**P0 = Must have（V0.1 必须）**、**P1 = Should have（V0.2）**、**P2 = Nice to have（V0.3+）**。

### 3.1 P0 —— V0.1 必须实现

#### A. 工程脚手架与基础设施

| 编号 | 模块 | 需求 | 验收标准 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-001 | 工程 | Flutter 工程骨架 + 目录结构（`app/core/features/shared`） | 工程可按 BRIEF 第八条目录结构组织；`flutter run` 能启动空壳 | 八 |
| FR-002 | 工程 | 主题与 Design Tokens（Primary/Secondary/Background/Surface/Text/Muted/Success/Warning/Error） | 所有颜色/字号走 token，页面不得写死颜色 | 八十~八十一 |
| FR-003 | 工程 | 路由（go_router）+ 状态管理（Riverpod）接入 | 路由可跳转；核心状态由 Riverpod Provider 管理 | 七 |
| FR-004 | 工程 | GitHub Actions CI：`tests.yml`（+ android/windows build 骨架） | push 触发 `flutter analyze` + `flutter test`，产出可下载 artifact（build 可先占位） | 一百零三 |
| FR-005 | 数据库 | Drift + SQLite 本地库初始化 | 首次启动可建库；DB 版本号可读取 | 九、六十二 |
| FR-006 | 数据库 | **内容库（只读）+ 用户库（读写）分离** | 两个独立 DB 文件；内容库以只读方式打开；用户库可写 | 四十五 |

#### B. Onboarding 与用户模型

| 编号 | 模块 | 需求 | 验收标准 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-010 | Onboarding | 首次启动进入 5 步引导（目标分数 / 考试时间 / 每日时长 / 最弱项 / 初始测试） | 5 步可前进后退；完成前不进入主界面；不强制联网 | 十一、十二 |
| FR-011 | Onboarding | 游客模式：默认建立 `Local User`（`local_user`, targetBand 7.0, examDate null, dailyStudyMinutes 60） | 无账号即可使用；用户档案落库 | 十一 |
| FR-012 | Onboarding | 初始能力测试 → 生成五维初始分（Vocabulary/Reading/Listening/Writing/Speaking 0~100） | 测试完成后写入 `skill_scores`；Dashboard 可见五维分数 | 十二、三十 |
| FR-013 | 用户模型 | 目标分数 / 考试日期 / 每日学习时长可编辑（Onboarding 后可改） | 设置修改后 Dashboard 与每日任务随之更新 | 十一、四十二 |

#### C. Dashboard（首页）

| 编号 | 模块 | 需求 | 验收标准 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-020 | Dashboard | 首页信息结构：目标分数 / 考试倒计时 / 今日进度条 / 今日任务清单 / 五维能力 / 连续学习天数 / 今日学习时长 | 七项全部展示；数据来自本地库实时聚合 | 五 |
| FR-021 | Dashboard | 今日任务清单可点击进入对应训练 | 点击词汇任务→词汇练习；点击阅读任务→阅读 | 五、三十四 |
| FR-022 | Dashboard | 今日进度条随完成任务实时更新 | 完成一项任务后进度条增长 | 五 |
| FR-023 | Dashboard | 首页懒加载：不在启动时一次性加载整库 | 首屏查询走索引 + 分页，冷启动达标 | 九十九、一百 |

#### D. Vocabulary（词汇系统）

| 编号 | 模块 | 需求 | 验收标准 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-030 | 词汇 | 词汇详情展示：word / 音标 / 词性 / 中文释义 / 英文释义 / 常见搭配 / IELTS Writing 用法 / IELTS Speaking 用法 / 例句 | 字段完整；缺失字段优雅降级不报错 | 十三、十四 |
| FR-031 | 词汇 | 词汇操作：🔊发音 / ⭐收藏 / ✓掌握 / ✗不认识 | 四类操作可用；状态写入用户库 | 十四 |
| FR-032 | 词汇 | 7 种练习类型：①单词→中文 ②中文→单词 ③四选一 ④单词拼写 ⑤例句填空 ⑥同义词选择 ⑦搭配选择 | 7 种题型均可作答并判分 | 十六 |
| FR-033 | 词汇 | 词汇记忆等级算法（L0~L6）：保存 memoryLevel/correctCount/wrongCount/streak/lastReviewedAt/nextReviewAt | 答对 Level+1，答错 Level-1；连续错误提高复习优先级 | 十五 |
| FR-034 | 词汇 | 复习间隔：L0→当天 / L1→1天 / L2→3天 / L3→7天 / L4→14天 / L5→30天 / L6→60天 | `nextReviewAt` 按等级正确计算；到期词进入复习队列 | 十五 |
| FR-035 | 词汇 | 词汇闭环：学习→练习→测试→记忆等级→复习计划 | 学完词后等级/复习时间被更新，下次复习队列可见 | 十六 |

#### E. Reading（阅读系统）

| 编号 | 模块 | 需求 | 验收标准 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-040 | 阅读 | 阅读文章字段：title/topic/difficulty/band/readingTime/passage/questions/answers/explanations/skills | 字段可读取并渲染 | 十七 |
| FR-041 | 阅读 | 题型支持：T/F/NG、Y/N/NG、Multiple Choice、Matching Headings、Matching Information、Sentence/Summary/Table/Note Completion | 至少覆盖 T/F/NG、Multiple Choice、Summary Completion 三类（V0.1 最小集），其余在内容就绪时可用 | 十七 |
| FR-042 | 阅读 | 阅读做题页布局：桌面左文章右题目；手机文章↓题目；保留题号、进度、剩余时间 | 桌面 55%/45% 分栏；移动上下堆叠 | 十八、八十三 |
| FR-043 | 阅读 | 每题解析字段：correctAnswer/evidence/keywords/synonyms/logic/explanation（含同义替换说明） | 提交后可逐题查看解析 | 十九 |
| FR-044 | 阅读 | 提交后自动判分并记录 `user_answers` | 正确率计算正确；答错自动进错题 | 二十八、七十七 |

#### F. Mistakes（错题系统）

| 编号 | 模块 | 需求 | 验收标准 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-050 | 错题 | 所有做错题自动加入 Mistakes，字段：questionId/questionType/skill/userAnswer/correctAnswer/errorType/difficulty/wrongCount/lastWrongAt/mastery | 答错即入库；重复答错 wrongCount 累加 | 二十八 |
| FR-051 | 错题 | 错误分类 Taxonomy：Vocabulary（Word Meaning/Synonym/Collocation/Spelling）、Reading（定位/同义替换/主旨/细节/推断/逻辑/题型） | 每条错题带 errorType；可按类型筛选 | 二十九 |
| FR-052 | 错题 | 错题列表 + 详情 + 按类型/科目筛选 | 列表可分页；详情展示用户答案 vs 正确答案与解析 | 二十八、二十九 |
| FR-053 | 错题 | 错题重做，答对提升 mastery | 重做后 mastery 更新；掌握后可从错题队列淡出 | 二十八 |

#### G. Adaptive Engine（自适应引擎，核心）

| 编号 | 模块 | 需求 | 验收标准 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-060 | 自适应 | 能力评分：`Skill Score = Correctness × Difficulty Factor × Consistency Factor × Recency Factor`，归一化 0~100 | Unit Test 覆盖；分数随答题变化 | 三十一 |
| FR-061 | 自适应 | UserSkillProfile 五维分数（V/R/L/W/S）；阅读再细分 T/F/NG、Matching Headings、Multiple Choice、Summary、Detail、Inference | 五维可读可写；阅读子维度可记录 | 三十 |
| FR-062 | 自适应 | 训练优先级：`Priority = Error Frequency × Skill Importance × Recency × Difficulty` | 最近连续错的题型 Priority 上升 | 三十二 |
| FR-063 | 自适应 | 难度自适应：连续 3 次正确率 >85% → 难度+1；正确率 <60% → 难度-1；某知识点连续错 3 次 → 进入专项训练 | Unit Test 覆盖三种触发 | 三十三 |
| FR-064 | 自适应 | **闭环证明**：答题结果 → 更新能力/优先级 → 影响下一次每日任务内容 | Integration Test：同一用户两次任务清单可观测到差异 | 九十四 |

#### H. Daily Plan 与 Study Plan（每日任务 / 学习计划）

| 编号 | 模块 | 需求 | 验收标准 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-070 | 每日任务 | 每日任务算法：输入 目标分数/当前能力/剩余天数/每日学习时间/最近错误/历史训练量 → 输出各科分钟数 | 弱科权重提高；任务含具体项与预计时长 | 三十四 |
| FR-071 | 每日任务 | 今日任务清单生成 + 完成状态记录 | 完成任务后状态持久化；Dashboard 进度联动 | 三十四、五 |
| FR-072 | 学习计划 | 提供 7/30/60/90 Day 与 Custom 计划 | 可创建/选择计划；每日按算法重新调整（非完全固定） | 三十六 |
| FR-073 | 学习计划 | 倒计时策略：>90 天→基础/词汇/知识点；30~90 天→专项；<30 天→综合/模拟/错题 | 计划阶段随剩余天数自动切换 | 三十五 |

#### I. 数据持久化 / 导出 / 迁移

| 编号 | 模块 | 需求 | 验收标准 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-080 | 持久化 | 崩溃恢复 + 自动保存（debounce + session checkpoint）：答案/进度/计时/词汇状态/错题 | 中途强杀后重开，进度不丢或仅丢最后一题 | 七十九 |
| FR-081 | 持久化 | 所有用户数据落 SQLite（非 LocalStorage） | 设置/进度/错题/词汇等级/统计/任务/能力分数均在库中 | 十 |
| FR-082 | 导出 | Export Data → `IELTS-Free-Backup.json`（学习进度/错题/收藏/笔记/词汇记忆状态/能力分数/计划） | 导出文件结构完整、可读、含版本号 | 四十三、四十四 |
| FR-083 | 迁移 | 数据库 Migration（DB v1→v2）不删用户数据 | Migration 测试通过；升级后数据完整 | 七十一~七十五 |
| FR-084 | 启动 | 首次启动初始化：建库 → 导入 Content DB → 建索引 → 建用户档案，并显示进度 | 启动有进度提示；后续启动直接读本地库 | 六十二 |

#### J. 内容与合规

| 编号 | 模块 | 需求 | 验收标准 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-090 | 内容 | V0.1 种子内容：词汇 + 阅读（原创），经 Validator 校验后打包进 Content DB | 内容可加载；无占位假数据混入正式库 | 十三、十七、九十一 |
| FR-091 | 合规 | About 页面原样展示免责声明（见 §8.2） | 文案与 BRIEF 第五十六条完全一致 | 五十五、五十六 |
| FR-092 | 合规 | 原创原则：不得大规模复制官方雅思真题/答案/材料 | 内容来源可审计；文档含独立性声明 | 五十五 |

### 3.2 P1 —— V0.2（本次只列需求，不设计页面）

| 编号 | 模块 | 需求 | 计划版本 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-100 | Listening | 听力系统：预生成音频 + 本地播放；Section 1–4；transcript/questions/answers/explanations | V0.2 | 二十、二十一 |
| FR-101 | Writing | 写作系统：Task 1/2；本地字数/段落/连接词/模板/结构检查（无 AI 评分） | V0.2 | 二十二、二十三 |
| FR-102 | Speaking | 口语系统：Part 1/2/3、录音、计时、结构提示、自我评价（无 AI 评分） | V0.2 | 二十五、二十七 |
| FR-103 | Statistics | 统计页：学习天数/总时长/连续天数/已掌握词汇/完成题数/正确率/错题数 + 五维趋势曲线 | V0.2 | 三十七 |
| FR-104 | Mistakes | 错误分类扩展：Listening/Writing/Speaking 标签（仅训练记录与自我诊断） | V0.2 | 二十九 |

### 3.3 P2 —— V0.3+

| 编号 | 模块 | 需求 | 计划版本 | BRIEF |
| --- | --- | --- | --- | --- |
| FR-110 | Achievements | 成就系统：连续 3/7/30 天；掌握 100/500/1000 词；完成 100 题等 | V0.3 | 三十八 |
| FR-111 | Favorites | 收藏：词汇/阅读/听力/写作/口语/题目 + My Favorites 页 | V0.3 | 三十九 |
| FR-112 | Notes | 笔记：给词汇/题目添加本地笔记 | V0.3 | 四十 |
| FR-113 | Backup | Import Backup（旧设备→新设备迁移） | V0.3 | 四十四 |
| FR-114 | Content Pack | Import Content Pack（SHA256 → manifest → 版本校验 → 导入） | V0.3 | 七十四 |
| FR-115 | Search | 搜索：词汇/主题/题目/知识点/错题 | V0.3 | 四十一 |
| FR-116 | Notifications | 本地通知（如「今天还有 20 个单词需要复习」），不依赖推送服务器 | V0.3 | 八十五 |
| FR-117 | Settings | 完整设置页：Dark Mode/Font Size/Sound/Reset/Import/Privacy/License | V0.3 | 四十二 |

### 3.4 P3 —— 远期（预留接口，V1 全部 Disabled）

| 编号 | 模块 | 需求 | BRIEF |
| --- | --- | --- | --- |
| FR-120 | OnlineService | 预留在线层抽象接口（Local Core 为主） | 六十五 |
| FR-121 | SyncService | 预留 `uploadProgress/downloadProgress/syncMistakes/syncFavorites` abstract interface | 六十六 |
| FR-122 | AIService | Disabled；预留 AIWritingService/AISpeakingService/AITutorService | 六十七 |
| FR-123 | AdService | Disabled；预留 Banner/Interstitial/Native Ad，基础学习不得被广告阻断 | 六十八 |

> **需求池统计**：P0 共 **46** 条（FR-001~FR-092），P1 共 5 条（FR-100~FR-104），P2 共 8 条（FR-110~FR-117），P3 共 4 条（FR-120~FR-123）。

---

## 4. 关键页面 UI 设计说明

### 4.0 设计基调（Design Tokens）

| 维度 | 取值取向 | 依据 |
| --- | --- | --- |
| 视觉关键词 | Clean / Academic / Modern / Friendly / Professional | 八十 |
| 主色 | 深蓝 Primary（学术、可信）；蓝 Secondary（交互、强调） | 八十 |
| 背景 / 表面 | 白 Background；浅灰 Surface（卡片分区） | 八十 |
| 语义色 | Success（绿）/ Warning（橙）/ Error（红） | 八十一 |
| 文字 | Text（主）/ Muted（次） | 八十一 |
| 字体 | 无衬线；正文 15~16，标题分级；支持 Font Size 调节 | 八十二、八十五 |
| **禁止** | 过度渐变、赛博朋克、大量发光、培训机构风格、复杂动画 | 八十 |
| 圆角/阴影 | 统一 token，轻微阴影、克制圆角 | 八十一 |

### 4.1 Onboarding（五步）

```
┌─────────────────────────────────────┐
│  ●○○○○            Step 1 / 5         │   ← 顶部进度指示
│                                      │
│  你的目标分数是？                     │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐  │
│  │6.0 │ │6.5 │ │7.0 │ │7.5 │ │8.0+│  │   ← 单选卡片
│  └────┘ └────┘ └────┘ └────┘ └────┘  │
│                                      │
│                    [ 下一步 → ]       │
└─────────────────────────────────────┘
```

| 步骤 | 内容 | 选项 |
| --- | --- | --- |
| 1 | 你的目标分数？ | 6.0 / 6.5 / 7.0 / 7.5 / 8.0+ |
| 2 | 距离考试多久？ | 30 / 60 / 90 / 180 天 / 暂未确定 |
| 3 | 每天学习时间？ | 30 / 60 / 90 / 120 分钟 |
| 4 | 你认为自己最弱的是？ | Listening / Reading / Writing / Speaking / Vocabulary / 不知道 |
| 5 | 初始能力测试 | 完成测试 → 生成「你的学习画像」（五维初始分） |

- 全程**不强制联网**；可返回上一步；第 5 步完成后落库并进入 Dashboard。
- 游客模式：不要求账号，直接建立 `local_user`。

### 4.2 Dashboard（首页，严格按 BRIEF 第五条）

```
┌──────────────────────────────────────────────┐
│  IELTS Free          Target 7.0   D-58 天      │  ← 目标分数 / 考试倒计时
│                                                │
│  今日进度  ▓▓▓▓▓▓░░░░░░░░  40%                 │  ← 今日进度条
│                                                │
│  今日任务                                       │
│   ☑ 词汇复习 20 词 · 15 min                     │  ← 今日任务清单
│   ☐ 词汇练习 四选一 · 10 min                    │
│   ☐ 阅读 1 篇 (T/F/NG) · 20 min                 │
│   ☐ 错题重做 5 题 · 10 min                      │
│                                                │
│  我的能力                                       │
│   Vocab ▓▓▓▓░░ 52   Reading ▓▓▓░░░ 48          │  ← 五维能力分数
│   List  ▓▓░░░░ 35   Write  ▓▓░░░░ 40           │
│   Speak ▓▓░░░░ 38                              │
│                                                │
│  连续学习 7 天 · 今日已学 25 min                │  ← 连续天数 / 今日时长
└──────────────────────────────────────────────┘
```

| 区域 | 数据来源 | 交互 |
| --- | --- | --- |
| 目标分数 | `study_goal` | 点击可编辑 |
| 考试倒计时 | `study_goal.examDate` | 无考试日期显示「未设置」 |
| 今日进度条 | `daily_tasks` 完成比例 | 随完成任务实时更新 |
| 今日任务清单 | Daily Plan 算法输出 | 点击进入对应训练 |
| 五维能力 | `skill_scores` | 点击进入对应科目 |
| 连续天数 / 今日时长 | `learning_statistics` | — |

### 4.3 Vocabulary 详情页（按 BRIEF 第十四条）

```
┌──────────────────────────────────────────────┐
│  ← 返回            词汇                ⭐      │
│                                                │
│   analyze   /ˈænəlaɪz/   v.                    │  ← word / 音标 / 词性
│   🔊 发音                                       │
│                                                │
│  中文释义：分析；解析                            │
│  英文释义：to examine something in detail...   │
│                                                │
│  常见搭配：analyze data / analyze the impact   │
│  Writing 用法：可用于 Task 2 论证中的数据描述    │
│  Speaking 用法：可用于 Part 3 表达分析观点       │
│                                                │
│  例句：Researchers analyzed the results...     │
│                                                │
│  [ ✓ 掌握 ]            [ ✗ 不认识 ]            │  ← 操作按钮
└──────────────────────────────────────────────┘
```

- 操作：🔊发音 / ⭐收藏 / ✓掌握 / ✗不认识；操作即更新记忆等级与复习计划。

### 4.4 词汇练习页（7 种题型）

```
┌──────────────────────────────────────────────┐
│  ← 练习        3 / 20              ⏱ 02:14     │  ← 进度 / 计时
│                                                │
│  题型：④ 单词拼写                                │
│                                                │
│  题目：/ˈænəlaɪz/  分析；解析                    │
│  ┌──────────────────────────────────────┐      │
│  │ a n a _ y z e                          │      │  ← 作答区（按题型变化）
│  └──────────────────────────────────────┘      │
│                                                │
│  [ 提交 ]                                       │
│  ── 提交后 ──                                   │
│  ✅ 正确   analyze                              │
└──────────────────────────────────────────────┘
```

| 题型 | 作答 UI |
| --- | --- |
| ① 单词→中文 | 输入中文 / 选择 |
| ② 中文→单词 | 输入英文 |
| ③ 四选一 | 4 个选项卡片 |
| ④ 单词拼写 | 字母输入框 |
| ⑤ 例句填空 | 句中空格输入 |
| ⑥ 同义词选择 | 选项卡片 |
| ⑦ 搭配选择 | 选项卡片 |

- 提交后：判分 → 更新 `memoryLevel`（对 +1 / 错 -1）→ 更新 `nextReviewAt` → 答错进错题。

### 4.5 Reading 做题页

**桌面（左右分栏，55% / 45%，BRIEF 十八条 / 八十三条）：**

```
┌───────────────────────────┬──────────────────────┐
│  文章 (55%)                │  题目 (45%)           │
│  ─────────────            │  题号 1 / 13   ⏱ 18:00 │
│  Passage title...         │  ─────────────        │
│  ...                      │  1. True/False/NG      │
│  (可滚动)                  │     ○ True ○ False     │
│                           │       ○ Not Given      │
│                           │  [ 提交 ]  [ 查看解析 ] │
└───────────────────────────┴──────────────────────┘
```

**移动（文章 ↓ 题目，BRIEF 十八条 / 八十三条）：**

```
┌─────────────────────┐
│ ← 阅读   ⏱ 18:00     │
│ ─────────────────── │
│  文章（可滚动）        │
│  Passage title...    │
│  ...                 │
│ ─────────────────── │
│  题目                 │
│  1. True/False/NG    │
│  ...                 │
│  [ 提交 ]             │
└─────────────────────┘
```

- 保留题号、进度、剩余时间；提交后逐题展示解析（correctAnswer / evidence / keywords / synonyms / logic / explanation）。

### 4.6 Mistakes 列表与详情

```
列表页                          详情页
┌──────────────────────┐       ┌──────────────────────────┐
│ ← 错题   [全部|词汇|阅读]│       │ ← 错题详情               │
│ ──────────────────── │       │ 题型：T/F/NG  错误类型：同义替换│
│ □ T/F/NG · 同义替换    │       │ 你的答案：False           │
│   analyze · 错 2 次    │       │ 正确答案：Not Given       │
│ ──────────────────── │       │ ── 解析 ──               │
│ □ 四选一 · 词义        │       │ evidence: ...            │
│   subtle · 错 1 次     │       │ keywords: ...            │
│ ...                  │       │ explanation: ...         │
│ [ 重做错题 ]           │       │ [ 重做 ]  mastery 20%     │
└──────────────────────┘       └──────────────────────────┘
```

- 按类型 / 科目筛选；展示 `wrongCount` / `mastery`；支持重做。

### 4.7 Study Plan 页

```
┌──────────────────────────────────────────────┐
│  ← 学习计划                                    │
│  计划周期：  [7] [30] [60] [90] [Custom]        │  ← 计划选择
│  ──────────────────────────────────────────── │
│  当前阶段：专项训练（剩余 58 天，30~90 天区间）  │  ← 倒计时策略
│  ──────────────────────────────────────────── │
│  本周安排（每日按算法动态调整）                  │
│  周一  词汇 20 词 · 阅读 1 篇 · 错题 5 题        │
│  周二  词汇 25 词 · 阅读 2 篇 ...                │
│  ...                                          │
└──────────────────────────────────────────────┘
```

- 计划非完全固定，每天根据算法重新调整（BRIEF 三十六条）。

---

## 5. 移动端与桌面端导航差异（BRIEF 第六条）

| 端 | 导航形式 | 一级入口 |
| --- | --- | --- |
| 移动端（Android 手机/平板） | **底部 Bottom Navigation** | 首页 / 学习 / 练习 / 错题 / 我的 |
| 桌面端（Windows） | **左侧 Sidebar** | Home / Learn / Vocabulary / Reading / Listening / Writing / Speaking / Mistakes / Study Plan / Statistics / Settings |

**响应式要求（BRIEF 八十三 / 八十四条）：**

| 场景 | 布局 |
| --- | --- |
| Android 手机 | 单列；阅读：文章↓题目；听力：播放器↓问题 |
| Android 平板 | 自适应加宽，可两栏 |
| Windows 1366×768 / 1920×1080 | Sidebar + Main；阅读 55%/45%；词汇 列表+详情；统计 图表+数据 |

> V0.1 桌面 Sidebar 中 Listening/Writing/Speaking/Statistics 入口可先保留但标注「V0.2」占位。

---

## 6. 数据与隐私要求

### 6.1 内容库 / 用户库分离（BRIEF 第四十五条）

| 库 | 文件 | 权限 | 内容 |
| --- | --- | --- | --- |
| Content Database | 内容 DB（只读） | **只读** | vocabulary / reading 等题库内容 |
| User Database | 用户 DB（读写） | **读写** | 用户档案、进度、错题、词汇记忆、能力分数、计划、设置 |

- 内容与程序版本解耦，便于后续发布新题库（BRIEF 七十四）。
- **不允许**把用户数据写入内容库。

### 6.2 Export / Delete My Data（BRIEF 四十三、八十七条）

| 功能 | 要求 |
| --- | --- |
| Export My Data | 导出 `IELTS-Free-Backup.json`，含学习进度/错题/收藏/笔记/词汇记忆状态/能力分数/计划 |
| Delete My Data | 一键清除本地用户数据，需二次确认 |

### 6.3 隐私原则（BRIEF 八十八条）

| 原则 | 要求 |
| --- | --- |
| No tracking | 不埋点、不追踪 |
| No analytics by default | 默认无分析上报 |
| No cloud account | 无需云账号 |
| No behavior upload | 不上传行为数据 |
| 录音默认本地 | 用户可选保存或不保存，**不默认上传网络**（BRIEF 二十七） |

---

## 7. 非功能需求

### 7.1 离线强制（BRIEF 六十三 / 六十四）

| 编号 | 要求 | 验收 |
| --- | --- | --- |
| NFR-01 | 飞行模式/关 Wi-Fi/关移动网络下，首页/词汇/阅读/错题/计划/统计全部可用 | 断网手动测试 + E2E |
| NFR-02 | 正常学习流程**禁止依赖**任何外部 AI API / 在线服务器 / 在线数据库 | 代码审查 + 断网测试 |
| NFR-03 | V1 尽可能不请求网络权限；若平台技术需要，不得因无网络导致核心功能崩溃 | Manifest 审查 + 异常测试 |

### 7.2 性能与体积（BRIEF 九十九 / 一百）

| 编号 | 要求 |
| --- | --- |
| NFR-10 | 启动尽可能快；首页避免一次性加载整库 |
| NFR-11 | Lazy Load / Pagination / Indexed Queries / Caching + 必要索引 |
| NFR-12 | 优化 APK/Windows 包体积；音频压缩；清理未使用资源与依赖 |
| NFR-13 | 冷启动首屏 ≤ 3 秒（中端机） |

### 7.3 启动体验（BRIEF 六十二）

| 编号 | 要求 |
| --- | --- |
| NFR-20 | 首次启动：初始化数据库 → 导入 Content DB → 建立索引 → 建立用户档案，显示进度 |
| NFR-21 | 后续启动直接读本地库，无需重复导入 |

### 7.4 数据库迁移保护用户数据（BRIEF 七十一~七十五）

| 编号 | 要求 |
| --- | --- |
| NFR-30 | 数据库升级（DB v1→v2）必须 Migration，**不得删除用户数据** |
| NFR-31 | 覆盖安装后用户数据保留 |
| NFR-32 | 内容包导入需校验 SHA256 → manifest → 版本（V0.3 完整实现，V0.1 预留） |

### 7.5 测试要求（BRIEF 七十六~七十九）

| 类型 | 覆盖对象 |
| --- | --- |
| Unit Test | 词汇记忆算法、能力评分、难度升级、错题优先级、每日计划 |
| Integration Test | 做题→提交→记录→生成错题→更新能力 |
| E2E Test | 首次启动→设置目标→完成测试→获得计划→学习→退出→再次打开→数据仍在 |
| 强制验收项 | **离线测试**（Android/Windows 完全断网下全部功能成功） |

---

## 8. 内容合规

### 8.1 原创内容原则（BRIEF 第五十五条）

- 尽可能自建原创 IELTS-style 内容。
- **不得**大规模复制官方雅思真题、官方答案、官方材料或其他受版权保护的完整内容。
- 所有 AI 生成内容必须经 Validation Agent（Grammar / Answer / Duplicate / Difficulty / Consistency / Formatting Check），状态流 `draft → validated → reviewed → published`，**不得直接进入正式题库**。
- 质量门槛：**宁可 1000 个高质量词汇，也不要 10000 个错误词汇；宁可 50 篇高质量原创阅读，也不要 500 篇低质量 AI 内容。**

### 8.2 App 内版权说明（About 页面，BRIEF 第五十六条 —— 原样写入）

```
IELTS Free
An independent open-source IELTS learning project.
This software is not affiliated with or endorsed by
IELTS, British Council, IDP Education, or Cambridge Assessment English.
All original educational content in this project
is created for learning and practice purposes.
```

### 8.3 独立性声明（BRIEF 第五十五条 —— 文档必须写明）

> IELTS Free is an independent educational project and is not affiliated with IELTS, British Council, IDP Education, or Cambridge Assessment English.

### 8.4 能力评分免责（BRIEF 第二十九条）

- V1 口语/写作标签仅用于训练记录与自我诊断，**不得宣称软件具备官方 IELTS 评分能力**。
- 能力评分目的不是预测官方分数，而是判断用户下一步该学什么（BRIEF 三十一条）。

---

## 9. 待确认问题（不阻塞开发，均给出推荐默认值）

> 说明：以下问题不影响架构与开发启动，架构师与工程师可**直接按推荐默认值推进**；用户后续如需调整再迭代。

| 编号 | 问题 | 推荐默认值 | 理由 |
| --- | --- | --- | --- |
| Q-1 | **V0.1 种子内容规模取多少？** | 词汇 **300 词** + 阅读 **8 篇 / 80 题**（覆盖 T/F/NG、Multiple Choice、Summary Completion 三类） | 足以跑通闭环与算法验证，又不至于让 V0.1 内容生产拖慢开发；远低于 V1 目标（3000 词 / 100 篇），留待后续内容包扩充 |
| Q-2 | **初始能力测试题量？** | **每维 3 题 × 5 维 = 15 题**（听力/写作/口语在 V0.1 无题时用自评映射：以 Onboarding 第 4 步「最弱项」做保守初始分） | 15 题约 5~8 分钟，平衡准确度与首次体验；V0.1 无 L/W/S 题库，用自评兜底 |
| Q-3 | **颜色主色具体色值？** | Primary 深蓝 `#1E3A5F`；Secondary 蓝 `#2F6FED`；Background `#FFFFFF`；Surface `#F5F7FA`；Success `#2E7D32`；Warning `#ED6C02`；Error `#D32F2F` | 符合「白/深蓝/蓝/浅灰」学术取向；具体值由架构师在 `theme.dart` 收敛为 Design Tokens |
| Q-4 | 五维能力分数展示用分数还是 Band 估算？ | **展示 0~100 分数**，不换算 Band | 避免伪精确与官方评分误导（BRIEF 三十一条） |
| Q-5 | 每日任务是否允许用户手动增删？ | **允许调整顺序，不允许删除算法生成的核心任务** | 保证算法闭环数据完整，同时保留用户掌控感 |
| Q-6 | V0.1 是否做深色模式？ | **做**（基础 Dark Theme，走同一套 Design Tokens） | 成本低、体验收益高；设置项可 V0.3 完善 |
| Q-7 | 桌面端入口中 V0.2 科目是否显示？ | **显示但置灰 + 标注「V0.2」** | 提前建立信息架构，避免后续大改导航 |
| Q-8 | 自动保存 debounce 间隔？ | **答题状态 500ms debounce + 每完成一题 checkpoint** | 平衡性能与数据安全（BRIEF 七十九） |
| Q-9 | 阅读剩余时间到期行为？ | **到期自动提交并判分**，不强制退出 | 贴近真实考试体验 |
| Q-10 | V0.1 是否实现本地通知？ | **不实现**（列 V0.3，FR-116） | 聚焦闭环，避免平台差异拖慢 V0.1 |

---

## 附录 A：V0.1 闭环验收清单（映射 BRIEF 一百一十一条）

| 验收项 | V0.1 范围 | 状态目标 |
| --- | --- | --- |
| 断网测试 | 首页 ✓ 词汇 ✓ 阅读 ✓ 错题 ✓ 计划 ✓（听力/写作/口语 V0.2） | 通过 |
| 数据测试 | 关闭重开后 学习记录/错题/词汇记忆/能力分数/计划 均在 | 通过 |
| 更新测试 | 旧版本→新版本 用户数据不丢失 | 通过（Migration） |
| 闭环测试 | 学习→答题→错误→错题→能力更新→下一次训练变化 | 通过 |

## 附录 B：V0.1 明确「不做」清单（防止范围蔓延）

- 不做听力 / 写作 / 口语页面（P1，V0.2）
- 不做实时 AI、不接服务器、不接广告、不设付费墙
- 不做云同步 / 账号系统（P3）
- 不做内容包 Import（V0.3）
- 不做统计页图表 / 成就 / 收藏 / 笔记页面（P2，V0.3）
- 不做本地通知（V0.3）
