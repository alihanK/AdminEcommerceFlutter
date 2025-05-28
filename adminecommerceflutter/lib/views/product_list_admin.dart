import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../models/product.dart';
import 'product_form_screen.dart';

class ProductListAdmin extends ConsumerStatefulWidget {
  const ProductListAdmin({super.key});

  @override
  ConsumerState<ProductListAdmin> createState() => _ProductListAdminState();
}

class _ProductListAdminState extends ConsumerState<ProductListAdmin> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  List<Category> categories = [];
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  int selectedCategoryId = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select('*')
          .order('id', ascending: true);

      setState(() {
        categories = List<Map<String, dynamic>>.from(response)
            .map((json) => Category.fromJson(json))
            .toList();
      });
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('Kategoriler yüklenirken hata oluştu: $error');
      }
    }
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => isLoading = true);

      final response = await supabase
          .from('products')
          .select('*')
          .order('id', ascending: true);

      setState(() {
        products = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
      _filterProducts();
    } catch (error) {
      setState(() => isLoading = false);
      if (mounted) {
        _showErrorSnackBar('Ürünler yüklenirken hata oluştu: $error');
      }
    }
  }

  void _filterProducts() {
    String searchTerm = _searchController.text.toLowerCase();

    setState(() {
      filteredProducts = products.where((product) {
        bool matchesSearch =
            product['name']?.toLowerCase()?.contains(searchTerm) ?? false;
        bool matchesCategory = selectedCategoryId == 0 ||
            product['category_id'] == selectedCategoryId;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _onCategorySelected(int categoryId) {
    setState(() {
      selectedCategoryId = categoryId;
    });
    _filterProducts();
  }

  Future<void> _updateStock(int productId, int newStock) async {
    try {
      await supabase
          .from('products')
          .update({'stock': newStock}).eq('id', productId);

      setState(() {
        final index = products.indexWhere((p) => p['id'] == productId);
        if (index != -1) {
          products[index]['stock'] = newStock;
        }
      });
      _filterProducts();

      if (mounted) {
        _showSuccessSnackBar('Stok başarıyla güncellendi: $newStock');
      }
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('Stok güncellenirken hata oluştu: $error');
      }
    }
  }

  Future<void> _deleteProductAndRelated(int productId) async {
    try {
      await supabase.from('order_items').delete().eq('product_id', productId);
      await supabase.from('cart_items').delete().eq('product_id', productId);
      await supabase.from('products').delete().eq('id', productId);

      setState(() {
        products.removeWhere((p) => p['id'] == productId);
      });
      _filterProducts();

      if (mounted) {
        _showSuccessSnackBar('Ürün başarıyla silindi');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Silme işlemi başarısız: $e');
      }
    }
  }

  void _navigateToEditProduct(Map<String, dynamic> productData) {
    final product = Product(
      id: productData['id'],
      name: productData['name'] ?? '',
      description: productData['description'],
      oldPrice: (productData['old_price'] ?? 0.0).toDouble(),
      newPrice: (productData['new_price'] ?? 0.0).toDouble(),
      stock: productData['stock'] ?? 0,
      categoryId: productData['category_id'],
      imageUrl: productData['image_url'],
    );

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ProductFormScreen(product: product),
          ),
        )
        .then((_) => _loadProducts());
  }

  void _showEditStockDialog(Map<String, dynamic> product) {
    final int originalStock = product['stock'] as int;
    final TextEditingController stockController =
        TextEditingController(text: originalStock.toString());

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2,
                          color: Colors.blue.shade700, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${product['name'] ?? 'Ürün'} - Stok Düzenle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Mevcut Stok: ',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$originalStock',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Yeni Stok Miktarı',
                    prefixIcon: const Icon(Icons.edit),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    hintText: '0',
                  ),
                  onSubmitted: (value) {
                    final newStock = int.tryParse(value);
                    if (newStock != null && newStock >= 0) {
                      _updateStock(product['id'], newStock);
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.cancel),
                        label: const Text('İptal'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Güncelle'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          final newStockText = stockController.text.trim();
                          final newStock = int.tryParse(newStockText);
                          if (newStock != null && newStock >= 0) {
                            _updateStock(product['id'], newStock);
                            Navigator.of(dialogContext).pop();
                          } else {
                            _showErrorSnackBar(
                                'Geçerli bir stok miktarı girin (0 veya pozitif sayı)');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Ürün ara...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCategoryButtons() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCategoryButton(0, 'HEPSİ'),
            const SizedBox(width: 8),
            ...categories.map((category) {
              String displayName = category.name.toUpperCase();
              if (displayName == 'GIDA')
                displayName = 'GIDA';
              else if (displayName == 'TEKNOLOJI')
                displayName = 'TEKNOLOJİ';
              else if (displayName == 'HIJYENIK ÜRÜNLER')
                displayName = 'HİJYENİK ÜRÜNLER';

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildCategoryButton(category.id, displayName),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(int categoryId, String name) {
    bool isSelected = selectedCategoryId == categoryId;

    return GestureDetector(
      onTap: () => _onCategorySelected(categoryId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProducts,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50.withOpacity(0.3),
              Colors.grey.shade100.withOpacity(0.5),
              Colors.white.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildSearchBar(),
            _buildCategoryButtons(),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Ürünler yükleniyor...')
                        ],
                      ),
                    )
                  : filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2,
                                  size: 80, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty ||
                                        selectedCategoryId != 0
                                    ? 'Arama kriterlerine uygun ürün bulunamadı'
                                    : 'Henüz ürün bulunmuyor',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadProducts,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: ListView.builder(
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) =>
                                  _buildProductCard(filteredProducts[index]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(
                  builder: (context) => const ProductFormScreen()))
              .then((_) => _loadProducts());
        },
        icon: const Icon(Icons.add),
        label: const Text('Yeni Ürün'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final screenWidth = MediaQuery.of(context).size.width;
    final stockCount = product['stock'] as int;
    final isLowStock = stockCount <= 5;
    final oldPrice = (product['old_price'] ?? 0.0).toDouble();
    final newPrice = (product['new_price'] ?? 0.0).toDouble();
    final showOldPrice = oldPrice > newPrice;

    // Responsive boyutlar
    final imageSize =
        screenWidth < 400 ? 50.0 : (screenWidth < 600 ? 60.0 : 70.0);
    final titleFontSize =
        screenWidth < 400 ? 13.0 : (screenWidth < 600 ? 14.0 : 15.0);
    final priceFontSize =
        screenWidth < 400 ? 11.0 : (screenWidth < 600 ? 12.0 : 13.0);
    final buttonPadding =
        screenWidth < 400 ? 6.0 : (screenWidth < 600 ? 8.0 : 10.0);
    final cardPadding =
        screenWidth < 400 ? 8.0 : (screenWidth < 600 ? 10.0 : 12.0);

    return Container(
      margin: EdgeInsets.only(bottom: screenWidth < 400 ? 8 : 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.15),
                  Colors.grey.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resim
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: product['image_url'] != null &&
                              product['image_url'].toString().isNotEmpty
                          ? Image.network(
                              product['image_url'],
                              width: imageSize,
                              height: imageSize,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: imageSize,
                                height: imageSize,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.broken_image,
                                  size: imageSize * 0.4,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            )
                          : Container(
                              width: imageSize,
                              height: imageSize,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.image_not_supported,
                                size: imageSize * 0.4,
                                color: Colors.grey.shade600,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(width: cardPadding),

                  // İçerik
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Başlık ve stok
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product['name'] ?? 'İsimsiz Ürün',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: titleFontSize,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: buttonPadding - 2, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLowStock
                                    ? Colors.red.withOpacity(0.2)
                                    : Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isLowStock
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2,
                                    size: 12,
                                    color: isLowStock
                                        ? Colors.red.shade700
                                        : Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$stockCount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: priceFontSize - 1,
                                      color: isLowStock
                                          ? Colors.red.shade700
                                          : Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Açıklama
                        if (product['description'] != null &&
                            product['description'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            product['description'],
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: priceFontSize - 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        const SizedBox(height: 8),

                        // Fiyat
                        Row(
                          children: [
                            if (showOldPrice) ...[
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: buttonPadding - 2, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '₺${oldPrice.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: priceFontSize - 1,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: buttonPadding - 1, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                '₺${newPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: priceFontSize,
                                ),
                              ),
                            ),
                            if (isLowStock) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: buttonPadding - 3, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning,
                                        size: 10, color: Colors.red.shade700),
                                    const SizedBox(width: 2),
                                    Text(
                                      'DÜŞÜK',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: priceFontSize - 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Butonlar
                        Row(
                          children: [
                            _buildCompactButton(
                              icon: Icons.remove,
                              color: Colors.red,
                              enabled: stockCount > 0,
                              size: buttonPadding,
                              onTap: () =>
                                  _updateStock(product['id'], stockCount - 1),
                            ),
                            const SizedBox(width: 6),
                            _buildCompactButton(
                              icon: Icons.add,
                              color: Colors.green,
                              enabled: true,
                              size: buttonPadding,
                              onTap: () =>
                                  _updateStock(product['id'], stockCount + 1),
                            ),
                            const SizedBox(width: 6),
                            _buildCompactButton(
                              icon: Icons.edit,
                              color: Colors.orange,
                              enabled: true,
                              size: buttonPadding,
                              onTap: () => _showEditStockDialog(product),
                            ),
                            const SizedBox(width: 6),
                            _buildCompactButton(
                              icon: Icons.settings,
                              color: Colors.blue,
                              enabled: true,
                              size: buttonPadding,
                              onTap: () => _navigateToEditProduct(product),
                            ),
                            const SizedBox(width: 6),
                            _buildCompactButton(
                              icon: Icons.delete,
                              color: Colors.red,
                              enabled: true,
                              size: buttonPadding,
                              onTap: () => _showDeleteConfirmation(product),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required Color color,
    required bool enabled,
    required double size,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: EdgeInsets.all(size),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? [
                      color.withOpacity(0.15),
                      color.withOpacity(0.05),
                    ]
                  : [
                      Colors.grey.withOpacity(0.1),
                      Colors.grey.withOpacity(0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? color.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: enabled ? color : color.withOpacity(0.5),
            size: size + 4,
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Ürünü Sil'),
          ],
        ),
        content: Text(
          '${product['name']} ürününü silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteProductAndRelated(product['id']);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
