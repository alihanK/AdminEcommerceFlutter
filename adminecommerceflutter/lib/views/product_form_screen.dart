import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/supabase_service.dart';

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => SupabaseService().fetchCategories(),
);

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormScreen({Key? key, this.product}) : super(key: key);

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late String name;
  String? desc;
  late double oldPrice;
  late double newPrice;
  late int stock;
  int? categoryId;

  String? _uploadedImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      name = p.name;
      desc = p.description;
      oldPrice = p.oldPrice;
      newPrice = p.newPrice;
      stock = p.stock;
      categoryId = p.categoryId;
      _uploadedImageUrl = p.imageUrl;
    } else {
      name = '';
      desc = '';
      oldPrice = 0.0;
      newPrice = 0.0;
      stock = 0;
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);
      final url = await SupabaseService().uploadImage(File(picked.path));
      setState(() {
        _uploadedImageUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resim yükleme hatası: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catsAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Yeni Ürün' : 'Ürünü Düzenle'),
      ),
      body: catsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Kategori yükleme hatası: $e')),
        data: (cats) => Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _buildInputCard(
                  title: 'Ürün Bilgileri',
                  children: [
                    _buildFormField(
                      label: 'Ürün Adı',
                      icon: Icons.shopping_bag,
                      initialValue: name,
                      validator: (v) => v!.isEmpty ? 'Lütfen isim girin' : null,
                      onSaved: (v) => name = v!.trim(),
                    ),
                    _buildFormField(
                      label: 'Açıklama',
                      icon: Icons.description,
                      initialValue: desc,
                      maxLines: 3,
                      onSaved: (v) => desc = v?.trim(),
                    ),
                  ],
                ),
                _buildInputCard(
                  title: 'Fiyat Bilgileri',
                  children: [
                    if (widget.product != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'Eski Fiyat',
                              icon: Icons.attach_money,
                              initialValue: oldPrice.toStringAsFixed(2),
                              prefix: '₺',
                              keyboardType: TextInputType.number,
                              validator: (v) => _validatePrice(v),
                              onSaved: (v) => oldPrice = double.parse(v!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFormField(
                              label: 'Yeni Fiyat',
                              icon: Icons.currency_lira,
                              initialValue: newPrice.toStringAsFixed(2),
                              prefix: '₺',
                              keyboardType: TextInputType.number,
                              validator: (v) => _validatePrice(v),
                              onSaved: (v) => newPrice = double.parse(v!),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      _buildFormField(
                        label: 'Yeni Fiyat',
                        icon: Icons.currency_lira,
                        initialValue: newPrice.toStringAsFixed(2),
                        prefix: '₺',
                        keyboardType: TextInputType.number,
                        validator: (v) => _validatePrice(v),
                        onSaved: (v) => newPrice = double.parse(v!),
                      ),
                    ],
                  ],
                ),
                _buildInputCard(
                  title: 'Stok ve Kategori',
                  children: [
                    _buildFormField(
                      label: 'Stok',
                      icon: Icons.inventory,
                      initialValue: stock.toString(),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty || int.tryParse(v) == null
                          ? 'Geçerli bir sayı girin'
                          : null,
                      onSaved: (v) => stock = int.parse(v!),
                    ),
                    const SizedBox(height: 16),
                    _buildCategoryDropdown(cats, theme),
                  ],
                ),
                _buildInputCard(
                  title: 'Ürün Görseli',
                  children: [
                    _buildImageUploadSection(),
                    if (_uploadedImageUrl != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _uploadedImageUrl!,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                _buildSaveButton(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    String? initialValue,
    String? prefix,
    int? maxLines,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          prefixText: prefix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        maxLines: maxLines ?? 1,
        keyboardType: keyboardType,
        validator: validator,
        onSaved: onSaved,
      ),
    );
  }

  Widget _buildCategoryDropdown(List<Category> cats, ThemeData theme) {
    return DropdownButtonFormField<int>(
      value: cats.any((c) => c.id == categoryId) ? categoryId : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Kategori',
        prefixIcon: const Icon(Icons.category, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: cats
          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
          .toList(),
      validator: (v) => v == null ? 'Lütfen kategori seçin' : null,
      onChanged: (v) => setState(() => categoryId = v),
      onSaved: (v) => categoryId = v,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(10),
      hint: const Text('Kategori Seçiniz'),
      icon: const Icon(Icons.arrow_drop_down_circle_outlined),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      children: [
        OutlinedButton.icon(
          icon: _isUploading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload),
          label: Text(_isUploading ? 'Yükleniyor...' : 'Resim Yükle'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue,
            side: const BorderSide(color: Colors.blue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _isUploading ? null : _pickAndUploadImage,
        ),
        if (_uploadedImageUrl == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'JPEG veya PNG (max 800px)',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: _submitForm,
      child: const Text('Ürünü Kaydet', style: TextStyle(fontSize: 16)),
    );
  }

  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) return 'Fiyat girin';
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) return 'Geçerli fiyat girin';
    return null;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _isUploading) return;

    try {
      _formKey.currentState!.save();

      final newProd = Product(
        id: widget.product?.id ?? 0,
        name: name,
        description: desc,
        oldPrice: oldPrice,
        newPrice: newPrice,
        stock: stock,
        categoryId: categoryId!,
        imageUrl: _uploadedImageUrl,
      );

      final svc = SupabaseService();
      if (widget.product == null) {
        await svc.createProduct(newProd);
      } else {
        await svc.updateProduct(newProd);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
