import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../resources/resource_providers.dart';
import '../theme/subject_type_style.dart';
import '../wanikani/models/wanikani_assignment.dart';
import '../wanikani/models/wanikani_subject.dart';
import 'pronunciation_audio_button.dart';
import 'subject_character_display.dart';
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
class TermInfoPanel extends ConsumerStatefulWidget {
  const TermInfoPanel({super.key, required this.subject, this.focus});

  final WaniKaniSubject subject;
  final TermInfoFocus? focus;

  @override
  ConsumerState<TermInfoPanel> createState() => _TermInfoPanelState();
}

class _TermInfoPanelState extends ConsumerState<TermInfoPanel> {
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

    final synonyms =
        ref
            .watch(resourceServiceProvider)
            .studyMaterialFor(subject.id)
            ?.meaningSynonyms ??
        const [];

    final sections = <Widget>[
      _AnswerSection(
        subject: subject,
        color: color,
        showMeaning: showMeaning,
        showReading: showReading,
      ),
      if (showMeaning)
        _SynonymsSection(subjectId: subject.id, synonyms: synonyms),
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

/// Displays the user's custom meaning synonyms for a subject, with an inline
/// editor (pencil icon → text fields + Save/Cancel) to add, remove, or change
/// them. Changes are persisted to WaniKani and the local cache via
/// [ResourceService.saveStudyMaterial].
class _SynonymsSection extends ConsumerStatefulWidget {
  const _SynonymsSection({required this.subjectId, required this.synonyms});

  final int subjectId;
  final List<String> synonyms;

  @override
  ConsumerState<_SynonymsSection> createState() => _SynonymsSectionState();
}

class _SynonymsSectionState extends ConsumerState<_SynonymsSection> {
  bool _editing = false;
  bool _saving = false;
  // Owns the currently displayed synonyms so the view updates immediately
  // after a save without waiting for a provider rebuild.
  late List<String> _displayedSynonyms;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _displayedSynonyms = List.of(widget.synonyms);
    _controllers = _buildControllers(_displayedSynonyms);
  }

  @override
  void didUpdateWidget(_SynonymsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New subject (lesson browse): reset entirely from the incoming prop.
    if (oldWidget.subjectId != widget.subjectId) {
      _disposeControllers();
      _displayedSynonyms = List.of(widget.synonyms);
      _controllers = _buildControllers(_displayedSynonyms);
      _editing = false;
      _saving = false;
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  List<TextEditingController> _buildControllers(List<String> synonyms) => [
    for (final s in synonyms) TextEditingController(text: s),
  ];

  void _disposeControllers() {
    for (final c in _controllers) {
      c.dispose();
    }
  }

  void _enterEdit() {
    setState(() {
      _disposeControllers();
      _controllers = _buildControllers(_displayedSynonyms);
      _editing = true;
    });
  }

  void _cancel() {
    setState(() {
      _disposeControllers();
      _controllers = _buildControllers(_displayedSynonyms);
      _editing = false;
    });
  }

  Future<void> _save() async {
    final saved = [
      for (final c in _controllers)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    setState(() => _saving = true);
    try {
      await ref
          .read(resourceServiceProvider)
          .saveStudyMaterial(subjectId: widget.subjectId, synonyms: saved);
      if (mounted) {
        setState(() {
          _displayedSynonyms = saved;
          _editing = false;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtleColor = theme.colorScheme.onSurfaceVariant;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: subtleColor);

    if (!_editing) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_displayedSynonyms.isNotEmpty)
            Expanded(
              child: Text(
                'Custom: ${_displayedSynonyms.join(', ')}',
                style: labelStyle,
              ),
            )
          else
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: 0.45,
                  child: Text('Add answers', style: labelStyle),
                ),
              ),
            ),
          InkWell(
            onTap: _enterEdit,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Opacity(
                opacity: _displayedSynonyms.isEmpty ? 0.45 : 1.0,
                child: Icon(Icons.edit_outlined, size: 14, color: subtleColor),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Custom answers', style: theme.textTheme.labelSmall),
        const SizedBox(height: 8),
        for (var i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controllers[i],
                    style: theme.textTheme.bodySmall,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _controllers[i].dispose();
                    _controllers.removeAt(i);
                  }),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () =>
              setState(() => _controllers.add(TextEditingController())),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: _saving ? null : _cancel,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ],
    );
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
          child: SubjectCharacterDisplay(
            subject: subject,
            size: 28,
            color: Colors.white,
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
