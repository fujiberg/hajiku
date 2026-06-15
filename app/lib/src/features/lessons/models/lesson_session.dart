import '../../review/models/review_session.dart';

/// State of a lesson browsing session: the fixed set of items to introduce,
/// and which one is currently shown.
class LessonSessionState {
  const LessonSessionState({required this.items, required this.currentIndex});

  /// The lesson items to browse, in the order they should be presented.
  final List<ReviewItem> items;

  /// The index of the item currently shown.
  final int currentIndex;

  ReviewItem? get current => items.isEmpty ? null : items[currentIndex];

  bool get isFirst => currentIndex == 0;

  bool get isLast => currentIndex == items.length - 1;

  LessonSessionState copyWith({int? currentIndex}) {
    return LessonSessionState(
      items: items,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}
