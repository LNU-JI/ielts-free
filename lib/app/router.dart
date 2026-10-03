import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ielts_free/app/responsive.dart';
import 'package:ielts_free/core/providers/bootstrap_provider.dart';
import 'package:ielts_free/features/bootstrap/presentation/bootstrap_page.dart';
import 'package:ielts_free/features/dashboard/presentation/dashboard_page.dart';
import 'package:ielts_free/features/learn/presentation/learn_hub_page.dart';
import 'package:ielts_free/features/listening/presentation/listening_list_page.dart';
import 'package:ielts_free/features/listening/presentation/listening_session_page.dart';
import 'package:ielts_free/features/me/presentation/me_page.dart';
import 'package:ielts_free/features/mistakes/presentation/mistake_detail_page.dart';
import 'package:ielts_free/features/mistakes/presentation/mistakes_page.dart';
import 'package:ielts_free/features/onboarding/presentation/onboarding_page.dart';
import 'package:ielts_free/features/practice/presentation/practice_hub_page.dart';
import 'package:ielts_free/features/reading/presentation/reading_list_page.dart';
import 'package:ielts_free/features/reading/presentation/reading_session_page.dart';
import 'package:ielts_free/features/settings/presentation/about_page.dart';
import 'package:ielts_free/features/settings/presentation/settings_page.dart';
import 'package:ielts_free/features/speaking/presentation/speaking_list_page.dart';
import 'package:ielts_free/features/speaking/presentation/speaking_session_page.dart';
import 'package:ielts_free/features/statistics/presentation/statistics_placeholder_page.dart';
import 'package:ielts_free/features/study_plan/presentation/study_plan_page.dart';
import 'package:ielts_free/features/vocabulary/presentation/vocabulary_detail_page.dart';
import 'package:ielts_free/features/vocabulary/presentation/vocabulary_list_page.dart';
import 'package:ielts_free/features/vocabulary/presentation/vocabulary_practice_page.dart';
import 'package:ielts_free/features/writing/presentation/writing_list_page.dart';
import 'package:ielts_free/features/writing/presentation/writing_session_page.dart';
import 'package:ielts_free/shared/widgets/navigation/app_shell.dart';

/// Route paths used across the app. Kept as constants so navigation calls and
/// the route table cannot drift apart.
abstract final class AppRoutes {
  static const String bootstrap = '/bootstrap';
  static const String onboarding = '/onboarding';

  // Mobile shell.
  static const String home = '/home';
  static const String learn = '/learn';
  static const String practice = '/practice';
  static const String mistakes = '/mistakes';
  static const String me = '/me';

  // Desktop shell.
  static const String dashboard = '/dashboard';
  static const String vocabulary = '/vocabulary';
  static const String reading = '/reading';
  static const String studyPlan = '/study-plan';
  static const String settings = '/settings';
  static const String about = '/settings/about';
  static const String listening = '/listening';
  static const String writing = '/writing';
  static const String speaking = '/speaking';
  static const String statistics = '/statistics';

  // Full-screen (no shell).
  static const String vocabularyPractice = '/practice/vocabulary';
}

/// The application router.
///
/// Every in-shell route renders through a single **width-adaptive** [AppShell]
/// (bottom navigation on phones, left sidebar on wide screens), so a given path
/// looks correct at any window size. The route table is grouped into two
/// [ShellRoute]s only to mirror the mobile and desktop navigation trees
/// described in docs/ARCHITECTURE-v0.1.md §2.3; both now delegate to [AppShell].
/// The redirect sends the user to Onboarding until it is completed, then lands
/// them on the shell that matches the current window width.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.bootstrap,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) =>
        _redirect(ref, context, state),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.bootstrap,
        builder: (BuildContext context, GoRouterState state) =>
            const BootstrapPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingPage(),
      ),

      // ---------------------------------------------------------------------
      // Mobile navigation tree: 首页 / 学习 / 练习 / 错题 / 我的
      // (rendered by AppShell → MobileShell on narrow windows)
      // ---------------------------------------------------------------------
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            AppShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            builder: (BuildContext context, GoRouterState state) =>
                const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.learn,
            builder: (BuildContext context, GoRouterState state) =>
                const LearnHubPage(),
          ),
          GoRoute(
            path: AppRoutes.practice,
            builder: (BuildContext context, GoRouterState state) =>
                const PracticeHubPage(),
          ),
          GoRoute(
            path: AppRoutes.mistakes,
            builder: (BuildContext context, GoRouterState state) =>
                const MistakesPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (BuildContext context, GoRouterState state) =>
                    MistakeDetailPage(
                  mistakeId: state.pathParameters['id'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.me,
            builder: (BuildContext context, GoRouterState state) =>
                const MePage(),
          ),
        ],
      ),

      // ---------------------------------------------------------------------
      // Desktop navigation tree: Home / Learn / Vocabulary / Reading /
      // Listening / Writing / Speaking / Mistakes / Study Plan / Statistics /
      // Settings
      // (rendered by AppShell → DesktopShell on wide windows; Listening /
      //  Writing / Speaking / Statistics are V0.2 placeholders.)
      // ---------------------------------------------------------------------
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            AppShell(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (BuildContext context, GoRouterState state) =>
                const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.vocabulary,
            builder: (BuildContext context, GoRouterState state) =>
                const VocabularyListPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (BuildContext context, GoRouterState state) =>
                    VocabularyDetailPage(
                  vocabularyId:
                      int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.reading,
            builder: (BuildContext context, GoRouterState state) =>
                const ReadingListPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (BuildContext context, GoRouterState state) =>
                    ReadingSessionPage(
                  passageId:
                      int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.studyPlan,
            builder: (BuildContext context, GoRouterState state) =>
                const StudyPlanPage(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (BuildContext context, GoRouterState state) =>
                const SettingsPage(),
            routes: <RouteBase>[
              GoRoute(
                path: 'about',
                builder: (BuildContext context, GoRouterState state) =>
                    const AboutPage(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.listening,
            builder: (BuildContext context, GoRouterState state) =>
                const ListeningListPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (BuildContext context, GoRouterState state) =>
                    ListeningSessionPage(
                  sectionId:
                      int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.writing,
            builder: (BuildContext context, GoRouterState state) =>
                const WritingListPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (BuildContext context, GoRouterState state) =>
                    WritingSessionPage(
                  taskId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.speaking,
            builder: (BuildContext context, GoRouterState state) =>
                const SpeakingListPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (BuildContext context, GoRouterState state) =>
                    SpeakingSessionPage(
                  topicId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.statistics,
            builder: (BuildContext context, GoRouterState state) =>
                const StatisticsPlaceholderPage(),
          ),
        ],
      ),

      // ---------------------------------------------------------------------
      // Full-screen route (no shell): vocabulary practice.
      // ---------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.vocabularyPractice,
        builder: (BuildContext context, GoRouterState state) =>
            const VocabularyPracticePage(),
      ),
    ],
  );

  // Re-run redirect whenever bootstrap state changes (e.g. Onboarding done).
  ref.listen<AsyncValue<BootstrapState>>(
    bootstrapControllerProvider,
    (_, __) => router.refresh(),
  );
  ref.onDispose(router.dispose);

  return router;
});

/// Redirect policy:
/// - while startup is in progress, stay on `/bootstrap`;
/// - until Onboarding is completed, force `/onboarding`;
/// - once completed, land on the shell that matches the window width.
String? _redirect(Ref ref, BuildContext context, GoRouterState state) {
  final AsyncValue<BootstrapState> bootstrap =
      ref.read(bootstrapControllerProvider);
  final String location = state.matchedLocation;

  final bool isInitializing = bootstrap.isLoading || !bootstrap.hasValue;
  if (isInitializing) {
    return location == AppRoutes.bootstrap ? null : AppRoutes.bootstrap;
  }

  final bool onboardingCompleted =
      bootstrap.valueOrNull?.onboardingCompleted ?? false;
  if (!onboardingCompleted) {
    return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
  }

  if (location == AppRoutes.bootstrap || location == AppRoutes.onboarding) {
    final double width = MediaQuery.maybeSizeOf(context)?.width ?? 0;
    return AppBreakpoints.isDesktopWidth(width)
        ? AppRoutes.dashboard
        : AppRoutes.home;
  }

  return null;
}
