import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/product.dart';

/// `TabBar` lọc theo trạng thái sản phẩm cho FarmerHomePage — "Tất cả" +
/// từng [ProductStatus]. Không tự gọi API; chỉ báo lựa chọn ra ngoài qua
/// [onChanged], FarmerHomePage chịu trách nhiệm refetch theo
/// `farmerProductFilterProvider`.
class ProductStatusFilterTabs extends StatefulWidget {
  final ProductStatus? value;
  final ValueChanged<ProductStatus?> onChanged;

  const ProductStatusFilterTabs({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _tabs = <ProductStatus?>[
    null,
    ProductStatus.active,
    ProductStatus.outOfStock,
    ProductStatus.hidden,
  ];

  @override
  State<ProductStatusFilterTabs> createState() =>
      _ProductStatusFilterTabsState();
}

class _ProductStatusFilterTabsState extends State<ProductStatusFilterTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: ProductStatusFilterTabs._tabs.length,
      vsync: this,
      initialIndex:
          ProductStatusFilterTabs._tabs.indexOf(widget.value).clamp(0, 3),
    );
    _controller.addListener(() {
      if (_controller.indexIsChanging) return;
      widget.onChanged(ProductStatusFilterTabs._tabs[_controller.index]);
    });
  }

  @override
  void didUpdateWidget(covariant ProductStatusFilterTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final index =
          ProductStatusFilterTabs._tabs.indexOf(widget.value).clamp(0, 3);
      if (_controller.index != index) {
        _controller.animateTo(index);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _labelFor(ProductStatus? status) {
    switch (status) {
      case null:
        return 'Tất cả';
      case ProductStatus.active:
        return 'Đang bán';
      case ProductStatus.outOfStock:
        return 'Hết hàng';
      case ProductStatus.hidden:
        return 'Đã ẩn';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: TabBar(
        controller: _controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: ProductStatusFilterTabs._tabs
            .map((s) => Tab(text: _labelFor(s)))
            .toList(),
      ),
    );
  }
}
