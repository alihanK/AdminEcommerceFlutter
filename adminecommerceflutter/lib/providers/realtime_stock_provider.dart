import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'changed_stocks_provider.dart';

bool isRevertingStocks = false;

final Map<int, int> previousStocks = {};

final realtimeStockListenerProvider = Provider<RealtimeChannel>((ref) {
  final client = Supabase.instance.client;
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final channelName = 'stock-tracker-$timestamp';

  print('[REALTIME] Kanal oluşturuluyor: $channelName');

  final channel = client.channel(channelName);

  channel
      .onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'products',
    callback: (payload) async {
      try {
        if (isRevertingStocks) {
          print('[REALTIME] Stok revert işlemi nedeniyle event atlandı.');
          return;
        }

        print('[REALTIME] Raw payload: $payload');

        if (payload.newRecord == null) {
          print('[REALTIME] newRecord null!');
          return;
        }

        final newRow = payload.newRecord!;
        final productId = newRow['id'] as int?;
        final newStockRaw = newRow['stock'];

        if (productId == null || newStockRaw == null) {
          print('[REALTIME] Eksik veri: ID=$productId, Stock=$newStockRaw');
          return;
        }

        int currentStock;
        if (newStockRaw is int) {
          currentStock = newStockRaw;
        } else if (newStockRaw is double) {
          currentStock = newStockRaw.toInt();
        } else if (newStockRaw is String) {
          currentStock = int.tryParse(newStockRaw) ?? 0;
        } else {
          print('[REALTIME] Bilinmeyen stok tipi: ${newStockRaw.runtimeType}');
          return;
        }

        int previousStock;
        if (previousStocks.containsKey(productId)) {
          previousStock = previousStocks[productId]!;
        } else {
          if (payload.oldRecord != null &&
              payload.oldRecord!['stock'] != null) {
            final oldStockRaw = payload.oldRecord!['stock'];
            if (oldStockRaw is int) {
              previousStock = oldStockRaw;
            } else if (oldStockRaw is double) {
              previousStock = oldStockRaw.toInt();
            } else if (oldStockRaw is String) {
              previousStock = int.tryParse(oldStockRaw) ?? currentStock;
            } else {
              previousStock = currentStock;
            }
          } else {
            try {
              final response = await client
                  .from('products')
                  .select('stock')
                  .eq('id', productId)
                  .single();

              previousStock = response['stock'] as int;
            } catch (e) {
              print('[REALTIME] Önceki stok alınamadı: $e');
              previousStock = currentStock;
            }
          }

          previousStocks[productId] = previousStock;
        }

        if (previousStock != currentStock) {
          print(
              '[REALTIME] Stok değişimi: ID=$productId, Önce=$previousStock, Yeni=$currentStock');

          ref
              .read(changedStocksProvider.notifier)
              .addChange(productId, previousStock, currentStock);

          previousStocks[productId] = currentStock;
        } else {
          print('[REALTIME] Stok değişmedi: $currentStock');
        }
      } catch (e, stack) {
        print('[REALTIME] Hata: $e');
        print(stack);
      }
    },
  )
      .subscribe((status, [error]) {
    print('[REALTIME] Subscribe durumu: $status');
    if (error != null) {
      print('[REALTIME] Subscribe hatası: $error');
    }
  });

  ref.onDispose(() {
    print('[REALTIME] Channel kapatılıyor: $channelName');
    channel.unsubscribe();
  });

  return channel;
});
