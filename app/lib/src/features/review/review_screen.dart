import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/romaji/romaji_kana_input_formatter.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/subject_type_style.dart';
import '../../core/wanikani/providers.dart';
import '../../core/widgets/term_info_panel.dart';
import 'models/review_session.dart';
import 'review_progress.dart';
import 'review_session_controller.dart';

/// Runs a review session: presents one meaning/reading quiz at a time for
/// items currently due, checks the user's typed answer, and reports
/// completed items back to WaniKani.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(reviewSessionControllerProvider);
    final subjectTypeColor = session.value?.current?.item.subject.type.color;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        ref.invalidate(wanikaniReviewCountProvider);
        ref.invalidate(wanikaniLevelProgressProvider);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reviews'),
          backgroundColor: subjectTypeColor,
          foregroundColor: subjectTypeColor != null ? Colors.white : null,
        ),
        body: session.when(
          data: (session) {
            if (session.totalItems == 0) return const _EmptyState();
            if (session.isFinished) {
              return _SessionSummary(itemCount: session.totalItems);
            }
            return _QuizBody(session: session);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Failed to load reviews: $error')),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No reviews available right now.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Session complete!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('Reviewed $itemCount item${itemCount == 1 ? '' : 's'}.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reasons a typed answer can't be submitted, distinct from it simply being
/// incorrect.
enum _InputValidationError { empty }

/// Returns why [input] can't be submitted, or `null` if it's valid.
_InputValidationError? _validateInput(String input) {
  if (input.trim().isEmpty) return _InputValidationError.empty;
  return null;
}

/// Shows the current quiz and its answer input.
class _QuizBody extends ConsumerStatefulWidget {
  const _QuizBody({required this.session});

  final ReviewSessionState session;

  @override
  ConsumerState<_QuizBody> createState() => _QuizBodyState();
}

class _QuizBodyState extends ConsumerState<_QuizBody>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _romajiFormatter = RomajiKanaInputFormatter();
  late final _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void initState() {
    super.initState();
    // Requesting focus immediately via `autofocus` can race with the page
    // transition on Android, leaving the field focused internally but
    // without an open keyboard/input connection. Request it after the
    // first frame instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(_QuizBody oldWidget) {
    super.didUpdateWidget(oldWidget);

    final feedback = widget.session.feedback;
    if (oldWidget.session.feedback == null && feedback != null) {
      _onFeedback(feedback);
    } else if (oldWidget.session.feedback != null && feedback == null) {
      _controller.clear();
      _romajiFormatter.reset();
      // As in initState, request focus after the field has had a frame to
      // become enabled again, so the keyboard reliably reopens.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onFeedback(ReviewAnswerFeedback feedback) {
    final settings = ref.read(settingsControllerProvider).value;
    if (settings?.hapticFeedbackEnabled ?? true) {
      if (feedback.correct) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    }

    if (feedback.correct && (settings?.autoAdvanceEnabled ?? false)) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.read(reviewSessionControllerProvider.notifier).next();
        }
      });
    }
  }

  void _submit() {
    final controller = ref.read(reviewSessionControllerProvider.notifier);
    if (widget.session.feedback == null) {
      final isReading = widget.session.current!.type == ReviewQuizType.reading;
      final answer = isReading ? _romajiFormatter.finalize() : _controller.text;
      if (_validateInput(answer) != null) {
        _onInvalidInput();
        return;
      }
      if (answer != _controller.text) {
        _controller.text = answer;
      }
      controller.submitAnswer(answer);
    } else {
      controller.next();
    }
  }

  void _onInvalidInput() {
    _shakeController.forward(from: 0);
    final settings = ref.read(settingsControllerProvider).value;
    if (settings?.invalidInputHapticFeedbackEnabled ?? true) {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final quiz = session.current!;
    final feedback = session.feedback;
    final subject = quiz.item.subject;
    final color = subject.type.color;
    final showQuizTypeBar = subject.readings.isNotEmpty;
    final settings = ref.watch(settingsControllerProvider).value;
    final keyboardSubmitEnabled = settings?.keyboardSubmitEnabled ?? true;
    final autoAdvanceEnabled = settings?.autoAdvanceEnabled ?? false;

    return Column(
      children: [
        _ReviewProgressBar(session: session, backgroundColor: color),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height * 0.22,
                  color: color,
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                subject.type.shortLabel.toUpperCase(),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                subject.displayText,
                                style: const TextStyle(
                                  fontSize: 64,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Always reserved, even when empty, so the box (and
                      // everything below it) stays the same height whether
                      // or not this quiz has a reading.
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(60, 0, 60, 8),
                        decoration: BoxDecoration(
                          color: !showQuizTypeBar
                              ? color
                              : (quiz.type == ReviewQuizType.reading
                                        ? Colors.white
                                        : Colors.black)
                                    .withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Text(
                            showQuizTypeBar
                                ? quiz.type.label.toUpperCase()
                                : '',
                            style: TextStyle(
                              color: quiz.type == ReviewQuizType.reading
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          final progress = _shakeController.value;
                          final offset =
                              sin(progress * pi * 8) * 8 * (1 - progress);
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          enabled: feedback == null,
                          autocorrect: false,
                          enableSuggestions: false,
                          inputFormatters: quiz.type == ReviewQuizType.reading
                              ? [_romajiFormatter]
                              : null,
                          textAlign: TextAlign.center,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(fontSize: 28),
                          onSubmitted: keyboardSubmitEnabled
                              ? (_) => _submit()
                              : null,
                          decoration: InputDecoration(
                            border: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: color),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: switch (feedback) {
                              null => color,
                              ReviewAnswerFeedback(correct: true) =>
                                Colors.green,
                              ReviewAnswerFeedback(correct: false) =>
                                Colors.red,
                            },
                            disabledBackgroundColor: feedback?.correct ?? false
                                ? Colors.green
                                : null,
                            disabledForegroundColor: feedback?.correct ?? false
                                ? Colors.white
                                : null,
                          ),
                          onPressed:
                              (feedback?.correct ?? false) && autoAdvanceEnabled
                              ? null
                              : _submit,
                          child: Text(switch (feedback) {
                            null => 'Submit',
                            ReviewAnswerFeedback(correct: true) =>
                              autoAdvanceEnabled ? 'Correct' : 'Correct - Next',
                            ReviewAnswerFeedback(correct: false) =>
                              'Incorrect - Next',
                          }),
                        ),
                      ),
                      if (feedback != null && !feedback.correct) ...[
                        const SizedBox(height: 16),
                        TermInfoPanel(
                          subject: subject,
                          focus: quiz.type == ReviewQuizType.meaning
                              ? TermInfoFocus.meaning
                              : TermInfoFocus.reading,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A segmented progress bar laid out in the order quizzes will be
/// encountered: one "dash" per review item, split into two glued halves for
/// items that need both a meaning and a reading quiz. Each segment's color
/// reflects that quiz's state (untouched, current, correct, or incorrect).
class _ReviewProgressBar extends StatelessWidget {
  const _ReviewProgressBar({
    required this.session,
    required this.backgroundColor,
  });

  final ReviewSessionState session;

  /// Fills the bar's transparent segments and gaps, matching the subject
  /// color shown in the app bar above.
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final groups = buildProgressGroups(session.initialQueue);

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: Row(
                  children: [
                    for (final quiz in groups[i])
                      Expanded(
                        child: _ProgressSegment(
                          color: progressSegmentColor(
                            session,
                            quiz.item,
                            quiz.type,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single rounded segment of the [_ReviewProgressBar].
class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: color == Colors.white
            ? Border.all(color: Colors.black26)
            : null,
      ),
    );
  }
}
