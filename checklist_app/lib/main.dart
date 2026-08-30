import 'package:flutter/material.dart';

import 'data/app_state.dart';
import 'pages/home_page.dart';
import 'pages/question_page.dart';
import 'pages/result_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(ChecklistApp(state: state));
}

/// 禁用滚动时的过度拉伸/发光效果：内容滚到底就停，
/// 不出现“无限延长”的弹性反馈（对结果页这类短列表更干净）。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

class ChecklistApp extends StatefulWidget {
  const ChecklistApp({super.key, required this.state});

  final AppState state;

  @override
  State<ChecklistApp> createState() => _ChecklistAppState();
}

class _ChecklistAppState extends State<ChecklistApp> {
  @override
  void initState() {
    super.initState();
    widget.state.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final seed = const Color(0xFF3F51B5);
        return MaterialApp(
          title: '清单追踪',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AppScrollBehavior(),
          themeMode: state.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: seed),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: seed, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          home: switch (state.screen) {
            Screen.home => HomePage(state: state),
            Screen.question => QuestionPage(state: state),
            Screen.result => ResultPage(state: state),
          },
        );
      },
    );
  }
}
