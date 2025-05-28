import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../models/product.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Category>> fetchCategories() async {
    try {
      final data = await _client.from('categories').select().order('id');
      final list = List<Map<String, dynamic>>.from(data as List);
      return list.map(Category.fromJson).toList();
    } catch (e) {
      print('fetchCategories error: $e');
      return [];
    }
  }

  Future<List<Product>> fetchProducts({int? categoryId}) async {
    try {
      var query = _client.from('products').select();

      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      }

      final data = await query.order('id');
      final list = List<Map<String, dynamic>>.from(data as List);
      return list.map(Product.fromJson).toList();
    } catch (e) {
      print('fetchProducts error: $e');
      return [];
    }
  }

  Future<void> createProduct(Product product) async {
    try {
      await _client.from('products').insert(product.toJson());
    } catch (e) {
      print('createProduct error: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      await _client
          .from('products')
          .update(product.toJson())
          .eq('id', product.id);
    } catch (e) {
      print('updateProduct error: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await _client.from('products').delete().eq('id', id);
    } catch (e) {
      print('deleteProduct error: $e');
      rethrow;
    }
  }

  Future<String> uploadImage(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final filePath =
          'product-images/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await _client.storage.from('images').upload(filePath, file);

      final publicUrl = _client.storage.from('images').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      print('uploadImage error: $e');
      rethrow;
    }
  }
}
