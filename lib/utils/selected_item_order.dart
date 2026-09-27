List<T> selectedItemsLast<T>(
  Iterable<T> items, {
  required bool Function(T item) isSelected,
}) {
  final unselectedItems = <T>[];
  final selectedItems = <T>[];
  for (final item in items) {
    if (isSelected(item)) {
      selectedItems.add(item);
    } else {
      unselectedItems.add(item);
    }
  }
  return [...unselectedItems, ...selectedItems];
}
