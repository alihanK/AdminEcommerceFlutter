import 'package:flutter_riverpod/flutter_riverpod.dart';

class StockChange {
  final int productId;
  final int previousStock;
  final int newStock;
  final DateTime timestamp;

  StockChange({
    required this.productId,
    required this.previousStock,
    required this.newStock,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  StockChange.legacy(this.previousStock, this.newStock)
      : productId = -1,
        timestamp = DateTime.now();

  int get decreaseAmount => previousStock - newStock;

  bool get isDecrease => decreaseAmount > 0;

  bool get isIncrease => decreaseAmount < 0;

  @override
  String toString() {
    return 'StockChange(productId: $productId, previous: $previousStock, new: $newStock, decrease: $decreaseAmount, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockChange &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          previousStock == other.previousStock &&
          newStock == other.newStock;

  @override
  int get hashCode =>
      productId.hashCode ^ previousStock.hashCode ^ newStock.hashCode;
}

final changedStocksProvider =
    StateNotifierProvider<ChangedStocksNotifier, Map<int, StockChange>>(
  (ref) => ChangedStocksNotifier(),
);

class ChangedStocksNotifier extends StateNotifier<Map<int, StockChange>> {
  ChangedStocksNotifier() : super({});

  void addChange(int productId, int previousStock, int newStock) {
    print(
        '[NOTIFIER] Stok değişimi ekleniyor: $productId ($previousStock → $newStock)');

    final change = StockChange(
      productId: productId,
      previousStock: previousStock,
      newStock: newStock,
    );

    _updateState(productId, change);
  }

  void addStockChange(StockChange change) {
    print('[NOTIFIER] StockChange objesi ekleniyor: ${change.productId}');
    print('[NOTIFIER] Change detayı: $change');

    _updateState(change.productId, change);
  }

  void _updateState(int productId, StockChange change) {
    final newState = {...state};
    newState[productId] = change;
    state = newState;

    print('[NOTIFIER] Yeni state: ${state.keys.toList()}');
    print('[NOTIFIER] State uzunluğu: ${state.length}');
    print('[NOTIFIER] Eklenen change: ${state[productId]}');
  }

  void clearAll() {
    print('[NOTIFIER] Tüm değişiklikler temizleniyor (${state.length} adet)');

    if (state.isNotEmpty) {
      print('[NOTIFIER] Temizlenen changes: ${state.values.toList()}');
    }

    state = {};

    print(
        '[NOTIFIER] Temizlik tamamlandı. Yeni state uzunluğu: ${state.length}');
  }

  void removeChange(int productId) {
    if (state.containsKey(productId)) {
      final removedChange = state[productId];
      final newState = {...state};
      newState.remove(productId);
      state = newState;
      print(
          '[NOTIFIER] Ürün $productId değişikliği kaldırıldı: $removedChange');
      print('[NOTIFIER] Kalan değişiklikler: ${state.keys.toList()}');
    } else {
      print('[NOTIFIER] Ürün $productId zaten state\'de yok');
    }
  }

  StockChange? getChange(int productId) {
    return state[productId];
  }

  List<StockChange> getAllChanges() {
    return state.values.toList();
  }

  Map<int, StockChange> getDecreases() {
    return Map.fromEntries(
      state.entries.where((entry) => entry.value.isDecrease),
    );
  }

  Map<int, StockChange> getIncreases() {
    return Map.fromEntries(
      state.entries.where((entry) => entry.value.isIncrease),
    );
  }

  bool get isEmpty => state.isEmpty;
  bool get isNotEmpty => state.isNotEmpty;

  int get changeCount => state.length;

  void printState() {
    print('[NOTIFIER] === STATE DUMP ===');
    print('[NOTIFIER] Total changes: ${state.length}');

    if (state.isEmpty) {
      print('[NOTIFIER] State is empty');
    } else {
      state.forEach((productId, change) {
        print('[NOTIFIER] Product $productId: $change');
      });
    }
    print('[NOTIFIER] === END STATE DUMP ===');
  }

  void resetStocksToPrevious(Map<int, StockChange> previousStocks) {
    state = {...previousStocks};
  }
}
