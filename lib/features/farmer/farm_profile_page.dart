import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/api/farmer_data_api.dart';
import '../../providers/farmer_data_provider.dart';

class FarmProfilePage extends ConsumerWidget {
  const FarmProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(farmerProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ trang trại')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is ApiException
                      ? error.message
                      : 'Không tải được hồ sơ trang trại.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(farmerProfileProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => _FarmProfileForm(profile: data),
      ),
    );
  }
}

class _FarmProfileForm extends ConsumerStatefulWidget {
  final FarmerProfileData profile;

  const _FarmProfileForm({required this.profile});

  @override
  ConsumerState<_FarmProfileForm> createState() => _FarmProfileFormState();
}

class _FarmProfileFormState extends ConsumerState<_FarmProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _farmNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _descriptionController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _farmNameController = TextEditingController(text: widget.profile.farmName);
    _addressController = TextEditingController(text: widget.profile.address);
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
    _descriptionController =
        TextEditingController(text: widget.profile.description ?? '');
  }

  @override
  void dispose() {
    _farmNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(farmerDataApiProvider).updateProfile(
            farmName: _farmNameController.text.trim(),
            address: _addressController.text.trim(),
            phone: _phoneController.text.trim(),
            description: _descriptionController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu hồ sơ trang trại.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.agriculture_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _farmNameController,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Tên trang trại',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập tên trang trại.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Địa chỉ',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập địa chỉ.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại liên hệ',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              final phone = value?.trim() ?? '';
              final digits = phone.replaceAll(RegExp(r'\D'), '');
              if (!RegExp(r'^\+?[0-9().\-\s]{7,30}$').hasMatch(phone) ||
                  digits.length < 7 ||
                  digits.length > 15) {
                return 'Vui lòng nhập số điện thoại hợp lệ.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _descriptionController,
            maxLength: 10000,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Giới thiệu',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.store_mall_directory_outlined),
            title: const Text('Chợ đăng ký'),
            subtitle: Text(profile.marketName ?? 'Chưa có thông tin'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.my_location_outlined),
            title: const Text('Vị trí GPS đã xác minh'),
            subtitle: Text(
              profile.latitude == null || profile.longitude == null
                  ? 'Chưa có tọa độ.'
                  : '${profile.latitude}, ${profile.longitude}',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Đang lưu...' : 'Lưu thay đổi'),
            ),
          ),
        ],
      ),
    );
  }
}
