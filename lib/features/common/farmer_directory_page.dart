import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/api/customer_community_api.dart';

class FarmerDirectoryPage extends ConsumerStatefulWidget {
  const FarmerDirectoryPage({super.key});

  @override
  ConsumerState<FarmerDirectoryPage> createState() =>
      _FarmerDirectoryPageState();
}

class _FarmerDirectoryPageState extends ConsumerState<FarmerDirectoryPage> {
  List<PublicFarmer> _farmers = const [];
  Set<String> _following = {};
  final Map<String, int> _followerCounts = {};
  final Set<String> _busy = {};
  String? _error;
  bool _loading = true;
  bool _showFollowingOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(customerCommunityApiProvider);
      final farmersFuture = api.fetchFarmers();
      final followingFuture = api.fetchFollowingIds();
      final farmers = await farmersFuture;
      final following = await followingFuture;
      if (!mounted) return;
      setState(() {
        _farmers = farmers;
        _following = following;
        _followerCounts
          ..clear()
          ..addEntries(
            farmers.map(
              (farmer) => MapEntry(farmer.id, farmer.followerCount),
            ),
          );
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error, stackTrace) {
      debugPrint('Could not load farmer directory: $error\n$stackTrace');
      if (mounted) {
        setState(() => _error = 'Không tải được danh sách nông trại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(PublicFarmer farmer) async {
    if (!_busy.add(farmer.id)) return;
    setState(() {});
    final wasFollowing = _following.contains(farmer.id);
    try {
      final updatedCount = await ref
          .read(customerCommunityApiProvider)
          .setFollowing(farmer.id, following: !wasFollowing);
      if (!mounted) return;
      setState(() {
        _followerCounts[farmer.id] = updatedCount;
        if (wasFollowing) {
          _following.remove(farmer.id);
        } else {
          _following.add(farmer.id);
        }
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      _busy.remove(farmer.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmers = _showFollowingOnly
        ? _farmers.where((farmer) => _following.contains(farmer.id)).toList()
        : _farmers;
    return Scaffold(
      appBar: AppBar(title: const Text('Nông trại')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Tất cả')),
                ButtonSegment(value: true, label: Text('Đang theo dõi')),
              ],
              selected: {_showFollowingOnly},
              onSelectionChanged: (selection) {
                setState(() => _showFollowingOnly = selection.first);
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _MessageState(
                        message: _error!,
                        action: TextButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      )
                    : farmers.isEmpty
                        ? _MessageState(
                            message: _showFollowingOnly
                                ? 'Bạn chưa theo dõi nông trại nào.'
                                : 'Chưa có nông trại đang hoạt động.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: farmers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final farmer = farmers[index];
                                final following =
                                    _following.contains(farmer.id);
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundImage:
                                                  farmer.avatarUrl == null
                                                      ? null
                                                      : NetworkImage(
                                                          farmer.avatarUrl!,
                                                        ),
                                              child: farmer.avatarUrl == null
                                                  ? const Icon(
                                                      Icons.agriculture,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                farmer.farmName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (farmer.marketName?.isNotEmpty ==
                                                true ||
                                            farmer.address?.isNotEmpty == true)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Text([
                                              if (farmer
                                                      .marketName?.isNotEmpty ==
                                                  true)
                                                farmer.marketName!,
                                              if (farmer.address?.isNotEmpty ==
                                                  true)
                                                farmer.address!,
                                            ].join(' · ')),
                                          ),
                                        if (farmer.description?.isNotEmpty ==
                                            true)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Text(farmer.description!),
                                          ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.star,
                                                size: 18, color: Colors.amber),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${farmer.rating.toStringAsFixed(1)} (${farmer.ratingCount})',
                                            ),
                                            const SizedBox(width: 16),
                                            const Icon(Icons.people_outline,
                                                size: 18),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${_followerCounts[farmer.id] ?? farmer.followerCount}',
                                            ),
                                            const Spacer(),
                                            TextButton.icon(
                                              onPressed: _busy
                                                      .contains(farmer.id)
                                                  ? null
                                                  : () => _toggleFollow(farmer),
                                              icon: Icon(following
                                                  ? Icons.check
                                                  : Icons.add),
                                              label: Text(following
                                                  ? 'Đang theo dõi'
                                                  : 'Theo dõi'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final Widget? action;

  const _MessageState({required this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              if (action != null) action!,
            ],
          ),
        ),
      );
}
