/// User-visible strings for IELTS Free (V0.1).
///
/// All copy that a user can read lives here so it can be reviewed, translated
/// and kept consistent. We deliberately do NOT use `flutter gen-l10n` because it
/// performs code generation (see docs/ARCHITECTURE-v0.1.md §2.1).
///
/// The V0.1 interface language is Simplified Chinese; technical identifiers stay
/// in English.
library;

/// Central collection of user-visible text.
abstract final class AppStrings {
  // --- App shell ----------------------------------------------------------

  static const String appName = 'IELTS Free';
  static const String appTagline = 'Free Offline IELTS Learning App';

  // --- Navigation (mobile bottom bar) ------------------------------------

  static const String navHome = '首页';
  static const String navLearn = '学习';
  static const String navPractice = '练习';
  static const String navMistakes = '错题';
  static const String navMe = '我的';

  // --- Navigation (desktop sidebar) --------------------------------------

  static const String navDashboard = 'Home';
  static const String navLearnHub = 'Learn';
  static const String navVocabulary = 'Vocabulary';
  static const String navReading = 'Reading';
  static const String navListening = 'Listening';
  static const String navWriting = 'Writing';
  static const String navSpeaking = 'Speaking';
  static const String navMistakesFull = 'Mistakes';
  static const String navStudyPlan = 'Study Plan';
  static const String navStatistics = 'Statistics';
  static const String navSettings = 'Settings';

  // --- Common -------------------------------------------------------------

  static const String comingSoon = 'V0.2';
  static const String placeholderTitle = 'V0.1 开发中';
  static const String placeholderMessage =
      '此功能正在开发中，将在后续版本提供。';
  static const String loading = '加载中…';
  static const String retry = '重试';
  static const String back = '返回';
  static const String next = '下一步';
  static const String previous = '上一步';
  static const String skip = '跳过';
  static const String confirm = '确定';
  static const String cancel = '取消';
  static const String done = '完成';
  static const String save = '保存';
  static const String edit = '编辑';
  static const String notSet = '未设置';
  static const String minutesUnit = 'min';
  static const String minutesWord = '分钟';
  static const String daysWord = '天';
  static const String wordsUnit = '词';
  static const String passagesUnit = '篇';
  static const String questionsUnit = '题';
  static const String unavailableV02 = 'V0.2 版本提供';

  // --- Buttons (vocabulary & practice) -----------------------------------

  static const String speak = '发音';
  static const String favorite = '收藏';
  static const String master = '掌握';
  static const String dontKnow = '不认识';
  static const String submit = '提交';
  static const String redo = '重做';
  static const String viewExplanation = '查看解析';
  static const String continueLabel = '继续';

  // --- Onboarding ---------------------------------------------------------

  static const String onboardingTitle = '欢迎使用 IELTS Free';

  static const String onboardingStep1Title = '你的目标分数是？';
  static const List<String> onboardingStep1Options = <String>[
    '6.0',
    '6.5',
    '7.0',
    '7.5',
    '8.0+',
  ];

  static const String onboardingStep2Title = '距离考试还有多久？';
  static const List<String> onboardingStep2Options = <String>[
    '30 天',
    '60 天',
    '90 天',
    '180 天',
    '暂未确定',
  ];

  static const String onboardingStep3Title = '每天能学习多长时间？';
  static const List<String> onboardingStep3Options = <String>[
    '30 分钟',
    '60 分钟',
    '90 分钟',
    '120 分钟',
  ];

  static const String onboardingStep4Title = '你认为自己最弱的是？';
  static const List<String> onboardingStep4Options = <String>[
    'Listening',
    'Reading',
    'Writing',
    'Speaking',
    'Vocabulary',
    '不知道',
  ];

  static const String onboardingStep5Title = '初始能力测试';
  static const String onboardingStep5Description =
      '完成 15 道题，生成你的学习画像（五维初始分）。';
  static const String onboardingFinish = '开始学习';

  /// Short "Step n / total" label shown at the top of the flow.
  static String onboardingStepIndicator(int current, int total) =>
      'Step $current / $total';

  /// Marks values that are derived from self-rating rather than a real test
  /// (ARCHITECTURE R7 / PRD Q-2). Shown verbatim next to such values.
  static const String onboardingEstimated = '估算';
  static const String onboardingEstimatedNote =
      'V0.1 暂无听力 / 写作 / 口语题库，这三项先按你的自评给出保守初始分，'
      '后续答题会自动校准。';

  /// The 15-item self-assessment of step 5 (3 statements per dimension).
  static const List<String> onboardingTestQuestions = <String>[
    '我能根据上下文猜出陌生词汇的大意。',
    '我掌握了不少学术场景的高频词。',
    '我能区分近义词在正式写作中的细微差别。',
    '我能快速定位阅读文章中的关键信息。',
    '我能处理 T/F/NG 这类判断题。',
    '我能在限定时间内读完并理解一篇学术文章。',
    '我能抓住英语听力中的主要观点。',
    '我能听懂日常对话中的细节信息。',
    '我能跟上英语母语者的自然语速。',
    '我能写出结构清晰的议论文。',
    '我能用多样的句式表达观点。',
    '我能在 40 分钟内完成一篇 250 词作文。',
    '我能就熟悉话题连续表达 1 分钟以上。',
    '我的发音清晰、语调自然。',
    '我能即兴回答 Part 3 的深入追问。',
  ];

  /// Three-point self-rating options used by the initial test.
  static const List<String> onboardingTestOptions = <String>[
    '不太符合',
    '一般',
    '比较符合',
  ];

  // --- Dashboard ----------------------------------------------------------

  static const String dashboardTitle = 'IELTS Free';
  static const String dashboardTarget = '目标';
  static const String dashboardCountdown = '距考试';
  static const String dashboardNoExamDate = '未设置';
  static const String dashboardDaysSuffix = '天';
  static const String dashboardTodayProgress = '今日进度';
  static const String dashboardTodayTasks = '今日任务';
  static const String dashboardSkillScores = '我的能力';
  static const String dashboardStreak = '连续学习';
  static const String dashboardTodayMinutes = '今日已学';
  static const String dashboardMinutesUnit = 'min';
  static const String dashboardStreakDaysSuffix = '天';
  static const String dashboardSkillVocabulary = 'Vocab';
  static const String dashboardSkillReading = 'Reading';
  static const String dashboardSkillListening = 'List';
  static const String dashboardSkillWriting = 'Write';
  static const String dashboardSkillSpeaking = 'Speak';

  /// Shown under the five-dimension bars (PRD Q-4 / BRIEF §29/§31).
  static const String dashboardSkillDisclaimer = '非官方分数，仅用于安排训练';

  static const String dashboardNoTasks = '今天还没有任务，去「学习计划」生成吧。';
  static const String dashboardGeneratePlan = '生成今日任务';
  static const String dashboardErrorTitle = '首页数据加载失败';

  // Task titles (persisted in `daily_tasks.title`).
  static const String taskTitleVocabReview = '词汇复习';
  static const String taskTitleReading = '阅读';
  static const String taskTitleMistakeReview = '错题重做';

  /// Builds a task title such as `词汇复习 20 词 · 15 min`.
  static String taskTitle(
    String base, {
    int? itemCount,
    String? itemUnit,
    int? minutes,
  }) {
    final List<String> parts = <String>[base];
    if (itemCount != null && itemCount > 0) {
      parts.add('$itemCount ${itemUnit ?? ''}'.trim());
    }
    final String head = parts.join(' ');
    if (minutes != null && minutes > 0) {
      return '$head · $minutes $minutesUnit';
    }
    return head;
  }

  // --- Vocabulary ---------------------------------------------------------

  static const String vocabularyTitle = '词汇';
  static const String vocabularyMeaningCn = '中文释义';
  static const String vocabularyMeaningEn = '英文释义';
  static const String vocabularyCollocations = '常见搭配';
  static const String vocabularyWritingUsage = 'Writing 用法';
  static const String vocabularySpeakingUsage = 'Speaking 用法';
  static const String vocabularyExamples = '例句';
  static const String vocabularyPracticeTitle = '词汇练习';

  // --- Reading ------------------------------------------------------------

  static const String readingTitle = '阅读';
  static const String readingPassage = '文章';
  static const String readingQuestions = '题目';
  static const String readingExplanation = '解析';
  static const String readingEvidence = '原文证据';
  static const String readingKeywords = '关键词';
  static const String readingSubmit = '提交';

  // --- Mistakes -----------------------------------------------------------

  static const String mistakesTitle = '错题';
  static const String mistakesDetailTitle = '错题详情';
  static const String mistakesFilterAll = '全部';
  static const String mistakesFilterVocabulary = '词汇';
  static const String mistakesFilterReading = '阅读';
  static const String mistakesYourAnswer = '你的答案';
  static const String mistakesCorrectAnswer = '正确答案';
  static const String mistakesWrongTimesSuffix = '次';

  // --- Study plan ---------------------------------------------------------

  static const String studyPlanTitle = '学习计划';
  static const String studyPlanWeekSchedule = '本周安排';
  static const String studyPlanCurrentPhase = '当前阶段';

  static const String studyPlanPeriod = '计划周期';
  static const String studyPlanCustom = 'Custom';
  static const String studyPlanCustomDaysTitle = '自定义天数';
  static const String studyPlanCustomDaysHint = '输入 1 ~ 365 天';
  static const String studyPlanNoExamDate = '未设置考试日期，按长期基础阶段安排。';
  static const String studyPlanRegenerate = '重新生成今日任务';
  static const String studyPlanEmpty = '暂无计划安排。';
  static const String studyPlanDynamicNote = '计划每天会根据你的表现动态调整。';
  static const String studyPlanErrorTitle = '学习计划加载失败';

  static const String studyPlanPhaseFoundation = '基础阶段';
  static const String studyPlanPhaseFocus = '专项训练';
  static const String studyPlanPhaseComprehensive = '综合冲刺';

  /// Human label for a phase, used on the Study Plan page.
  static String studyPlanPhaseLabel(String phaseWire) {
    switch (phaseWire) {
      case 'FOUNDATION':
        return studyPlanPhaseFoundation;
      case 'FOCUS':
        return studyPlanPhaseFocus;
      case 'COMPREHENSIVE':
        return studyPlanPhaseComprehensive;
      default:
        return studyPlanPhaseFoundation;
    }
  }

  /// `当前阶段：专项训练（剩余 58 天）`.
  static String studyPlanPhaseSummary(String phaseLabel, int? daysRemaining) {
    if (daysRemaining == null) {
      return '$phaseLabel（未设置考试日期）';
    }
    return '$phaseLabel（剩余 $daysRemaining $daysWord）';
  }

  /// Day-of-week labels used by the weekly schedule.
  static const List<String> studyPlanWeekdayNames = <String>[
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  // --- Settings / About ---------------------------------------------------

  static const String settingsTitle = '设置';
  static const String aboutTitle = '关于';

  // Settings sections / rows.
  static const String settingsSectionGoal = '学习目标';
  static const String settingsSectionAppearance = '外观';
  static const String settingsSectionData = '数据';
  static const String settingsSectionAbout = '关于';

  static const String settingsTargetBand = '目标分数';
  static const String settingsExamDate = '考试日期';
  static const String settingsDailyStudyTime = '每日学习时长';
  static const String settingsExamDateClear = '清除考试日期';

  static const String settingsDarkMode = '深色模式';
  static const String settingsThemeSystem = '跟随系统';
  static const String settingsThemeLight = '浅色';
  static const String settingsThemeDark = '深色';
  static const String settingsFontSize = '字体大小';
  static const String settingsSound = '音效';
  static const String settingsFontSmall = '小';
  static const String settingsFontDefault = '标准';
  static const String settingsFontLarge = '大';
  static const String settingsFontXLarge = '特大';

  static const String settingsExportData = '导出我的数据';
  static const String settingsExportDataSubtitle = '导出为 IELTS-Free-Backup.json';
  static const String settingsDeleteData = '删除我的数据';
  static const String settingsDeleteDataSubtitle = '清除本机全部学习数据（不可恢复）';
  static const String settingsDeleteConfirmTitle = '确认删除全部数据？';
  static const String settingsDeleteConfirmMessage =
      '此操作不可恢复，将清除档案、进度、错题、词汇记忆、能力分数与计划。';
  static const String settingsDeleteConfirmStep2 = '再次确认：真的要删除吗？';
  static const String settingsDeleteAction = '删除';

  static const String settingsPrivacy = '隐私政策';
  static const String settingsLicense = '开源许可';
  static const String settingsOpenSource = '开源项目主页';

  static const String settingsSaved = '已保存';
  static const String settingsSaveFailed = '保存失败，请重试。';
  static const String settingsExportSuccess = '已导出备份文件：';
  static const String settingsExportFailed = '导出失败，请重试。';
  static const String settingsDeleteSuccess = '已清除本地数据。';
  static const String settingsDeleteFailed = '删除失败，请重试。';
  static const String settingsAboutSubtitle = '版本信息、免责声明与开源许可';

  static const String privacySummary =
      'IELTS Free 是一个完全离线的本地应用：不埋点、不追踪、不上传行为数据、'
      '不需要云账号。所有学习数据仅保存在你的设备上，可随时导出或删除。';
  static const String licenseSummary =
      '本项目的源代码以开源许可发布；所有原创学习内容仅用于学习与练习用途。'
      '本软件与 IELTS、British Council、IDP Education、Cambridge Assessment '
      'English 均无关联，也未获其认可。';
  static const String openSourceSummary =
      'IELTS Free —— 一个独立、开源、免费、离线的雅思学习项目。';

  // Hub pages (mobile tabs).
  static const String learnHubSubtitle = '选择今天要学习的内容';
  static const String learnHubVocabulary = '词汇';
  static const String learnHubReading = '阅读';
  static const String learnHubListening = '听力';
  static const String learnHubWriting = '写作';
  static const String learnHubSpeaking = '口语';
  static const String practiceHubSubtitle = '开始一次练习';
  static const String practiceHubVocabulary = '词汇练习';
  static const String practiceHubReading = '阅读练习';
  static const String practiceHubMistakes = '错题重做';
  static const String meProfileSummary = '我的学习概况';
  static const String meStatistics = '学习统计';
  static const String meMistakes = '错题本';
  static const String meStudyPlan = '学习计划';
  static const String meSettings = '设置';
  static const String meAbout = '关于';
  static const String meOnboardingRedo = '重新引导';

  /// The exact independence / copyright disclaimer required by the BRIEF
  /// (section 56). Do not edit this text — it must be shown verbatim.
  static const String aboutDisclaimer = 'IELTS Free\n'
      'An independent open-source IELTS learning project.\n'
      'This software is not affiliated with or endorsed by\n'
      'IELTS, British Council, IDP Education, or Cambridge Assessment English.\n'
      'All original educational content in this project\n'
      'is created for learning and practice purposes.';

  // --- Vocabulary list & detail (T04b) -----------------------------------

  static const String vocabularySearchHint = '搜索单词或释义';
  static const String vocabularyFilterTopic = '主题';
  static const String vocabularyFilterDifficulty = '难度';
  static const String vocabularyEmpty = '没有找到匹配的词汇。';
  static const String vocabularyEmptyHint = '换个关键词或筛选条件试试。';
  static const String vocabularyListErrorTitle = '词汇加载失败';
  static const String vocabularyLoadMore = '加载更多';
  static const String vocabularyAllTopics = '全部';
  static const String vocabularyPartOfSpeech = '词性';
  static const String vocabularySynonyms = '近义词';
  static const String vocabularyAntonyms = '反义词';
  static const String vocabularyCommonMistakes = '常见错误';
  static const String vocabularyRelatedWords = '词族';
  static const String vocabularyTopicLabel = '主题';
  static const String vocabularyNoField = '—';
  static const String vocabularySpeakUnavailable = '暂不可用（离线无发音）';
  static const String vocabularyMastered = '已掌握';
  static const String vocabularyDetailErrorTitle = '词汇加载失败';

  /// `300 词`
  static String vocabularyCountLabel(int count) => '$count $wordsUnit';

  /// `记忆等级 L3`
  static String vocabularyLevelLabel(int level) => '记忆等级 L$level';

  /// `难度 3`
  static String vocabularyDifficultyLabel(int difficulty) => '难度 $difficulty';

  // --- Vocabulary practice (T04b) ----------------------------------------

  static const String vocabularyPracticeEmpty = '暂无可练习的词汇。';
  static const String vocabularyPracticeEmptyHint = '先到「词汇」页学习一些单词吧。';
  static const String vocabularyPracticeCompleteTitle = '本次练习完成';
  static const String vocabularyPracticeRestored = '已恢复上次未完成的练习';
  static const String vocabularyPracticeNext = '下一题';
  static const String vocabularyPracticeFinish = '完成';
  static const String vocabularyPracticeHint = '提示';
  static const String vocabularyPracticeSpellingHint = '请输入单词';
  static const String vocabularyPracticeAnswerHint = '请输入答案';
  static const String vocabularyPracticeCorrect = '正确';
  static const String vocabularyPracticeWrong = '错误';
  static const String vocabularyPracticeYourAnswer = '你的答案';
  static const String vocabularyPracticeCorrectAnswer = '正确答案';
  static const String vocabularyPracticeRestart = '再来一组';
  static const String vocabularyPracticeQuestion = '题目';

  /// `3 / 20`
  static String vocabularyPracticeProgress(int current, int total) =>
      '$current / $total';

  /// `答对 18 / 20`
  static String vocabularyPracticeResult(int correct, int total) =>
      '答对 $correct / $total';

  /// `正确率 90%`
  static String vocabularyPracticeAccuracy(int percent) => '正确率 $percent%';

  /// `题型 ④`
  static String vocabularyPracticeKindLabel(int number) {
    const List<String> circled = <String>['①', '②', '③', '④', '⑤', '⑥', '⑦'];
    final String mark = (number >= 1 && number <= circled.length)
        ? circled[number - 1]
        : '$number';
    return '题型 $mark';
  }

  /// The seven practice kinds (BRIEF §16), in order.
  static const List<String> vocabularyPracticeKindNames = <String>[
    '单词→中文',
    '中文→单词',
    '四选一',
    '单词拼写',
    '例句填空',
    '同义词选择',
    '搭配选择',
  ];

  // --- Reading list & session (T04b) -------------------------------------

  static const String readingListErrorTitle = '阅读加载失败';
  static const String readingListEmpty = '暂无阅读文章。';
  static const String readingListEmptyHint = '稍后再来看看。';
  static const String readingSessionErrorTitle = '阅读加载失败';
  static const String readingPassageEmpty = '文章内容缺失。';
  static const String readingRemaining = '剩余';
  static const String readingSubmitAll = '提交本次阅读';
  static const String readingAutoSubmitted = '时间到，已自动提交';
  static const String readingAllDone = '本次阅读已完成';
  static const String readingNoAnswer = '未作答';
  static const String readingYourAnswer = '你的答案';
  static const String readingCorrectAnswerLabel = '正确答案';
  static const String readingSynonyms = '同义替换';
  static const String readingLogic = '逻辑';
  static const String readingExplanationTitle = '解析';
  static const String readingPrev = '上一题';
  static const String readingNext = '下一题';

  /// `8 篇`
  static String readingCountLabel(int count) => '$count $passagesUnit';

  /// `题号 1 / 13`
  static String readingQuestionOf(int current, int total) =>
      '题号 $current / $total';

  /// `建议 20 分钟`
  static String readingTimeLabel(int minutes) => '建议 $minutes $minutesWord';

  /// `答对 10 / 13`
  static String readingResult(int correct, int total) =>
      '答对 $correct / $total';

  // --- Mistakes (T04b) ---------------------------------------------------

  static const String mistakesErrorTitle = '错题加载失败';
  static const String mistakesEmpty = '还没有错题，继续保持！';
  static const String mistakesEmptyHint = '答错的题会自动出现在这里。';
  static const String mistakesDetailErrorTitle = '错题加载失败';
  static const String mistakesTypeLabel = '题型';
  static const String mistakesErrorTypeLabel = '错误类型';
  static const String mistakesSkillLabel = '科目';
  static const String mistakesRedo = '重做';
  static const String mistakesRedoAll = '重做错题';
  static const String mistakesMasteredTag = '已掌握';
  static const String mistakesRedoCorrect = '答对了，掌握度提升。';
  static const String mistakesRedoWrong = '又答错了，掌握度下降。';
  static const String mistakesMasteryLabel = '掌握度';

  /// `错 2 次`
  static String mistakesWrongCount(int count) => '错 $count 次';

  /// `掌握度 20%`
  static String mistakesMasteryPercent(int percent) => '掌握度 $percent%';

  /// `12 题`
  static String mistakesCountLabel(int count) => '$count $questionsUnit';

  /// Error-type labels keyed by the persisted `error_type` wire value (BRIEF §29).
  static const Map<String, String> errorTypeLabels = <String, String>{
    'VOCAB_WORD_MEANING': '词义',
    'VOCAB_SYNONYM': '同义词',
    'VOCAB_COLLOCATION': '搭配',
    'VOCAB_SPELLING': '拼写',
    'READING_LOCATING': '定位',
    'READING_PARAPHRASE': '同义替换',
    'READING_MAIN_IDEA': '主旨',
    'READING_DETAIL': '细节',
    'READING_INFERENCE': '推断',
    'READING_LOGIC': '逻辑',
    'READING_QUESTION_TYPE': '题型',
    'LISTENING_LOCATING': '定位',
    'LISTENING_SPELLING': '拼写',
    'LISTENING_NUMBER': '数字',
    'LISTENING_KEYWORD': '关键词',
    'LISTENING_PARAPHRASE': '同义替换',
    'LISTENING_MISSED_INFO': '信息遗漏',
    'WRITING_GRAMMAR': '语法',
    'WRITING_VOCABULARY': '词汇',
    'WRITING_COHERENCE': '连贯',
    'WRITING_TASK_RESPONSE': '任务回应',
    'WRITING_SENTENCE_STRUCTURE': '句式',
    'SPEAKING_FLUENCY': '流利度',
    'SPEAKING_VOCABULARY': '词汇',
    'SPEAKING_GRAMMAR': '语法',
    'SPEAKING_PRONUNCIATION': '发音',
    'SPEAKING_STRUCTURE': '结构',
  };

  /// Human label for an `error_type` wire value.
  static String errorTypeLabel(String? wire) =>
      errorTypeLabels[wire] ?? (wire ?? '');

  /// Question-type labels keyed by the `question_type` wire value.
  static const Map<String, String> questionTypeLabels = <String, String>{
    'TFNG': 'True/False/Not Given',
    'YNNG': 'Yes/No/Not Given',
    'MC': '四选一',
    'MATCH_HEADINGS': '匹配标题',
    'MATCH_INFO': '匹配信息',
    'SENTENCE_COMPLETION': '句子填空',
    'SUMMARY_COMPLETION': '摘要填空',
    'TABLE_COMPLETION': '表格填空',
    'NOTE_COMPLETION': '笔记填空',
  };

  /// Human label for a `question_type` wire value.
  static String questionTypeLabel(String? wire) =>
      questionTypeLabels[wire] ?? (wire ?? '');

  /// Skill labels keyed by the `skill` wire value (used on the mistake detail).
  static const Map<String, String> skillLabels = <String, String>{
    'VOCABULARY': '词汇',
    'READING': '阅读',
    'LISTENING': '听力',
    'WRITING': '写作',
    'SPEAKING': '口语',
    'READING_TFNG': 'T/F/NG',
    'READING_MC': '选择题',
    'READING_SUMMARY': '摘要题',
    'DETAIL': '细节题',
    'INFERENCE': '推断题',
    'MATCH_HEADINGS': '匹配标题',
  };

  /// Human label for a `skill` wire value.
  static String skillLabel(String? wire) => skillLabels[wire] ?? (wire ?? '');

  // --- Errors -------------------------------------------------------------

  static const String errorGeneric = '出现了一些问题，请稍后重试。';
  static const String errorDatabase = '本地数据访问失败，请重试。';
  static const String errorContentMissing = '内容库加载失败，请重新安装应用。';
  static const String errorNotImplemented = '该功能尚未实现。';
}
