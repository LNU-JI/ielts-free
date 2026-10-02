# IELTS Free —— 项目总任务书（BRIEF / 唯一事实来源）

> 本文件由主理人从用户提供的《IELTS Free Flutter 全平台开发总任务书》原文固化而来，作为产品经理、架构师、工程师、QA 的共同输入。
> **任何与用户原始需求冲突的解释，以本文件为准；本文件未覆盖处，由成员按「离线优先 / 本地数据优先 / 基础功能永久免费 / 开源」四大原则自行判定。**

---

## 一、项目总定义

- 项目名称：**IELTS Free**
- 英文副标题：Free Offline IELTS Learning App
- 中文定位：一款本地运行、无需服务器、无需实时 AI、基础功能永久免费、代码公开透明的雅思学习软件。
- 核心理念：**AI + Agent 负责开发阶段生产内容；App 负责本地交付和自适应学习。**

用户使用流程：下载 App → 安装 → 本地数据库 → 本地题库 → 本地音频 → 本地算法 → 离线学习。

正常学习流程**禁止依赖**：GPT / Claude / Gemini / DeepSeek / 任何外部 AI API / 任何在线服务器 / 任何在线数据库。即使用户完全断网，核心学习功能仍必须正常运行。

## 二、第一阶段平台

- V1 优先：**Android**（产物 `IELTS-Free-Android.apk`）+ **Windows**（产物 `IELTS-Free-Windows.zip` 或安装程序）。
- V2 再增加：macOS、Linux、iOS。**不要第一阶段同时开发所有平台。**

> ⚠️ 本次交付的环境约束（主理人补充，非用户原文）：构建机无 Flutter/Android SDK/VS 工具链，**本次只交付完整可构建源码 + GitHub Actions CI**，不本地打包。

## 三、核心产品原则（必须遵守）

1. **Offline First** —— 所有核心功能本地运行。
2. **Local Data First** —— 内容优先存放本地。
3. **AI Not Required** —— AI 是开发工具，不是用户使用依赖。
4. **永久免费基础功能** —— V1 不收费、不接广告、不要求 AI。
5. **可扩展** —— 以后增加云同步/AI/广告/在线题库/社区，都不能破坏离线核心。
6. **开源** —— 代码放 GitHub；题库数据尽可能采用清晰、可审计的数据格式。

## 四、产品一句话

> IELTS Free：把雅思词汇、阅读、听力、写作、口语、自适应训练和错题管理全部装进用户设备，让用户无需服务器也能长期免费学习。

## 五、整体产品结构（首页）

首页要回答「今天应该学什么」，展示：目标分数、考试倒计时、今日学习进度条、今日任务清单、我的能力（Vocabulary/Reading/Listening/Writing/Speaking 五维分数）、连续学习天数、今日学习时长。

## 六、底部导航

- 移动端：首页 / 学习 / 练习 / 错题 / 我的
- 桌面端左侧 Sidebar：Home / Learn / Vocabulary / Reading / Listening / Writing / Speaking / Mistakes / Study Plan / Statistics / Settings

## 七、技术栈（优先使用）

Flutter + Dart；状态管理 Riverpod；路由 go_router；本地数据库 Drift + SQLite；本地文件 JSON / SQLite / MP3；音频 just_audio（须验证 Android/Windows 兼容性）；UI Material 3；图表使用成熟 Flutter 图表库。

## 八、工程目录

```
ielts_free/
├── android/ windows/ macos/ linux/ ios/
├── lib/
│   ├── main.dart
│   ├── app/            (app.dart router.dart theme.dart constants.dart)
│   ├── core/           (database/ storage/ services/ utils/ errors/ models/)
│   ├── features/       (onboarding/ dashboard/ vocabulary/ reading/ listening/ writing/ speaking/ mistakes/ study_plan/ statistics/ achievements/ settings/)
│   └── shared/         (widgets/ components/ extensions/)
├── assets/             (data/ audio/ images/ icons/ seed/)
├── content_pipeline/   (vocabulary/ reading/ listening/ writing/ speaking/ validators/)
├── test/  integration_test/  docs/
├── README.md  LICENSE  pubspec.yaml
```

## 九、数据库设计（本地 SQLite，推荐 Drift）

核心表：users、user_profile、study_goal、study_plan、daily_tasks、vocabulary、vocabulary_topics、vocabulary_reviews、reading_passages、reading_questions、reading_options、listening_passages、listening_questions、writing_prompts、writing_templates、writing_expressions、speaking_questions、speaking_structures、skills、skill_scores、user_answers、mistakes、favorites、notes、learning_sessions、learning_statistics、achievements、user_achievements、content_metadata、app_settings。

## 十、为什么还需要本地数据库

不能把所有内容放 LocalStorage。SQLite 需保存：用户设置、学习进度、错题、收藏、笔记、词汇记忆等级、学习统计、每日任务、能力分数。

## 十一、用户模型

首次打开进入 Onboarding，不强迫联网，允许**游客模式**，默认建立 `Local User`：
```json
{ "id": "local_user", "targetBand": 7.0, "examDate": null, "dailyStudyMinutes": 60 }
```

## 十二、Onboarding（五步）

1. 你的目标分数？(6.0/6.5/7.0/7.5/8.0+)
2. 距离考试多久？(30/60/90/180天/暂未确定)
3. 每天学习时间 (30/60/90/120分钟)
4. 你认为自己最弱的是？(Listening/Reading/Writing/Speaking/Vocabulary/不知道)
5. 初始能力测试 → 生成「你的学习画像」(五维初始分)

## 十三、词汇系统

V1 至少 1000~3000 个高质量核心词汇（后续 5000+/8000+/10000+）。每个词字段：word、phonetic、partOfSpeech、meaningCN、meaningEN、difficulty、cefr、ieltsLevel、topics、synonyms、antonyms、collocations、examples、writingUsage、speakingUsage、commonMistakes、relatedWords。

## 十四、词汇页面

展示 word / 音标 / 词性 / 中文释义 / 英文释义 / 常见搭配 / IELTS Writing 用法 / IELTS Speaking 用法 / 例句；操作：🔊发音、⭐收藏、✓掌握、✗不认识。

## 十五、词汇记忆系统

每词保存 memoryLevel、correctCount、wrongCount、streak、lastReviewedAt、nextReviewAt。初始 Level 0。
复习间隔：L0→当天、L1→1天、L2→3天、L3→7天、L4→14天、L5→30天、L6→60天。
答对 Level+1；答错 Level-1；连续错误提高复习优先级。

## 十六、词汇练习类型

1 单词→中文；2 中文→单词；3 四选一；4 单词拼写；5 例句填空；6 同义词选择；7 搭配选择。
闭环：单词学习 → 练习 → 测试 → 记忆等级 → 复习计划。

## 十七、阅读系统

每篇：title、topic、difficulty、band、readingTime、passage、questions、answers、explanations、skills。V1 至少 50 篇原创阅读 + 500 题。
题型：True/False/Not Given、Yes/No/Not Given、Multiple Choice、Matching Headings、Matching Information、Sentence Completion、Summary Completion、Table Completion、Note Completion。

## 十八、阅读页面

桌面：左文章 右题目；手机：文章 ↓ 题目。保留题号、进度、剩余时间。

## 十九、阅读解析

每题必须保存 correctAnswer、evidence、keywords、synonyms、logic、explanation（含同义替换说明）。

## 二十、听力系统

**预生成音频 + 本地播放**（不做实时生成）。字段：audioFile、transcript、questions、answers、explanations、section、topic、difficulty。支持 Section 1–4。V1：30 份原创听力 + 300 题。

## 二十一、听力音频生产

Listening Agent → 生成脚本 → 质量检查 → TTS → 人工审核 → MP3 → 打包进 App。用户侧：本地 MP3 → 本地播放器，完全离线。

## 二十二、写作系统

Task 1（Chart/Graph/Table/Process/Map/Mixed）与 Task 2（Agree-Disagree / Discuss Both Views / Advantages-Disadvantages / Problems-Solutions / Two-part Question / Mixed）。

## 二十三、V1 写作不需要 AI

本地提供：文章字数、段落数、句子数、常见连接词、模板检查、结构检查、关键词检查，以及 Introduction/Body1/Body2/Conclusion 结构训练。

## 二十四、写作知识库

观点库、论证库、连接词库、句型库、同义词库、高频主题库、常见错误库。主题含 Education/Technology/Environment/Health/Government/Crime/Culture/Work/Society/Transport。

## 二十五、口语系统

Part 1（问题 30 秒）、Part 2（1 分钟准备 + 2 分钟回答）、Part 3（深入讨论）。**V1 不需要 AI 评分**，提供录音、计时、结构提示、关键词、自我评价。

## 二十六、口语训练结构

模板库：人物（Who/How you met/What happened/Why important/How you feel）、地点（Where/When/What it looks like/What you did/Why memorable）、事件（What/When/Who/What happened/Why important/Reflection）。

## 二十七、录音系统

开始/暂停/结束/播放/删除/重录。录音默认**本地保存**，用户可选保存或不保存，**不要默认上传网络**。

## 二十八、错题系统

所有做错题自动加入 Mistakes。字段：questionId、questionType、skill、userAnswer、correctAnswer、errorType、difficulty、wrongCount、lastWrongAt、mastery。

## 二十九、错误分类 Taxonomy

- Vocabulary：Word Meaning / Synonym / Collocation / Spelling
- Reading：定位 / 同义替换 / 主旨 / 细节 / 推断 / 逻辑 / 题型
- Listening：定位 / 拼写 / 数字 / 关键词 / 同义替换 / 信息遗漏
- Writing：Grammar / Vocabulary / Coherence / Task Response / Sentence Structure
- Speaking：Fluency / Vocabulary / Grammar / Pronunciation / Structure

> V1 口语/写作标签仅用于训练记录与自我诊断，**不得宣称软件具备官方 IELTS 评分能力**。

## 三十、自适应学习引擎（核心）

UserSkillProfile 五维（Vocabulary/Reading/Listening/Writing/Speaking），各 0~100。阅读再细分 T/F/NG、Matching Headings、Multiple Choice、Summary、Detail、Inference。

## 三十一、能力评分算法（基础版）

```
Skill Score = Correctness × Difficulty Factor × Consistency Factor × Recency Factor
```
归一化到 0~100。**不追求伪精确，目的不是预测官方分数，而是判断用户下一步该学什么。**

## 三十二、训练优先级算法

```
Priority = Error Frequency × Skill Importance × Recency × Difficulty
```
例：用户最近连续错 T/F/NG → T/F/NG Priority ↑ → 当天任务增加相关训练。

## 三十三、难度自适应

- 连续 3 次正确率 > 85% → 难度 +1
- 正确率 < 60% → 难度 -1
- 某知识点连续错误 3 次 → 进入专项训练

## 三十四、每日任务算法

输入：目标分数、当前能力、剩余天数、每日学习时间、最近错误、历史训练量。输出 Daily Plan（各科分钟数）。若某科最弱，提高其权重。

## 三十五、考试倒计时策略

>90 天：基础/词汇/知识点；30~90 天：专项；<30 天：综合训练/模拟/错题。

## 三十六、学习计划

提供 7/30/60/90 Day 与 Custom；但计划非完全固定，每天根据算法重新调整。

## 三十七、首页统计

学习天数、总学习时长、连续天数、已掌握词汇、完成题目、正确率、错题数；能力曲线（五维趋势）。

## 三十八、成就系统（轻量）

连续 3/7/30 天；掌握 100/500/1000 词；完成 100 题；完成第一篇写作；完成第一套完整训练。

## 三十九、收藏

可收藏：词汇、阅读、听力、写作表达、口语表达、题目。页面 My Favorites。

## 四十、笔记

用户可给词汇/阅读题/写作题/口语题添加笔记，完全本地保存。

## 四十一、搜索

支持搜索词汇、主题、题目、知识点、错题。

## 四十二、设置

Target Band、Exam Date、Daily Study Time、Dark Mode、Font Size、Sound、Notifications、Reset Learning Data、Export Data、Import Data、About、Privacy、License、Open Source。

## 四十三 / 四十四、数据备份与恢复

Export → `IELTS-Free-Backup.json`（学习进度/错题/收藏/笔记/词汇记忆状态/能力分数/计划）；Import Backup 实现旧设备→新设备迁移。

## 四十五、内容数据与用户数据分离（技术上非常重要）

**Content Database（只读）+ User Database（读写）**，便于后续发布新题库。

## 四十六、内容包设计

`content_v1.0/`（vocabulary.db/reading.db/listening.db/writing.db/speaking.db/manifest.json）或统一 `ielts_content_v1.db`。优先评估：**单一 SQLite 内容数据库 + 独立音频资源**。

## 四十七、不要大量 JSON 散落在 App 中

推荐流水线：AI 生产 JSON → Validator → 编译/导入 SQLite → 生成 Content DB → 打包 Release。

## 四十八~五十三、AI + Agent 内容生产系统（`/content_pipeline`，不运行在用户 App 中）

- Vocabulary Agent：word list → meaning/phonetic/pos/examples/collocations/synonyms/antonyms/topic/difficulty/ielts use/common mistakes
- Reading Agent：Topic → Difficulty → Article → Questions → Answers → Evidence → Explanation → Validation
- Listening Agent：Topic → Scenario → Script → Questions → Answers → Transcript → TTS → Audio → Validation
- Writing Agent：题目/观点/论证/结构/范文/高频表达/常见错误/训练任务
- Speaking Agent：Part 1/2/3 + 题目/思路/结构/Useful Vocabulary/Useful Expressions/Follow-up Questions

## 五十四、Validation Agent

所有内容必须经过 Grammar / Answer / Duplicate / Difficulty / Consistency / Formatting Check。AI 生成**不能直接进入正式题库**。状态流：draft → validated → reviewed → published。

## 五十五、原创内容原则

尽可能自建原创 IELTS-style 内容；**不得大规模复制官方雅思真题、官方答案、官方材料或其他受版权保护的完整内容**。文档必须写明：

> IELTS Free is an independent educational project and is not affiliated with IELTS, British Council, IDP Education, or Cambridge Assessment English.

## 五十六、App 内版权说明（About 页面）

```
IELTS Free
An independent open-source IELTS learning project.
This software is not affiliated with or endorsed by
IELTS, British Council, IDP Education, or Cambridge Assessment English.
All original educational content in this project
is created for learning and practice purposes.
```

## 五十七 / 五十八、GitHub 仓库

`github.com/<用户名>/ielts-free`，含 README.md、LICENSE、CONTRIBUTING.md、CODE_OF_CONDUCT.md、SECURITY.md、CHANGELOG.md。
README 第一屏：`Free and Offline IELTS Learning App` + ✓Offline ✓Free ✓Open Source ✓No AI required ✓No account required ✓Adaptive learning ✓Android ✓Windows，然后 Download / Features / Screenshots / Installation / Architecture / Content / Roadmap / License。

## 五十九~六十一、Releases 与发布结构

版本 v0.1.0 / v0.2.0 / v0.3.0 / v1.0.0。发布 Android APK、Windows package、Source code、Content package、SHA256 checksums。
Release 结构示例：`IELTS-Free-Android-v1.0.0.apk`、`IELTS-Free-Windows-v1.0.0.zip`、`IELTS-Free-Content-v1.0.0.zip`、`SHA256SUMS.txt`。
**GitHub 单个 Release 资产需 < 2 GiB，大内容包应拆分或压缩。**
**不要把 MP3/大型数据库/安装包直接提交进 Git 仓库**，应作为 Release Assets。

## 六十二、首次启动

初始化数据库 → 导入 Content DB → 建立索引 → 建立用户档案；以后启动直接读本地库。启动显示进度。

## 六十三 / 六十四、断网必须可用 & 网络权限

飞行模式/关 Wi-Fi/关移动网络下，首页、词汇、阅读、听力、写作、口语、错题、计划、统计全部可用。V1 尽可能不请求网络权限；若某平台技术需要，**不得因无网络导致核心功能崩溃**。

## 六十五~六十八、预留接口（V1 全部 Disabled）

- `OnlineService`（Optional 在线层，Local Core 为主）
- `SyncService`：uploadProgress/downloadProgress/syncMistakes/syncFavorites（V1 仅留 abstract interface）
- `AIService` = Disabled（预留 AIWritingService / AISpeakingService / AITutorService）
- `AdService` = Disabled（预留 Banner/Interstitial/Native Ad，基础学习不得被广告阻断）

## 六十九 / 七十、免费与商业化

V1：收费 0 / 广告 0 / AI 0 / 服务器 0。商业化路径：完全免费 → 广告 → AI 高级功能 → 学校/机构部署；但 Vocabulary/Reading/Listening/Writing/Speaking/Mistakes/Study Plan 保持免费。

## 七十一~七十五、更新与迁移

新版本 → GitHub Release → 用户下载安装包覆盖安装；**用户数据必须保留**，数据库升级需要 Migration（DB v1 → DB v2），不得删除用户数据。
内容与程序版本解耦；内容包导入：设置中 Import Content Pack，校验 SHA256 → manifest → 版本 → 导入。
manifest 示例：contentVersion / appCompatibility / vocabularyCount / readingCount / listeningCount / writingCount / speakingCount / checksum。

## 七十六~七十九、测试与健壮性

- Unit Test：词汇记忆算法、能力评分、难度升级、错题优先级、每日计划
- Integration Test：做题→提交→记录→生成错题→更新能力
- E2E Test：首次启动→设置目标→完成测试→获得计划→学习→退出→再次打开→数据仍在
- **离线测试为强制验收项**（Android/Windows 完全断网下全部功能成功）
- 崩溃恢复 + 自动保存（debounce + session checkpoint）：答案、学习进度、计时、词汇状态、错题

## 八十~八十四、界面与响应式

视觉关键词：Clean / Academic / Modern / Friendly / Professional；配色 白 / 深蓝 / 蓝 / 浅灰。**不要**过度渐变、赛博朋克、大量发光、培训机构风格、复杂动画。
建立 Design Tokens：Primary/Secondary/Background/Surface/Text/Muted/Success/Warning/Error，禁止页面随意写死颜色。
响应式：Android 手机+平板；Windows 1366×768 与 1920×1080。桌面 Sidebar+Main（阅读 55%/45%，词汇 列表+详情，统计 图表+数据）；移动 Bottom Navigation（阅读 文章↓题目，听力 播放器↓问题）。

## 八十五~八十八、通知 / 设置 / 隐私

本地通知（如「今天还有 20 个单词需要复习」），不依赖推送服务器。设置含通知开关、音量、自动播放、字体大小、深色模式、每日目标。
提供 Export My Data / Delete My Data。V1 隐私原则：No tracking / No analytics by default / No cloud account / No behavior upload。

## 八十九 / 九十、内容生产自动化 CLI

```bash
generate vocabulary|reading|listening|writing|speaking
validate content
deduplicate content
build content db
export content pack
```
例：`python generate_reading.py --count 100` → `generated/reading_0001.json` …；`python validate_content.py` → `Valid: 97 / Need Review: 3 / Duplicate: 0`；`python build_content_db.py` → `ielts_content_v1.db`。

## 九十一、内容质量门槛

**宁可 1000 个高质量词汇，也不要 10000 个错误词汇；宁可 50 篇高质量原创阅读，也不要 500 篇低质量 AI 内容。**

## 九十二、Agent 不得做的事

不得 AI 生成直接发布；不得复制网页真题；不得把 AI API 作为学习必需条件；不得强制登录；第一版不得搭复杂云后端、不得做广告、不得做付费系统。

## 九十三、第一阶段开发顺序（Sprint）

S1 Flutter 工程/主题/路由/数据库/存储/架构（能启动的空壳）→ S2 Onboarding/Dashboard/Vocabulary/Review → S3 Reading/Questions/Answers/Explanations/Mistakes → S4 Listening/Audio/Transcript → S5 Writing/Speaking/Timers/Recording → S6 Adaptive/DailyPlan/Statistics/Achievements → S7 Backup/Restore/Settings/Offline QA → S8 Release Build/GitHub/README/Release Notes/APK/Windows。

## 九十四~九十七、版本范围

- **V0.1 MVP 必须实现：Dashboard、Vocabulary、Reading、Mistakes、Adaptive Engine**，最先证明闭环：学习→答题→错误→错题→能力更新→下一次训练变化。
- V0.2：Listening、Writing、Speaking、Statistics
- V0.3：Achievements、Favorites、Notes、Backup、Content Pack Import
- V1.0：完整四科、自适应算法、离线运行、用户数据、内容数据库、GitHub 开源、Android/Windows Release

## 九十八、V1.0 内容目标

Vocabulary 3000+；Reading 100+ / 1000+ 题；Listening 50+ / 500+ 题；Writing 200+；Speaking 300+。**不允许为凑数量降低质量。**

## 九十九 / 一百、性能与体积

启动尽可能快；首页避免一次性加载整库；Lazy Load / Pagination / Indexed Queries / Caching；必要索引。优化 APK/Windows 包体积、音频压缩、清理未使用资源与依赖。

## 一百零一~一百零三、发布与 CI

Release 资产：APK / Windows package / Content Pack / SHA256SUMS.txt（单文件 < 2 GiB）。
提供 SHA256 校验。
GitHub Actions（`.github/workflows/`）：android.yml、windows.yml、tests.yml、release.yml；push tag v1.0.0 → 自动测试 → 自动 build → 生成 APK → 生成 Windows package → 生成 checksum → 创建 GitHub Release。

## 一百零四 / 一百零五、Issue 与贡献

Issue Template：Bug / Feature Request / Content Error / Question，字段 Device/OS/App Version/Problem/Steps to Reproduce/Expected/Actual。
CONTRIBUTING.md 允许题目、词汇、翻译、UI、代码、Bug Fix 贡献；内容贡献必须审核。

## 一百零六、License

代码默认可优先 MIT，但**必须把代码 License 与教育内容 License 分开考虑**，不要自动认为所有生成内容具有相同版权状态。

## 一百零七、README 产品介绍

```
IELTS Free is an independent, offline-first, open-source IELTS learning app.
No account required. No server required. No AI required.
Learn anywhere. Learn offline. Learn for free.
```

## 一百零八、核心架构

```
                    IELTS Free
          ┌──────────────┴──────────────┐
      Local Content                 Local User Data
   (Vocabulary/Reading/...)     (Progress/Mistakes/Favorites/
          │                       Notes/Statistics)
          └──────────────┬──────────────┘
                  Adaptive Engine
                         ↓
                   Daily Planner
                         ↓
                      User
```
后台：AI + Agent（Vocabulary/Reading/Listening/Writing/Speaking Agent + Validator）→ Human Review → Content Database → Content Pack → App。

## 一百零九 / 一百一十、未来扩展与理念

V2 Cloud Sync；V3 AI Writing/Speaking/Tutor；V4 Community；V5 Ads。核心本地学习引擎始终存在。
产品不是「一个需要联网的 AI 雅思 App」，而是**一个可以独立运行的数字化雅思学习系统**：
内容 + 知识结构 + 自适应算法 + 学习记录 + 本地数据库 = IELTS Free。

## 一百一十一、最终验收（V1 完成前必须证明）

1. **断网测试**：启动 ✓ 首页 ✓ 词汇 ✓ 阅读 ✓ 听力 ✓ 写作 ✓ 口语 ✓ 错题 ✓ 统计 ✓ 学习计划 ✓
2. **数据测试**：关闭重开后 学习记录/错题/词汇记忆/收藏/笔记/计划 均在 ✓
3. **更新测试**：旧版本→新版本 用户数据不丢失 ✓
4. **发布测试**：GitHub Release 含 APK ✓ Windows ✓ Source ✓ Checksum ✓ README ✓ Release Notes ✓

## 一百一十二、执行方式

不要只输出计划，必须直接执行：Create Project → Write Code → Create Database → Create Components → Create Tests → Generate Seed Data → Build App → Run Tests → Fix Errors → Build Release → Prepare GitHub Repository。
每阶段结束输出：Completed / Files Changed / Database Changes / Tests / Build Result / Known Issues / Next Task。

## 一百一十三、优先级

- **P0**：离线运行 + 本地数据库 + 词汇 + 阅读 + 错题 + 自适应算法 + 每日任务
- **P1**：听力 + 写作 + 口语
- **P2**：统计 + 成就 + 收藏 + 笔记 + 备份
- **P3**：AI + 云同步 + 广告 + 社区

## 一百一十四 / 一百一十五、战略与最终命令

第一阶段 0 元用户 / 0 元 AI 调用 / 0 元服务器 / 0 元广告；通过 GitHub 开源与 Releases 分发。
现在开始开发 **IELTS Free V1**：初始化工程 → 建立 Android+Windows → 目录架构 → Drift/SQLite → Onboarding → Dashboard → Vocabulary → Reading → Mistakes → Adaptive Engine → Daily Plan → 种子内容 → 测试 → 断网测试 → APK → Windows → GitHub 发布文件 → README/LICENSE/CHANGELOG → 不接实时 AI / 不接服务器 / 不接广告 / 不设付费墙 → V1 基础学习功能完全免费。

**最终目标不是生成一个 UI Demo，而是生成一个用户可以下载、安装、断网、长期使用的真正可运行软件。**

> 用户附加指令：**不要问我每一步要怎么做；先按任务书直接执行，遇到非关键技术选择自行选稳定方案。只有涉及产品核心方向或无法继续的阻塞问题才暂停。**
