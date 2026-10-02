/// Simple pagination value objects.
///
/// Every list query in the data layer is bounded by `LIMIT` / `OFFSET` and an
/// index-friendly `ORDER BY` (docs/ARCHITECTURE-v0.1.md §9.8, NFR-11). Repositories
/// return [PagedList] so callers can render "load more" without scanning the
/// whole table.
library;

/// An immutable page of results plus the total row count.
class PagedList<T> {
  const PagedList({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  /// The items on this page.
  final List<T> items;

  /// Total number of rows matching the query (ignoring the page window).
  final int total;

  /// Page size that was requested.
  final int limit;

  /// Offset that was requested.
  final int offset;

  /// Whether more rows exist after this page.
  bool get hasMore => offset + items.length < total;

  /// Whether the page is empty.
  bool get isEmpty => items.isEmpty;

  /// An empty page (used for early returns).
  static PagedList<T> empty<T>({int limit = 0, int offset = 0}) =>
      PagedList<T>(
        items: const <Never>[],
        total: 0,
        limit: limit,
        offset: offset,
      );
}
