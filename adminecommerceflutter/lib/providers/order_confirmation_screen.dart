import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import 'changed_stocks_provider.dart';

class OrderConfirmationScreen extends ConsumerStatefulWidget {
  final Map<int, int> changedStocks;

  const OrderConfirmationScreen({Key? key, required this.changedStocks})
      : super(key: key);

  @override
  ConsumerState<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState
    extends ConsumerState<OrderConfirmationScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  Map<int, Product> _productsMap = {};
  Map<int, bool> _selected = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final ids = widget.changedStocks.keys.toList();
      if (ids.isEmpty) {
        setState(() {
          _loading = false;
          _productsMap = {};
          _selected = {};
        });
        return;
      }

      final orFilter = ids.map((id) => 'id.eq.$id').join(',');

      final data = await _client.from('products').select().or(orFilter);

      final list = List<Map<String, dynamic>>.from(data as List);

      _productsMap = {for (var p in list) p['id'] as int: Product.fromJson(p)};

      _selected = {
        for (var id in widget.changedStocks.keys) id: true,
      };

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _applyChanges() async {
    final toConfirmIds =
        _selected.entries.where((e) => e.value).map((e) => e.key).toList();

    try {
      for (final id in toConfirmIds) {
        final product = _productsMap[id]!;
        final decreaseAmount = widget.changedStocks[id]!;
        final newStock = product.stock - decreaseAmount;

        await _client.from('products').update({'stock': newStock}).eq('id', id);
      }

      ref.read(changedStocksProvider.notifier).clearAll();

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Onaylama hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hata')),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Değişikliklerini Onaylayın'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: _productsMap.entries.map((entry) {
                  final product = entry.value;
                  final decreaseAmount = widget.changedStocks[product.id]!;
                  final newStock = product.stock - decreaseAmount;

                  return CheckboxListTile(
                    value: _selected[product.id],
                    title: Text(product.name),
                    subtitle: Text('Stok: ${product.stock} → $newStock'),
                    onChanged: (val) {
                      setState(() {
                        _selected[product.id] = val ?? false;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            ElevatedButton(
              onPressed: _applyChanges,
              child: const Text('Onayla'),
            ),
          ],
        ),
      ),
    );
  }
}
