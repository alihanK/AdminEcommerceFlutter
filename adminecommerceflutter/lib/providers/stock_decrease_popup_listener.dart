import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../providers/changed_stocks_provider.dart';

class StockDecreasePopupListener extends ConsumerStatefulWidget {
  final Widget child;
  const StockDecreasePopupListener({Key? key, required this.child})
      : super(key: key);

  @override
  ConsumerState<StockDecreasePopupListener> createState() =>
      _StockDecreasePopupListenerState();
}

class _StockDecreasePopupListenerState
    extends ConsumerState<StockDecreasePopupListener> {
  bool _isDialogOpen = false;
  Map<int, int> _lastKnownStocks = {};
  bool _isInitialized = false;
  Timer? _stockCheckTimer;
  Timer? _dialogDelayTimer;
  StreamSubscription? _realtimeSubscription;
  DateTime? _lastSyncTimestamp;

  @override
  void initState() {
    super.initState();
    _initializeStockTracking();
  }

  Future<void> _initializeStockTracking() async {
    try {
      await _performFullSync();

      await Future.delayed(const Duration(seconds: 2));

      _isInitialized = true;

      debugPrint(
          ' İlk senkronizasyon tamamlandı: ${_lastKnownStocks.length} ürün');

      _startRealtimeListener();

      _startPeriodicStockCheck();

      debugPrint(
          ' Stok takibi başlatıldı - Son senkronizasyon: $_lastSyncTimestamp');
    } catch (e) {
      debugPrint(' Stok takibi başlatma hatası: $e');
    }
  }

  Future<void> _performFullSync() async {
    final client = Supabase.instance.client;

    try {
      final response =
          await client.from('products').select('id, stock').order('id');

      debugPrint('📊 Full sync: ${response.length} ürün stok bilgisi alındı');

      _lastKnownStocks.clear();
      for (final item in response) {
        final productId = item['id'] as int;
        final stock = item['stock'] as int;
        _lastKnownStocks[productId] = stock;
      }

      _lastSyncTimestamp = DateTime.now();
      debugPrint(
          ' _lastKnownStocks güncellendi: ${_lastKnownStocks.length} ürün');
    } catch (e) {
      debugPrint(' Full sync hatası: $e');
      _lastSyncTimestamp = DateTime.now();
    }
  }

  Future<void> _performIncrementalSync() async {
    final client = Supabase.instance.client;

    try {
      List<dynamic> recentChanges;

      try {
        final cutoffTime = _lastSyncTimestamp ??
            DateTime.now().subtract(const Duration(hours: 1));

        recentChanges = await client
            .from('products')
            .select('id, stock, updated_at')
            .gte('updated_at', cutoffTime.toIso8601String())
            .order('updated_at', ascending: false)
            .limit(1000);

        debugPrint(
            '📈 Incremental sync (updated_at): ${recentChanges.length} değişiklik');
      } catch (e) {
        debugPrint(' updated_at kolunu yok, full sync yapılıyor: $e');
        recentChanges =
            await client.from('products').select('id, stock').order('id');
        debugPrint(
            ' Incremental sync (full fallback): ${recentChanges.length} ürün');
      }

      Map<int, StockChange> detectedChanges = {};

      for (final item in recentChanges) {
        final productId = item['id'] as int;
        final currentStock = item['stock'] as int;
        final previousStock = _lastKnownStocks[productId];

        if (previousStock != null && previousStock != currentStock) {
          detectedChanges[productId] = StockChange(
            productId: productId,
            previousStock: previousStock,
            newStock: currentStock,
          );

          debugPrint(
              ' Incremental değişiklik: Ürün $productId ($previousStock → $currentStock)');
        }

        _lastKnownStocks[productId] = currentStock;
      }

      if (detectedChanges.isNotEmpty) {
        debugPrint(
            ' ${detectedChanges.length} incremental değişiklik provider\'a ekleniyor');
        _addChangesToProvider(detectedChanges);
      }

      _lastSyncTimestamp = DateTime.now();
    } catch (e) {
      debugPrint(' Incremental sync hatası: $e');
    }
  }

  void _startPeriodicStockCheck() {
    _stockCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (!_isDialogOpen && _isInitialized) {
        debugPrint(' Periyodik incremental sync başlıyor...');
        _performIncrementalSync();
      }
    });
    debugPrint(' Periyodik incremental sync başlatıldı (2 dakika aralık)');
  }

  void _startRealtimeListener() {
    try {
      final client = Supabase.instance.client;

      _realtimeSubscription =
          client.from('products').stream(primaryKey: ['id']).listen((data) {
        debugPrint(' Realtime veri alındı: ${data.length} kayıt');
        _handleRealtimeStockChanges(data);
      });

      debugPrint(' Realtime listener başlatıldı');
    } catch (e) {
      debugPrint(' Realtime listener hatası: $e');
    }
  }

  void _handleRealtimeStockChanges(List<Map<String, dynamic>> data) {
    if (!_isInitialized || _isDialogOpen) {
      debugPrint(
          'Realtime işlem atlandı - initialized: $_isInitialized, dialog: $_isDialogOpen');
      return;
    }

    Map<int, StockChange> detectedChanges = {};
    int totalProductsInData = data.length;
    int productsWithPreviousStock = 0;

    for (final item in data) {
      final productId = item['id'] as int;
      final currentStock = item['stock'] as int;
      final previousStock = _lastKnownStocks[productId];

      if (previousStock != null) {
        productsWithPreviousStock++;

        if (previousStock != currentStock) {
          detectedChanges[productId] = StockChange(
            productId: productId,
            previousStock: previousStock,
            newStock: currentStock,
          );

          debugPrint(
              ' REALTIME DEĞIŞIKLIK BULUNDU: Ürün $productId ($previousStock → $currentStock)');
        }
      } else {
        debugPrint(
            ' Ürün $productId için önceki stok bilgisi yok - ilk kez görülüyor');
      }

      _lastKnownStocks[productId] = currentStock;
    }

    debugPrint(
        ' Realtime veri analizi: ${totalProductsInData} toplam ürün, ${productsWithPreviousStock} önceki stoklu, ${detectedChanges.length} değişiklik');

    if (productsWithPreviousStock < (totalProductsInData * 0.8) &&
        detectedChanges.length < 3) {
      debugPrint(
          ' Erken realtime verisi tespit edildi - popup gösterilmiyor (${productsWithPreviousStock}/${totalProductsInData} ürün hazır)');
      return;
    }

    if (detectedChanges.isNotEmpty) {
      debugPrint(
          '🚨 ${detectedChanges.length} REALTIME değişiklik provider\'a ekleniyor!');
      _addChangesToProvider(detectedChanges);
    } else {
      debugPrint(' Realtime verilerinde değişiklik bulunamadı');
    }
  }

  void _addChangesToProvider(Map<int, StockChange> changes) {
    final notifier = ref.read(changedStocksProvider.notifier);

    debugPrint(' Provider\'a ${changes.length} değişiklik ekleniyor:');

    for (final change in changes.values) {
      notifier.addStockChange(change);
      debugPrint(
          '  ➤ Ürün ${change.productId}: ${change.previousStock} → ${change.newStock} ${change.isDecrease ? '(AZALMA ⬇️)' : '(ARTMA ⬆️)'}');
    }

    final totalInProvider = ref.read(changedStocksProvider).length;
    debugPrint(' Provider\'daki toplam değişiklik: $totalInProvider');
  }

  void _scheduleDialogDisplay() {
    // Eğer zaten bir timer varsa iptal et
    _dialogDelayTimer?.cancel();

    // 1 saniye bekle ve sonra dialog göster
    _dialogDelayTimer = Timer(const Duration(seconds: 1), () {
      final changedStocks = ref.read(changedStocksProvider);

      if (changedStocks.isNotEmpty && !_isDialogOpen) {
        _showDialogNow(changedStocks);
      }
    });
  }

  void _showDialogNow(Map<int, StockChange> changedStocks) {
    _isDialogOpen = true;
    debugPrint('🎉 DIALOG AÇILIYOR - ${changedStocks.length} değişiklik var!');

    // Provider'daki tüm değişiklikleri logla
    changedStocks.forEach((productId, change) {
      debugPrint(
          '  📋 Provider\'da: Ürün $productId: ${change.previousStock} → ${change.newStock}');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final result = await _showStockChangeDialog(changedStocks);

        if (result != null) {
          if (result.rejectedIds.isNotEmpty) {
            await _revertStocks(result.rejectedIds, changedStocks);
          }
          ref.read(changedStocksProvider.notifier).clearAll();
          debugPrint(' Dialog kapandı ve değişiklikler temizlendi');
        }
      } catch (e) {
        debugPrint(' Stok değişiklik dialog hatası: $e');
      } finally {
        _isDialogOpen = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final changedStocks = ref.watch(changedStocksProvider);

    debugPrint(
        '🔄 Build çağrıldı - Provider\'da ${changedStocks.length} değişiklik var');

    if (changedStocks.isNotEmpty && !_isDialogOpen) {
      _scheduleDialogDisplay();
    }

    return Scaffold(
      body: widget.child,
      floatingActionButton: changedStocks.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                if (!_isDialogOpen) {
                  _showDialogNow(changedStocks);
                }
              },
              icon: const Icon(Icons.inventory_2),
              label: Text('Stok Değişiklikleri (${changedStocks.length})'),
              backgroundColor: Colors.orange,
            )
          : null,
    );
  }

  Future<StockChangeResult?> _showStockChangeDialog(
      Map<int, StockChange> changedStocks) async {
    final client = Supabase.instance.client;

    try {
      final productIds = changedStocks.keys.toList();

      final productsData = await client
          .from('products')
          .select()
          .filter('id', 'in', '(${productIds.join(',')})');

      final List<dynamic> rawList = productsData as List<dynamic>;
      final products = rawList.map((json) => Product.fromJson(json)).toList();

      if (products.isEmpty) {
        return null;
      }

      for (final product in products) {
        final change = changedStocks[product.id];
        if (change != null) {}
      }

      return showDialog<StockChangeResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _StockChangeDialog(
          products: products,
          changedStocks: changedStocks,
        ),
      );
    } catch (e) {
      debugPrint(' Dialog gösterme hatası: $e');
      return null;
    }
  }

  Future<void> _revertStocks(
      Set<int> productIds, Map<int, StockChange> changedStocks) async {
    final client = Supabase.instance.client;

    for (final id in productIds) {
      final previousStock = changedStocks[id]?.previousStock;
      if (previousStock != null) {
        await client
            .from('products')
            .update({'stock': previousStock}).eq('id', id);

        _lastKnownStocks[id] = previousStock;
      }
    }
  }

  @override
  void dispose() {
    _stockCheckTimer?.cancel();
    _dialogDelayTimer?.cancel();
    _realtimeSubscription?.cancel();
    _lastKnownStocks.clear();
    super.dispose();
  }
}

class StockChangeResult {
  final Set<int> approvedIds;
  final Set<int> rejectedIds;

  StockChangeResult({
    required this.approvedIds,
    required this.rejectedIds,
  });
}

class _StockChangeDialog extends StatefulWidget {
  final List<Product> products;
  final Map<int, StockChange> changedStocks;

  const _StockChangeDialog({
    required this.products,
    required this.changedStocks,
  });

  @override
  State<_StockChangeDialog> createState() => _StockChangeDialogState();
}

class _StockChangeDialogState extends State<_StockChangeDialog> {
  final Map<int, bool> _selections = {};
  final Map<int, TextEditingController> _stockControllers = {};
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    for (final product in widget.products) {
      _selections[product.id] = true;
      final change = widget.changedStocks[product.id];
      _stockControllers[product.id] = TextEditingController(
        text: change?.newStock.toString() ?? '0',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      for (final product in widget.products) {
        _selections[product.id] = _selectAll;
      }
    });
  }

  void _toggleSelection(int productId) {
    setState(() {
      _selections[productId] = !(_selections[productId] ?? false);
      _selectAll = _selections.values.every((selected) => selected);
    });
  }

  int get _selectedCount =>
      _selections.values.where((selected) => selected).length;

  Future<void> _updateStockManually(int productId, int newStock) async {
    final client = Supabase.instance.client;

    try {
      await client
          .from('products')
          .update({'stock': newStock}).eq('id', productId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stok güncelleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.inventory_2, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            'Stok Değişiklikleri (${widget.products.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.products.length}',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _selectAll,
                    onChanged: (_) => _toggleSelectAll(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Text(
                    'Tümünü Seç/Bırak',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_selectedCount seçili',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.products.length,
                  itemBuilder: (context, index) {
                    final product = widget.products[index];
                    final change = widget.changedStocks[product.id];
                    final isSelected = _selections[product.id] ?? false;
                    final controller = _stockControllers[product.id]!;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) =>
                                      _toggleSelection(product.id),
                                ),
                                Expanded(
                                  child: Text(
                                    product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color:
                                      isSelected ? Colors.green : Colors.grey,
                                ),
                              ],
                            ),
                            if (change != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Eski: ${change.previousStock}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 16),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: change.isDecrease
                                          ? Colors.red.shade100
                                          : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Tespit Edilen: ${change.newStock}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: change.isDecrease
                                            ? Colors.red.shade700
                                            : Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'Manuel Düzenleme: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      controller: controller,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        border: OutlineInputBorder(),
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final newStock =
                                          int.tryParse(controller.text);
                                      if (newStock != null && newStock >= 0) {
                                        await _updateStockManually(
                                            product.id, newStock);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${product.name} stoku ${newStock} olarak güncellendi',
                                              ),
                                              backgroundColor: Colors.green,
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      } else {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Geçerli bir stok miktarı girin'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                    ),
                                    child: const Text(
                                      'Güncelle',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.cancel, color: Colors.grey),
          label: const Text('İptal'),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        TextButton.icon(
          icon: const Icon(Icons.block, color: Colors.red),
          label: const Text('Hepsini Reddet'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          onPressed: () async {
            final allProductIds = widget.products.map((p) => p.id).toSet();

            for (final id in allProductIds) {
              final previousStock = widget.changedStocks[id]?.previousStock;
              if (previousStock != null) {
                await client
                    .from('products')
                    .update({'stock': previousStock}).eq('id', id);
              }
            }

            Navigator.of(context).pop(StockChangeResult(
              approvedIds: {},
              rejectedIds: allProductIds,
            ));
          },
        ),
        if (_selectedCount < widget.products.length && _selectedCount > 0)
          TextButton.icon(
            icon: const Icon(Icons.undo, color: Colors.orange),
            label: Text('Seçilenleri Reddet ($_selectedCount)'),
            onPressed: () async {
              final selectedIds = _selections.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toSet();

              for (final id in selectedIds) {
                final previousStock = widget.changedStocks[id]?.previousStock;
                if (previousStock != null) {
                  await client
                      .from('products')
                      .update({'stock': previousStock}).eq('id', id);
                }
              }

              Navigator.of(context).pop(StockChangeResult(
                approvedIds: {},
                rejectedIds: selectedIds,
              ));
            },
          ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: Text('Seçilenleri Onayla ($_selectedCount)'),
          onPressed: _selectedCount > 0
              ? () {
                  final selectedIds = _selections.entries
                      .where((entry) => entry.value)
                      .map((entry) => entry.key)
                      .toSet();

                  final rejectedIds = _selections.entries
                      .where((entry) => !entry.value)
                      .map((entry) => entry.key)
                      .toSet();

                  Navigator.of(context).pop(StockChangeResult(
                    approvedIds: selectedIds,
                    rejectedIds: rejectedIds,
                  ));
                }
              : null,
        ),
      ],
    );
  }
}
