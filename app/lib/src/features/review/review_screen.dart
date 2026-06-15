import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/romaji/romaji_kana_input_formatter.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/subject_type_style.dart';
import '../../core/wanikani/providers.dart';
import '../../core/widgets/flick_keyboard/flick_kana_keyboard.dart';
import '../../core/widgets/term_info_panel.dart';
import '../settings/settings_screen.dart';
import 'models/review_session.dart';
import 'review_progress.dart';
import 'review_session_controller.dart';

/// Runs a review session: presents one meaning/reading quiz at a time for
/// items currently due, checks the user's typed answer, and reports
/// completed items back to WaniKani.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({
    super.key,
    this.title = 'Reviews',
    this.isLessonQuiz = false,
  });

  /// The app bar title. Defaults to "Reviews"; the lesson quiz reuses this
  /// screen with the title "Lessons" instead.
  final String title;

  /// Whether this is the quiz phase of a lesson session, reached via "Start
  /// quiz" on [LessonScreen]. Lessons quizzed this way have already had their
  /// assignments started on WaniKani, so leaving always warns about losing
  /// progress, regardless of whether any answer has been given yet.
  final bool isLessonQuiz;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  /// Set once the user has confirmed leaving via [_confirmExit], so the
  /// follow-up [Navigator.pop] is allowed through without prompting again.
  bool _confirmedExit = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(reviewSessionControllerProvider);
    final subjectTypeColor = session.value?.current?.item.subject.type.color;
    final needsExitConfirmation = _needsExitConfirmation(session.value);

    return PopScope(
      canPop: _confirmedExit || !needsExitConfirmation,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          ref.invalidate(wanikaniReviewCountProvider);
          ref.invalidate(wanikaniLessonCountProvider);
          ref.invalidate(wanikaniLevelProgressProvider);
          return;
        }
        final confirmed = await _confirmExit(context);
        if (confirmed && context.mounted) {
          setState(() => _confirmedExit = true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: subjectTypeColor,
          foregroundColor: subjectTypeColor != null ? Colors.white : null,
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
            ),
          ],
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

  /// Whether leaving this screen now would discard meaningful progress and
  /// should be confirmed first.
  bool _needsExitConfirmation(ReviewSessionState? session) {
    if (session == null || session.totalItems == 0 || session.isFinished) {
      return false;
    }
    return widget.isLessonQuiz || session.hasCorrectAnswer;
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave session?'),
        content: Text(
          widget.isLessonQuiz
              ? 'These lessons have already started. If you leave now, '
                    'your quiz progress will be lost.'
              : 'Your progress in this session will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result ?? false;
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _romajiFormatter = RomajiKanaInputFormatter();
  late final _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  /// Whether the keyboard shown for the current reading question has been
  /// switched away from the "Flick kana keyboard" setting's default (flick
  /// vs. system). Toggled each time the user dismisses whichever keyboard is
  /// currently shown; reset for each new question.
  bool _readingKeyboardSwapped = false;

  /// The bottom view inset (system keyboard height) as of the last
  /// [didChangeMetrics] call, used to detect when the system keyboard
  /// transitions from open to closed.
  double _lastBottomInset = 0;

  /// Drives the flick keyboard's slide in/out animation. The
  /// [FlickKanaKeyboard] stays mounted at all times, sized via
  /// [SizeTransition] - this keeps a continuous size signal for both
  /// directions, unlike swapping between two different child widgets.
  late final AnimationController _flickKeyboardAnimController;

  /// Whether the flick keyboard was shown as of the last build, used to
  /// detect when to forward/reverse [_flickKeyboardAnimController].
  bool _flickKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flickKeyboardVisible = _computeUseFlickKeyboard();
    _flickKeyboardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _flickKeyboardVisible ? 1 : 0,
    );
    // Requesting focus immediately via `autofocus` can race with the page
    // transition on Android, leaving the field focused internally but
    // without an open keyboard/input connection. Request it after the
    // first frame instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  bool _computeUseFlickKeyboard() {
    final settings = ref.read(settingsControllerProvider).value;
    return widget.session.current?.type == ReviewQuizType.reading &&
        (settings?.flickKeyboardEnabled ?? true) != _readingKeyboardSwapped;
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final bottomInset = View.of(context).viewInsets.bottom;
    final wasOpen = _lastBottomInset > 0;
    _lastBottomInset = bottomInset;

    // Only react to an open-to-closed transition, not to the inset simply
    // being zero (e.g. while it's still animating open).
    if (!wasOpen || bottomInset > 0) return;

    if (widget.session.current?.type != ReviewQuizType.reading) return;
    final settings = ref.read(settingsControllerProvider).value;
    final defaultFlick = settings?.flickKeyboardEnabled ?? true;
    final useFlickKeyboard = defaultFlick != _readingKeyboardSwapped;
    // The system keyboard was showing (either as the default, or because the
    // flick keyboard was dismissed) and was just dismissed itself - switch to
    // the flick keyboard.
    if (useFlickKeyboard) return;
    setState(() => _readingKeyboardSwapped = !_readingKeyboardSwapped);
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
      _readingKeyboardSwapped = false;
      // As in initState, request focus after the field has had a frame to
      // become enabled again, so the keyboard reliably reopens.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    _flickKeyboardAnimController.dispose();
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
      final settings = ref.read(settingsControllerProvider).value;
      final useFlickKeyboard =
          isReading &&
          (settings?.flickKeyboardEnabled ?? true) != _readingKeyboardSwapped;
      final answer = isReading && !useFlickKeyboard
          ? _romajiFormatter.finalize()
          : _controller.text;
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
    final flickKeyboardSubmitEnabled =
        settings?.flickKeyboardSubmitEnabled ?? true;
    final autoAdvanceEnabled = settings?.autoAdvanceEnabled ?? false;
    final useFlickKeyboard =
        quiz.type == ReviewQuizType.reading &&
        (settings?.flickKeyboardEnabled ?? true) != _readingKeyboardSwapped;

    if (useFlickKeyboard != _flickKeyboardVisible) {
      _flickKeyboardVisible = useFlickKeyboard;
      if (useFlickKeyboard) {
        _flickKeyboardAnimController.forward();
      } else {
        _flickKeyboardAnimController.reverse();
      }
    }

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
                          readOnly: useFlickKeyboard,
                          showCursor: useFlickKeyboard ? true : null,
                          keyboardType: useFlickKeyboard
                              ? TextInputType.none
                              : null,
                          autocorrect: false,
                          enableSuggestions: false,
                          inputFormatters:
                              quiz.type == ReviewQuizType.reading &&
                                  !useFlickKeyboard
                              ? [_romajiFormatter]
                              : null,
                          textAlign: TextAlign.center,
                          textInputAction: keyboardSubmitEnabled
                              ? TextInputAction.done
                              : TextInputAction.newline,
                          style: const TextStyle(fontSize: 28),
                          onSubmitted: keyboardSubmitEnabled
                              ? (_) => _submit()
                              : null,
                          // Without this, the default behavior for a
                          // non-multiline field is to close the keyboard on
                          // Enter even when onSubmitted is null.
                          onEditingComplete: keyboardSubmitEnabled
                              ? null
                              : () {},
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
        SizeTransition(
          alignment: Alignment.topCenter,
          sizeFactor: _flickKeyboardAnimController,
          child: FlickKanaKeyboard(
            controller: _controller,
            enabled: useFlickKeyboard && feedback == null,
            onSubmit: flickKeyboardSubmitEnabled ? _submit : null,
            onCollapse: () {
              _focusNode.unfocus();
              setState(
                () => _readingKeyboardSwapped = !_readingKeyboardSwapped,
              );
              // As in initState, request focus after a frame so the
              // system keyboard reliably opens once the field is no
              // longer read-only.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _focusNode.requestFocus();
              });
            },
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
