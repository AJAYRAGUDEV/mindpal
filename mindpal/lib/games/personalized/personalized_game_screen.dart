import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/language_scope.dart';
import '../../models/difficulty.dart';
import '../../models/game_result.dart';
import '../../models/quiz_question.dart';
import '../../services/memory_aid_service.dart';
import '../../l10n/app_language.dart';
import '../../services/ai_service.dart';
import '../../services/personalized_game_service.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import 'personalized_game_session.dart';

/// The personalised game — "Memory Moment".
///
/// Deliberately calmer than Memory Match and Sequence Recall: no clock, no
/// moves counter, no pressure. The only progress shown is "2 / 5". This is a
/// game about your own family, and it should feel like remembering, not
/// competing.
///
/// Note what this widget does NOT do: it never builds a question. It asks
/// [PersonalizedGameService] for a finished list and plays it. When a real AI
/// generator arrives, it replaces the service and this file is untouched.
class PersonalizedGameScreen extends StatefulWidget {
  const PersonalizedGameScreen({
    super.key,
    required this.memoryAidService,
    required this.difficulty,
    required this.onOpenMemoryAid,
    required this.aiService,
    required this.language,
  });

  final MemoryAidService memoryAidService;
  final Difficulty difficulty;

  /// Called from the empty state, to send the user where they can add data.
  final VoidCallback onOpenMemoryAid;

  /// The question source. GeminiAiService tries the gateway and validates
  /// what comes back; DeterministicAiService builds them locally. This screen
  /// cannot tell which it was given, and does not need to.
  final AiService aiService;

  /// Passed in rather than read from LanguageScope, because the first load
  /// happens in initState where an inherited-widget lookup is not allowed.
  final AppLanguage language;

  /// How many questions each difficulty asks. Short on purpose — this is a
  /// gentle daily activity, not an exam.
  static int questionCountFor(Difficulty difficulty) => switch (difficulty) {
    Difficulty.easy => 3,
    Difficulty.medium => 5,
    Difficulty.hard => 7,
  };

  @override
  State<PersonalizedGameScreen> createState() => _PersonalizedGameScreenState();
}

class _PersonalizedGameScreenState extends State<PersonalizedGameScreen> {
  PersonalizedGameSession? _session;
  bool _isLoading = true;

  /// The result screen is shown only when the player asks for it.
  ///
  /// Without this the last answer would flip straight to the result and the
  /// player would never see whether they got it right — the one question whose
  /// feedback matters most.
  bool _showingResult = false;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  Future<void> _startNewGame() async {
    setState(() => _isLoading = true);

    final data = await widget.memoryAidService.loadAll();

    // Never throws: the service handles its own failures and returns the
    // deterministic set if anything goes wrong online.
    final questions = await widget.aiService.generateQuestions(
      data: data,
      language: widget.language,
      count: PersonalizedGameScreen.questionCountFor(widget.difficulty),
    );
    if (!mounted) return;

    setState(() {
      // No questions means not enough saved data. We show an empty state
      // rather than padding the game with invented content.
      _showingResult = false;
      _session = questions.isEmpty
          ? null
          : PersonalizedGameSession(
              questions: questions,
              difficulty: widget.difficulty,
            );
      _isLoading = false;
    });
  }

  void _answer(int optionIndex) {
    final session = _session;
    if (session == null || session.isAnswered) return;
    setState(() => session.answer(optionIndex));
  }

  void _next() => setState(() => _session!.next());

  void _showResult() => setState(() => _showingResult = true);

  /// Leaves, handing the result back so MainShell can file it in the Activity
  /// History — the same route Memory Match and Sequence Recall already use.
  void _leaveWithResult() {
    final session = _session;
    Navigator.of(
      context,
    ).pop<GameResult>(session?.toResult());
  }

  @override
  Widget build(BuildContext context) {
    final strings = LanguageScope.of(context);
    final session = _session;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.personalizedGame),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: strings.backToHome,
          onPressed: _leaveWithResult,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : session == null
              ? _EmptyState(
                  strings: strings,
                  onAddMemories: () {
                    Navigator.of(context).pop();
                    widget.onOpenMemoryAid();
                  },
                )
              : _showingResult
              ? _ResultView(
                  session: session,
                  strings: strings,
                  onPlayAgain: _startNewGame,
                  onBackHome: _leaveWithResult,
                )
              : _QuestionView(
                  session: session,
                  strings: strings,
                  onAnswer: _answer,
                  onNext: _next,
                  onShowResult: _showResult,
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- question

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.session,
    required this.strings,
    required this.onAnswer,
    required this.onNext,
    required this.onShowResult,
  });

  final PersonalizedGameSession session;
  final AppStrings strings;
  final ValueChanged<int> onAnswer;
  final VoidCallback onNext;
  final VoidCallback onShowResult;

  @override
  Widget build(BuildContext context) {
    final question = session.currentQuestion;

    return ListView(
      children: [
        _ProgressHeader(session: session, strings: strings),
        const SizedBox(height: AppSizes.gapLarge),

        // A gentle cross-fade between questions. Keyed by question index so
        // Flutter knows the content genuinely changed.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: ValueKey(session.currentIndex),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.cardPadding + 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: AppColors.primary, width: 2.5),
            ),
            child: Text(
              question.prompt,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gapLarge),

        for (var index = 0; index < question.options.length; index++) ...[
          _AnswerButton(
            label: question.options[index],
            state: _stateFor(session, question, index),
            onPressed: session.isAnswered ? null : () => onAnswer(index),
          ),
          const SizedBox(height: AppSizes.gap),
        ],

        if (session.isAnswered) ...[
          const SizedBox(height: AppSizes.gapSmall),
          _FeedbackPanel(session: session, strings: strings),
          const SizedBox(height: AppSizes.gap),
          // On the last question this becomes "See result" instead, so the
          // player always sees feedback before the game ends.
          FilledButton.icon(
            onPressed: session.isLastQuestion ? onShowResult : onNext,
            icon: Icon(
              session.isLastQuestion
                  ? Icons.emoji_events_rounded
                  : Icons.arrow_forward_rounded,
              size: AppSizes.iconMedium,
            ),
            label: Text(
              session.isLastQuestion
                  ? strings.seeResult
                  : strings.nextQuestion,
            ),
          ),
        ],
        const SizedBox(height: AppSizes.gapLarge),
      ],
    );
  }

  _AnswerState _stateFor(
    PersonalizedGameSession session,
    QuizQuestion question,
    int index,
  ) {
    if (!session.isAnswered) return _AnswerState.waiting;
    if (index == question.correctIndex) return _AnswerState.correct;
    if (index == session.selectedIndex) return _AnswerState.chosenWrong;
    return _AnswerState.dimmed;
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.session, required this.strings});

  final PersonalizedGameSession session;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          strings.letsRemember,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 21, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        Text(
          '${session.questionNumber} / ${session.totalQuestions}',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            // The bar slides to its new length instead of jumping, which is
            // the one place a small animation genuinely helps: it shows that
            // something moved forward.
            tween: Tween(
              begin: 0,
              end: session.questionNumber / session.totalQuestions,
            ),
            duration: const Duration(milliseconds: 400),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 14,
              backgroundColor: AppColors.background,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _AnswerState { waiting, correct, chosenWrong, dimmed }

/// A very large answer button.
///
/// After answering, the correct option turns green whether or not it was the
/// one chosen — being shown the right answer is the point of the exercise.
/// The wrong choice is outlined in amber, not red, and is never called a
/// failure.
class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.state,
    required this.onPressed,
  });

  final String label;
  final _AnswerState state;
  final VoidCallback? onPressed;

  static const Color _green = Color(0xFF1B5E20);
  static const Color _greenFill = Color(0xFFE3F1E4);

  @override
  Widget build(BuildContext context) {
    final (Color border, Color fill, Color text, IconData? icon) = switch (state) {
      _AnswerState.waiting => (
        AppColors.border,
        AppColors.surface,
        AppColors.textPrimary,
        null,
      ),
      _AnswerState.correct => (
        _green,
        _greenFill,
        _green,
        Icons.check_circle_rounded,
      ),
      _AnswerState.chosenWrong => (
        AppColors.reminder,
        AppColors.surface,
        AppColors.reminder,
        Icons.info_outline_rounded,
      ),
      _AnswerState.dimmed => (
        AppColors.border,
        AppColors.background,
        AppColors.textSecondary,
        null,
      ),
    };

    return Semantics(
      button: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: border, width: 2.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: text,
                    ),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: AppSizes.gapSmall),
                  Icon(icon, size: 30, color: border),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.session, required this.strings});

  final PersonalizedGameSession session;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final correct = session.wasCorrect;
    final color = correct
        ? _AnswerButton._green
        : AppColors.reminder;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  correct
                      ? Icons.celebration_rounded
                      : Icons.favorite_rounded,
                  size: 28,
                  color: color,
                ),
                const SizedBox(width: AppSizes.gapSmall),
                Expanded(
                  child: Text(
                    correct ? strings.greatJob : strings.niceTry,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (!correct) ...[
              const SizedBox(height: AppSizes.gapSmall),
              Text(
                '${strings.theAnswerWas}: '
                '${session.currentQuestion.correctAnswer}',
                style: const TextStyle(
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ result

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.session,
    required this.strings,
    required this.onPlayAgain,
    required this.onBackHome,
  });

  final PersonalizedGameSession session;
  final AppStrings strings;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackHome;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: AppSizes.gap),
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 58,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gapLarge),
        Text(
          strings.wellDone,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: AppSizes.gapSmall),
        Text(
          strings.youCompletedGame,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSizes.gapLarge),

        // "4 / 5" and nothing more. No percentage, no grade, no comparison to
        // last time, and no interpretation of what the number means.
        Center(
          child: Text(
            '${session.correctCount} / ${session.totalQuestions}',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gapSmall),
        Center(
          child: Text(
            strings.activityResult,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gapLarge),

        FilledButton.icon(
          onPressed: onPlayAgain,
          icon: const Icon(Icons.replay_rounded, size: AppSizes.iconMedium),
          label: Text(strings.playAgain),
        ),
        const SizedBox(height: AppSizes.gap),
        OutlinedButton.icon(
          onPressed: onBackHome,
          icon: const Icon(Icons.home_rounded, size: AppSizes.iconMedium),
          label: Text(strings.backToHome),
        ),

        const SizedBox(height: AppSizes.gapLarge),
        _CreatedFromMemoriesNote(strings: strings),
        const SizedBox(height: AppSizes.gapLarge),
      ],
    );
  }
}

/// The line that explains the whole idea of the feature.
class _CreatedFromMemoriesNote extends StatelessWidget {
  const _CreatedFromMemoriesNote({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.favorite_rounded,
            size: 26,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: AppSizes.gapSmall),
          Expanded(
            child: Text(
              strings.createdFromMemories,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- empty state

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.strings, required this.onAddMemories});

  final AppStrings strings;
  final VoidCallback onAddMemories;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: AppSizes.gapLarge),
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: AppColors.memory,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gapLarge),
        Text(
          strings.needMoreMemories,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSizes.gap),
        Text(
          strings.needMoreMemoriesHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSizes.gapLarge),
        FilledButton.icon(
          onPressed: onAddMemories,
          icon: const Icon(Icons.add_rounded, size: AppSizes.iconMedium),
          label: Text(strings.addMemories),
        ),
      ],
    );
  }
}
