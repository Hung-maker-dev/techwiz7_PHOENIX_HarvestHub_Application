import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_exception.dart';
import '../../data/api/farmer_products_api.dart';
import '../../models/product.dart';
import '../../providers/farmer_products_provider.dart';

/// Form thêm/sửa sản phẩm — route `/farmer/products/new` (thêm) và
/// `/farmer/products/:id/edit` (sửa, [productId] khác null).
/// Trả về `true` qua `Navigator.pop` khi lưu thành công để FarmerHomePage
/// biết cần refetch danh sách.
///
/// "Hết hàng" KHÔNG phải lựa chọn farmer tự chọn — nó tự động khi stock = 0
/// (xem ProductStatus). Ở đây farmer chỉ chỉnh Đang bán/Đã ẩn (is_active).
class FarmerProductFormPage extends ConsumerStatefulWidget {
  final String? productId;

  const FarmerProductFormPage({super.key, this.productId});

  bool get isEditing => productId != null;

  @override
  ConsumerState<FarmerProductFormPage> createState() =>
      _FarmerProductFormPageState();
}

class _FarmerProductFormPageState extends ConsumerState<FarmerProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  String? _currentImageUrl;

  String? _categoryId;
  bool _isActive = true;
  bool _submitting = false;
  bool _loadedExisting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() {
      _pickedImage = pickedFile;
      _currentImageUrl = pickedFile.path;
    });
  }

  void _fillFrom(Product product) {
    _nameController.text = product.name;
    _priceController.text = product.price.toString();
    _unitController.text = product.unit;
    _stockController.text = product.stock.toString();
    _minStockController.text = product.minStock.toString();
    _descriptionController.text = product.description ?? '';
    _currentImageUrl = product.imageUrl;
    _categoryId = product.categoryId;
    _isActive = product.isActive;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final api = ref.read(farmerProductsApiProvider);
    final name = _nameController.text.trim();
    final unit = _unitController.text.trim();
    final price = double.parse(_priceController.text.trim());
    final stock = int.parse(_stockController.text.trim());
    final minStock = int.parse(_minStockController.text.trim());
    final imageUrl = (_pickedImage == null ? _currentImageUrl : null)?.trim();
    final description = _descriptionController.text.trim();

    try {
      if (widget.isEditing) {
        await api.updateProduct(
          widget.productId!,
          name: name,
          categoryId: _categoryId,
          unit: unit,
          price: price,
          stock: stock,
          minStock: minStock,
          imageUrl: imageUrl?.isEmpty == true ? null : imageUrl,
          imageFile: _pickedImage,
          description: description,
          isActive: _isActive,
        );
      } else {
        await api.createProduct(
          name: name,
          categoryId: _categoryId!,
          unit: unit,
          price: price,
          stock: stock,
          minStock: minStock,
          imageUrl: imageUrl?.isEmpty == true ? null : imageUrl,
          imageFile: _pickedImage,
          description: description.isEmpty ? null : description,
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      final productAsync =
          ref.watch(farmerProductDetailProvider(widget.productId!));
      return productAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Sửa sản phẩm')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Sửa sản phẩm')),
          body: Center(
            child: Text(
              error is ApiException
                  ? error.message
                  : 'Không tải được sản phẩm.',
            ),
          ),
        ),
        data: (product) {
          if (!_loadedExisting) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _loadedExisting) return;
              _fillFrom(product);
              setState(() => _loadedExisting = true);
            });
          }
          return _buildForm(title: 'Sửa sản phẩm');
        },
      );
    }
    return _buildForm(title: 'Thêm sản phẩm');
  }

  Widget _buildImagePreview(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_outlined, size: 36),
        ),
      );
    }

    return Image.file(
      File(imageUrl),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_outlined, size: 36),
      ),
    );
  }

  Widget _buildForm({required String title}) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tên sản phẩm *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bắt buộc nhập' : null,
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                error is ApiException
                    ? error.message
                    : 'Không tải được danh mục.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (categories) {
                if (categories.isEmpty) {
                  return DropdownButtonFormField<String>(
                    value: null,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục *',
                      helperText: 'Chưa có danh mục nào trong hệ thống.',
                    ),
                    items: const [],
                    onChanged: null,
                    validator: (_) => 'Chưa có danh mục nào để chọn',
                  );
                }

                final validCategories = categories
                    .where((category) => category.id.isNotEmpty)
                    .toList();
                final hasCurrent = _categoryId != null &&
                    validCategories
                        .any((category) => category.id == _categoryId);
                if (_categoryId == null && validCategories.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _categoryId == null) {
                      setState(() => _categoryId = validCategories.first.id);
                    }
                  });
                }

                return DropdownButtonFormField<String>(
                  value: hasCurrent ? _categoryId : null,
                  decoration: const InputDecoration(labelText: 'Danh mục *'),
                  items: validCategories
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (v) => v == null ? 'Vui lòng chọn danh mục' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Giá (đ) *'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final value = double.tryParse((v ?? '').trim());
                      if (value == null || value <= 0) {
                        return 'Giá phải > 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                        labelText: 'Đơn vị * (kg, bó...)'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(labelText: 'Tồn kho'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final value = int.tryParse((v ?? '').trim());
                      if (value == null || value < 0) {
                        return 'Không hợp lệ';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minStockController,
                    decoration: const InputDecoration(
                      labelText: 'Ngưỡng cảnh báo',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final value = int.tryParse((v ?? '').trim());
                      if (value == null || value < 0) {
                        return 'Không hợp lệ';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _pickedImage != null || (_currentImageUrl ?? '').isNotEmpty
                  ? _buildImagePreview(_pickedImage?.path ?? _currentImageUrl)
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 36,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          const Text('Chưa có ảnh sản phẩm'),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Chọn ảnh từ máy'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Mô tả'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Đang bán'),
              subtitle: const Text(
                'Tắt để ẩn sản phẩm khỏi cửa hàng (khách sẽ không thấy).',
              ),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
