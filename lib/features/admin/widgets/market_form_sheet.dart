// lib/features/admin/widgets/market_form_sheet.dart
import 'package:flutter/material.dart';

import '../../../models/admin/admin_market.dart';
import '../admin_localization.dart';

Future<AdminMarket?> showMarketFormSheet(
  BuildContext context, {
  AdminMarket? existing,
}) {
  return showModalBottomSheet<AdminMarket>(
    context: context,
    isScrollControlled: true,
    builder: (context) => MarketFormSheet(existing: existing),
  );
}

class MarketFormSheet extends StatefulWidget {
  MarketFormSheet({super.key, this.existing});
  final AdminMarket? existing;

  @override
  State<MarketFormSheet> createState() => _MarketFormSheetState();
}

class _MarketFormSheetState extends State<MarketFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _nameEnCtrl =
      TextEditingController(text: widget.existing?.nameEn ?? '');
  late final _addressCtrl =
      TextEditingController(text: widget.existing?.address ?? '');
  late final _latitudeCtrl =
      TextEditingController(text: widget.existing?.latitude?.toString() ?? '');
  late final _longitudeCtrl =
      TextEditingController(text: widget.existing?.longitude?.toString() ?? '');
  late TimeOfDay? _startTime = _parseTime(widget.existing?.openHours, 0);
  late TimeOfDay? _endTime = _parseTime(widget.existing?.openHours, 1);
  late bool _isActive = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameEnCtrl.dispose();
    _addressCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Sửa chợ nông sản' : 'Thêm chợ nông sản',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                    labelText: adminText(context, 'Tên chợ (Tiếng Việt)')),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _nameEnCtrl,
                decoration: InputDecoration(
                    labelText: adminText(context, 'Tên chợ (English)')),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration:
                    InputDecoration(labelText: adminText(context, 'Địa chỉ')),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Bắt buộc' : null,
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeCtrl,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: adminText(context, 'Vĩ độ')),
                      validator: _validateLatitude,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeCtrl,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: adminText(context, 'Kinh độ')),
                      validator: _validateLongitude,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              FormField<void>(
                validator: (_) => _startTime == null || _endTime == null
                    ? 'Vui lòng chọn đủ giờ bắt đầu và kết thúc'
                    : _minutes(_endTime!) <= _minutes(_startTime!)
                        ? 'Giờ kết thúc phải sau giờ bắt đầu'
                        : null,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(true),
                            icon: Icon(Icons.schedule),
                            label: Text(_formatTime(_startTime, 'Giờ bắt đầu')),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(false),
                            icon: Icon(Icons.schedule),
                            label: Text(_formatTime(_endTime, 'Giờ kết thúc')),
                          ),
                        ),
                      ],
                    ),
                    if (field.hasError)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(field.errorText!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(adminText(context, 'Đang hoạt động')),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(isEditing ? 'Lưu' : 'Thêm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final latitude = double.parse(_latitudeCtrl.text.trim());
    final longitude = double.parse(_longitudeCtrl.text.trim());
    final openHours =
        '${_formatTime(_startTime, '')}-${_formatTime(_endTime, '')}';
    Navigator.of(context).pop(
      AdminMarket(
        id: widget.existing?.id ?? '',
        name: _nameCtrl.text.trim(),
        nameEn:
            _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: latitude,
        longitude: longitude,
        geohash: _encodeGeohash(latitude, longitude),
        openHours: openHours,
        isActive: _isActive,
        farmerCount: widget.existing?.farmerCount ?? 0,
      ),
    );
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (start ? _startTime : _endTime) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => start ? _startTime = picked : _endTime = picked);
  }

  String? _validateLatitude(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || number < -90 || number > 90
        ? 'Vĩ độ từ -90 đến 90'
        : null;
  }

  String? _validateLongitude(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || number < -180 || number > 180
        ? 'Kinh độ từ -180 đến 180'
        : null;
  }

  static int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  static String _formatTime(TimeOfDay? time, String fallback) {
    if (time == null) return fallback;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static TimeOfDay? _parseTime(String? value, int index) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 2) return null;
    final values = parts[index].trim().split(':');
    if (values.length != 2) return null;
    final hour = int.tryParse(values[0]);
    final minute = int.tryParse(values[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _encodeGeohash(double latitude, double longitude) {
    const alphabet = '0123456789bcdefghjkmnpqrstuvwxyz';
    var latRange = [-90.0, 90.0];
    var lonRange = [-180.0, 180.0];
    var even = true;
    var bit = 0;
    var value = 0;
    final result = StringBuffer();
    while (result.length < 10) {
      final range = even ? lonRange : latRange;
      final coordinate = even ? longitude : latitude;
      final middle = (range[0] + range[1]) / 2;
      if (coordinate >= middle) {
        value = (value << 1) | 1;
        range[0] = middle;
      } else {
        value <<= 1;
        range[1] = middle;
      }
      even = !even;
      bit++;
      if (bit == 5) {
        result.write(alphabet[value]);
        bit = 0;
        value = 0;
      }
    }
    return result.toString();
  }
}
