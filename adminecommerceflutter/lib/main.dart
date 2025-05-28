import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/realtime_stock_provider.dart' as realtime_provider;
import 'providers/stock_decrease_popup_listener.dart';
import 'utils/constants.dart';
import 'views/product_list_admin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(realtime_provider.realtimeStockListenerProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StockDecreasePopupListener(
        child: ProductListAdmin(),
      ),
    );
  }
}
