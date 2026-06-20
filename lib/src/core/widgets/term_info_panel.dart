import 'package:flutter/material.dart';

import '../theme/subject_type_style.dart';
import '../wanikani/models/wanikani_assignment.dart';
import '../wanikani/models/wanikani_subject.dart';
import 'pronunciation_audio_button.dart';
import 'wanikani_markup_text.dart';

/// Which half of a [TermInfoPanel] to emphasize, hiding the other half by
/// default (the user can still reveal it with the "Show all" button).
enum TermInfoFocus { meaning, reading }

/// Detailed information about a [WaniKaniSubject]: its meanings and
/// readings, mnemonics, example sentences, and pronunciation audio.
///
/// Shown after an incorrect review answer, and reused on lesson screens. If
/// [focus] is set, information for the other half (meaning vs. reading) is
/// hidden until the user taps "Show all" — useful when only one half of the
/// answer was being tested.
class TermInfoPanel extends StatefulWidget {
  const TermInfoPanel({super.key, required this.subject, this.focus});

  final WaniKaniSubject subject;
  final TermInfoFocus? focus;

  @override
  State<TermInfoPanel> createState() => _TermInfoPanelState();
}

class _TermInfoPanelState extends State<TermInfoPanel> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final focus = _showAll ? null : widget.focus;
    final showMeaning = focus != TermInfoFocus.reading;
    final showReading = focus != TermInfoFocus.meaning;
    final color = subject.type.color;
    final audios = _audiosByVoiceActor(subject.pronunciationAudios);

    // Only offer "Show all" if hiding the other half actually hides
    // something: meanings are always present, but radicals have no readings.
    final canShowAll =
        widget.focus == TermInfoFocus.meaning && subject.readings.isEmpty
        ? false
        : widget.focus != null;

    final sections = <Widget>[
      _AnswerSection(
        subject: subject,
        color: color,
        showMeaning: showMeaning,
        showReading: showReading,
      ),
      if (showReading && audios.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final audio in audios) PronunciationAudioButton(audio: audio),
          ],
        ),
      if (showMeaning && subject.meaningMnemonic != null)
        _MnemonicSection(
          title: 'Meaning mnemonic',
          text: subject.meaningMnemonic!,
        ),
      if (showReading && subject.readingMnemonic != null)
        _MnemonicSection(
          title: 'Reading mnemonic',
          text: subject.readingMnemonic!,
        ),
      if (subject.contextSentences.isNotEmpty)
        _ContextSentencesSection(sentences: subject.contextSentences),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canShowAll)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(_showAll ? 'Show less' : 'Show all'),
                ),
              ),
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              sections[i],
            ],
          ],
        ),
      ),
    );
  }

  /// One audio per voice actor, preferring `audio/mpeg` clips for broad
  /// platform support.
  static List<WaniKaniPronunciationAudio> _audiosByVoiceActor(
    List<WaniKaniPronunciationAudio> audios,
  ) {
    final byActor = <String, WaniKaniPronunciationAudio>{};
    for (final audio in audios) {
      final key = audio.voiceActorName ?? audio.url;
      final existing = byActor[key];
      if (existing == null ||
          (existing.contentType != 'audio/mpeg' &&
              audio.contentType == 'audio/mpeg')) {
        byActor[key] = audio;
      }
    }
    return byActor.values.toList();
  }
}

/// Shows the subject's characters alongside its accepted meanings and
/// readings, with the primary answer emphasized.
class _AnswerSection extends StatelessWidget {
  const _AnswerSection({
    required this.subject,
    required this.color,
    required this.showMeaning,
    required this.showReading,
  });

  final WaniKaniSubject subject;
  final Color color;
  final bool showMeaning;
  final bool showReading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            subject.displayText,
            style: const TextStyle(fontSize: 28, color: Colors.white),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showMeaning)
                _AnswerLine(
                  label: 'Meaning',
                  values: [for (final m in subject.meanings) m.meaning],
                  primary: subject.primaryMeaning,
                  style: style,
                ),
              if (showReading && subject.readings.isNotEmpty) ...[
                if (showMeaning) const SizedBox(height: 4),
                if (subject.type == WaniKaniSubjectType.kanji)
                  _KanjiReadingLines(subject: subject, style: style)
                else
                  _AnswerLine(
                    label: 'Reading',
                    values: [for (final r in subject.readings) r.reading],
                    primary: subject.primaryReading,
                    style: style,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// For kanji, on'yomi and kun'yomi (and nanori, if present) readings shown
/// on separate lines, with the group containing the preferred reading first.
class _KanjiReadingLines extends StatelessWidget {
  const _KanjiReadingLines({required this.subject, this.style});

  final WaniKaniSubject subject;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final groups = <WaniKaniReadingType, List<WaniKaniReading>>{};
    for (final reading in subject.readings) {
      final type = reading.type;
      if (type == null) continue;
      groups.putIfAbsent(type, () => []).add(reading);
    }

    final primaryType = subject.readings
        .firstWhere((r) => r.primary, orElse: () => subject.readings.first)
        .type;

    final order = [
      ?primaryType,
      for (final type in WaniKaniReadingType.values)
        if (type != primaryType) type,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final type in order)
          if (groups[type] case final readings?)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _AnswerLine(
                label: type.label,
                values: [for (final r in readings) r.reading],
                primary: subject.primaryReading,
                style: style,
              ),
            ),
      ],
    );
  }
}

/// A label followed by a list of values, with the primary value emphasized.
class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.values,
    required this.primary,
    this.style,
  });

  final String label;
  final List<String> values;
  final String primary;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.normal),
          ),
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const TextSpan(text: ', '),
            TextSpan(
              text: values[i],
              style: TextStyle(
                fontWeight: values[i] == primary
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MnemonicSection extends StatelessWidget {
  const _MnemonicSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        WaniKaniMarkupText(text: text, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _ContextSentencesSection extends StatelessWidget {
  const _ContextSentencesSection({required this.sentences});

  final List<WaniKaniContextSentence> sentences;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Example sentences', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        for (var i = 0; i < sentences.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Text(sentences[i].japanese, style: theme.textTheme.bodyMedium),
          Text(
            sentences[i].english,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
