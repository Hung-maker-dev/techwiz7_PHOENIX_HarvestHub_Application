import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../data/api/farmer_data_api.dart';
import '../../providers/farmer_data_provider.dart';

class FarmerPickupSlotsPage extends ConsumerStatefulWidget {
  const FarmerPickupSlotsPage({super.key});

  @override
  ConsumerState<FarmerPickupSlotsPage> createState() =>
      _FarmerPickupSlotsPageState();
}

class _FarmerPickupSlotsPageState extends ConsumerState<FarmerPickupSlotsPage> {
  bool _isCreatingSlot = false;

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(farmerPickupSlotsProvider(false));
    return Scaffold(
      appBar: AppBar(title: const Text('Khung giờ nhận hàng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreatingSlot ? null : _createSlot,
        icon: const Icon(Icons.add),
        label: Text(_isCreatingSlot ? 'Đang tạo...' : 'Thêm khung giờ'),
      ),
      body: slotsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _FarmerDataUnavailable(
          title: 'Không tải được khung giờ',
          message: error is ApiException
              ? error.message
              : 'Không thể tải dữ liệu lúc này.',
        ),
        data: (slots) {
          if (slots.isEmpty) {
            return const _FarmerDataUnavailable(
              title: 'Chưa có khung giờ nhận hàng',
              message: 'Chưa có bản ghi pickup_slots cho farmer này.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: slots
                .map(
                  (slot) => Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: const EdgeInsets.only(right: 8),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_time(slot.startTime)} - ${_time(slot.endTime)}',
                                    ),
                                  ),
                                  if (slot.bookedCount > 0)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Đã có người đặt',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                slot.bookedCount > 0
                                    ? 'Đã có ${slot.bookedCount}/${slot.capacity} chỗ đặt - không thể xóa'
                                    : '${slot.bookedCount}/${slot.capacity} chỗ đã đặt',
                              ),
                              value: slot.isOpen,
                              onChanged: (value) => _toggleSlot(slot, value),
                            ),
                          ),
                          IconButton(
                            tooltip: slot.bookedCount > 0
                                ? 'Khung giờ đã có người đặt, không thể xóa'
                                : 'Xóa khung giờ',
                            onPressed: slot.bookedCount > 0
                                ? null
                                : () => _deleteSlot(slot),
                            icon: const Icon(Icons.delete_outline),
                            color: slot.bookedCount > 0
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Future<void> _toggleSlot(FarmerPickupSlotData slot, bool value) async {
    try {
      await ref.read(farmerDataApiProvider).updatePickupSlot(slot.id, value);
      ref.invalidate(farmerPickupSlotsProvider(false));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu khung giờ lúc này.')),
        );
      }
    }
  }

  Future<void> _deleteSlot(FarmerPickupSlotData slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa khung giờ?'),
        content: Text(
          'Bạn có chắc muốn xóa khung giờ ${_time(slot.startTime)} - ${_time(slot.endTime)} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(farmerDataApiProvider).deletePickupSlot(slot.id);
      ref.invalidate(farmerPickupSlotsProvider(false));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa khung giờ.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa khung giờ lúc này.')),
        );
      }
    }
  }

  Future<void> _createSlot() async {
    if (_isCreatingSlot || !mounted) return;
    setState(() => _isCreatingSlot = true);

    try {
      final start = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 8, minute: 0),
        helpText: 'Chọn giờ bắt đầu',
      );
      if (!mounted || start == null) return;

      final end = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: start.hour >= 22 ? 23 : start.hour + 2,
          minute: start.minute,
        ),
        helpText: 'Chọn giờ kết thúc',
      );
      if (!mounted || end == null) return;

      final capacity = await _askCapacity();
      if (!mounted || capacity == null || capacity <= 0) return;

      final now = DateTime.now();
      final startDate =
          DateTime(now.year, now.month, now.day, start.hour, start.minute);
      final endDate =
          DateTime(now.year, now.month, now.day, end.hour, end.minute);
      if (!endDate.isAfter(startDate)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Giờ kết thúc phải sau giờ bắt đầu.')),
          );
        }
        return;
      }

      await ref.read(farmerDataApiProvider).createPickupSlot(
            startTime: startDate,
            endTime: endDate,
            capacity: capacity,
          );
      if (!mounted) return;
      ref.invalidate(farmerPickupSlotsProvider(false));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo khung giờ nhận hàng.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tạo khung giờ lúc này.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingSlot = false);
      }
    }
  }

  Future<int?> _askCapacity() async {
    if (!mounted) return null;

    final controller = TextEditingController(text: '5');
    final value = await showDialog<int?>(
      context: context,
      builder: (context) {
        final dialogController = TextEditingController(text: controller.text);
        return AlertDialog(
          title: const Text('Sức chứa khung giờ'),
          content: TextField(
            controller: dialogController,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số khách tối đa'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final capacity = int.tryParse(dialogController.text.trim());
                if (capacity != null && capacity > 0) {
                  Navigator.pop(context, capacity);
                } else {
                  Navigator.pop(context, null);
                }
              },
              child: const Text('Tạo khung giờ'),
            ),
          ],
        );
      },
    );
    return value;
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class FarmerReportsPage extends ConsumerStatefulWidget {
  const FarmerReportsPage({super.key});

  @override
  ConsumerState<FarmerReportsPage> createState() => _FarmerReportsPageState();
}

class _FarmerReportsPageState extends ConsumerState<FarmerReportsPage> {
  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(farmerReportProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _FarmerDataUnavailable(
          title: 'Không tải được báo cáo',
          message: error is ApiException
              ? error.message
              : 'Không thể tải dữ liệu lúc này.',
        ),
        data: (report) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ReportValue(
                label: 'Tổng đơn hàng', value: '${report.totalOrders} đơn'),
            _ReportValue(
                label: 'Đơn hoàn tất', value: '${report.completedOrders} đơn'),
            _ReportValue(
                label: 'Doanh thu đã hoàn tất',
                value: '${report.revenue.toStringAsFixed(0)} đ'),
            _ReportValue(
                label: 'Sản phẩm sắp hết hàng',
                value: '${report.lowStock} sản phẩm'),
          ],
        ),
      ),
    );
  }
}

class _ReportValue extends StatelessWidget {
  final String label;
  final String value;

  const _ReportValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(child: ListTile(title: Text(label), trailing: Text(value)));
  }
}

class FarmerReviewsPage extends ConsumerStatefulWidget {
  const FarmerReviewsPage({super.key});

  @override
  ConsumerState<FarmerReviewsPage> createState() => _FarmerReviewsPageState();
}

class _FarmerReviewsPageState extends ConsumerState<FarmerReviewsPage> {
  bool _sending = false;

  Future<void> _composeAnnouncement() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final announcement = await showDialog<({String title, String body})>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Gửi tin đến người theo dõi'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                maxLength: 255,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập tiêu đề thông báo.'
                    : null,
              ),
              TextFormField(
                controller: bodyController,
                maxLength: 5000,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Nội dung'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nhập nội dung thông báo.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                (
                  title: titleController.text.trim(),
                  body: bodyController.text.trim(),
                ),
              );
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
    titleController.dispose();
    bodyController.dispose();
    if (announcement == null || !mounted) return;

    setState(() => _sending = true);
    try {
      final delivery = await ref.read(farmerDataApiProvider).sendAnnouncement(
            title: announcement.title,
            body: announcement.body,
          );
      ref.invalidate(farmerNotificationsProvider(false));
      if (mounted) {
        final pushMessage = switch (delivery.pushStatus) {
          'sent' => ' Push đã gửi đến ${delivery.pushedDeviceCount} thiết bị.',
          'partial' =>
            ' Push thành công ${delivery.pushedDeviceCount} thiết bị, lỗi ${delivery.failedDeviceCount}.',
          'no_devices' => ' Chưa có thiết bị bật thông báo để nhận push.',
          'not_configured' =>
            ' Push chưa cấu hình credentials FCM trên backend.',
          _ => ' Push chưa gửi được; hãy kiểm tra log PHP backend.',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              delivery.recipientCount == 0
                  ? 'Chưa có người theo dõi để nhận thông báo.'
                  : 'Đã lưu thông báo trong app cho '
                      '${delivery.recipientCount} người theo dõi.$pushMessage',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(farmerReviewsProvider(false));
    final followersAsync = ref.watch(farmerFollowersProvider(false));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cộng đồng'),
          actions: [
            IconButton(
              tooltip: 'Gửi tin đến người theo dõi',
              onPressed: _sending ? null : _composeAnnouncement,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.campaign_outlined),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Người theo dõi'),
              Tab(icon: Icon(Icons.star_outline), text: 'Đánh giá'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FollowersContent(followersAsync: followersAsync),
            _ReviewsContent(reviewsAsync: reviewsAsync),
          ],
        ),
      ),
    );
  }
}

class _FollowersContent extends StatelessWidget {
  final AsyncValue<List<FarmerFollowerData>> followersAsync;

  const _FollowersContent({required this.followersAsync});

  @override
  Widget build(BuildContext context) {
    return followersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _FarmerDataUnavailable(
        title: 'Không tải được người theo dõi',
        message: error is ApiException
            ? error.message
            : 'Không thể tải dữ liệu lúc này.',
      ),
      data: (followers) {
        if (followers.isEmpty) {
          return const _FarmerDataUnavailable(
            title: 'Chưa có người theo dõi',
            message: 'Chưa có khách hàng theo dõi trang trại.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.people_alt_outlined, size: 36),
                title: Text('${followers.length} người theo dõi'),
                subtitle:
                    const Text('Danh sách người đang theo dõi trang trại'),
              ),
            ),
            const SizedBox(height: 12),
            ...followers.map(
              (follower) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(follower.userName),
                  subtitle: Text(follower.email ?? 'Người theo dõi'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReviewsContent extends StatelessWidget {
  final AsyncValue<List<FarmerReviewData>> reviewsAsync;

  const _ReviewsContent({required this.reviewsAsync});

  @override
  Widget build(BuildContext context) {
    return reviewsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _FarmerDataUnavailable(
        title: 'Không tải được đánh giá',
        message: error is ApiException
            ? error.message
            : 'Không thể tải dữ liệu lúc này.',
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return const _FarmerDataUnavailable(
            title: 'Chưa có đánh giá',
            message: 'Chưa có khách hàng gửi đánh giá cho trang trại.',
          );
        }
        final average =
            reviews.fold<int>(0, (sum, review) => sum + review.rating) /
                reviews.length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.amber, size: 36),
                title: Text('${average.toStringAsFixed(1)} / 5.0'),
                subtitle: Text('${reviews.length} đánh giá'),
              ),
            ),
            const SizedBox(height: 12),
            ...reviews.map(
              (review) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(review.userName ?? 'Khách hàng'),
                  subtitle: Text(review.comment?.isNotEmpty == true
                      ? review.comment!
                      : 'Không có nhận xét'),
                  trailing: Text('★ ${review.rating}'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FarmerNotificationsPage extends ConsumerStatefulWidget {
  const FarmerNotificationsPage({super.key});

  @override
  ConsumerState<FarmerNotificationsPage> createState() =>
      _FarmerNotificationsPageState();
}

class _FarmerNotificationsPageState
    extends ConsumerState<FarmerNotificationsPage> {
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(farmerNotificationsProvider(false));
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _FarmerDataUnavailable(
          title: 'Không tải được thông báo',
          message: error is ApiException
              ? error.message
              : 'Không thể tải dữ liệu lúc này.',
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const _FarmerDataUnavailable(
              title: 'Chưa có thông báo',
              message: 'Không có bản ghi notifications cho farmer này.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return Card(
                color: item.isRead
                    ? null
                    : Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(item.isRead
                      ? Icons.notifications_none
                      : Icons.notifications_active),
                  title: Text(item.title),
                  subtitle:
                      Text(item.body ?? (item.isRead ? 'Đã đọc' : 'Chưa đọc')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openNotification(item),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openNotification(FarmerNotificationData item) async {
    try {
      await ref.read(farmerDataApiProvider).markNotificationRead(item.id);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    } catch (error, stackTrace) {
      debugPrint(
          'Could not mark farmer notification as read: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Không thể cập nhật thông báo lúc này.')),
        );
      }
      return;
    }
    if (!mounted) return;
    ref.invalidate(farmerNotificationsProvider(false));
    if (item.orderId != null) {
      context.go('/farmer/orders');
    }
    if (item.productId != null) {
      context.go('/farmer/products/${item.productId}/edit');
    }
  }
}

class _FarmerDataUnavailable extends StatelessWidget {
  final String title;
  final String message;

  const _FarmerDataUnavailable({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storage_outlined, size: 52),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
