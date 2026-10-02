/// Widget tests for the shared building blocks — ARCHITECTURE §3.5.
///
/// These widgets are the loading / empty / error branches reused by every page,
/// so verifying them here keeps the page-level tests focused on behaviour.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ielts_free/app/strings.dart';
import 'package:ielts_free/app/theme.dart';
import 'package:ielts_free/shared/widgets/empty_state.dart';
import 'package:ielts_free/shared/widgets/error_view.dart';
import 'package:ielts_free/shared/widgets/linear_progress_bar.dart';
import 'package:ielts_free/shared/widgets/loading_view.dart';
import 'package:ielts_free/shared/widgets/section_card.dart';
import 'package:ielts_free/shared/widgets/skill_bar.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('EmptyState shows its message', (WidgetTester tester) async {
    await pump(tester, const EmptyState(message: '还没有内容'));
    expect(find.text('还没有内容'), findsOneWidget);
  });

  testWidgets('ErrorView shows the message and a retry action',
      (WidgetTester tester) async {
    int taps = 0;
    await pump(
      tester,
      ErrorView(message: '出错了', onRetry: () => taps++),
    );
    expect(find.text('出错了'), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    await tester.tap(find.text(AppStrings.retry));
    expect(taps, 1);
  });

  testWidgets('LoadingView shows a spinner and the default caption',
      (WidgetTester tester) async {
    await pump(tester, const LoadingView());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.loading), findsOneWidget);
  });

  testWidgets('SectionCard renders its child', (WidgetTester tester) async {
    await pump(tester, const SectionCard(child: Text('卡片内容')));
    expect(find.text('卡片内容'), findsOneWidget);
  });

  testWidgets('LinearProgressBar clamps its value', (WidgetTester tester) async {
    await pump(tester, const LinearProgressBar(value: 1.5));
    final LinearProgressIndicator bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 1.0);
  });

  testWidgets('SkillBar shows the label and the score',
      (WidgetTester tester) async {
    await pump(tester, const SkillBar(label: 'Vocab', value: 52));
    expect(find.text('Vocab'), findsOneWidget);
    expect(find.text('52'), findsOneWidget);
  });
}
