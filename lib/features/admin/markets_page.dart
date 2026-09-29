// lib/features/admin/markets_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/admin/admin_market.dart';
import '../../providers/admin/admin_providers.dart';
import 'admin_shell.dart';
import 'widgets/market_form_sheet.dart';
import 'widgets/market_list_tile.dart';
import 'admin_localization.dart';

class AdminMarketsPage extends ConsumerWidget {
  const AdminMarketsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketsAsync = ref.watch(marketsProvider);
    final actions = ref.read(marketActionsProvider);

    return AdminShell(
      currentRoute: '/admin/markets',
      title: adminText(context, 'Chợ nông sản'), // i18n: admin.markets.title
      actions: [
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () async {
            final draft = await showMarketFormSheet(context);
            if (draft != null) await actions.create(draft);
          },
        ),
      ],
      child: marketsAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(marketsProvider),
            child:
                Text(adminText(context, 'Không tải được danh sách — thử lại')),
          ),
        ),
        data: (markets) {
          if (markets.isEmpty) {
            return Center(
                child: Text(adminText(context, 'Chưa có chợ nông sản nào.')));
          }
          return ListView.builder(
            itemCount: markets.length,
            itemBuilder: (context, index) {
              final m = markets[index];
              return MarketListTile(
                market: m,
                onToggleActive: (active) =>
                    actions.update(m.id, _withActive(m, active)),
                onTap: () async {
                  final draft = await showMarketFormSheet(context, existing: m);
                  if (draft != null) await actions.update(m.id, draft);
                },
              );
            },
          );
        },
      ),
    );
  }

  AdminMarket _withActive(AdminMarket m, bool active) => AdminMarket(
        id: m.id,
        name: m.name,
        nameEn: m.nameEn,
        address: m.address,
        latitude: m.latitude,
        longitude: m.longitude,
        geohash: m.geohash,
        openHours: m.openHours,
        isActive: active,
        farmerCount: m.farmerCount,
      );
}
