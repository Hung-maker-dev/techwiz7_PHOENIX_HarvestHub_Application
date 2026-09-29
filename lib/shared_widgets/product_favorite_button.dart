import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/api/customer_api.dart';
import '../data/providers/shopping_providers.dart';
import '../models/product.dart';

class ProductFavoriteButton extends ConsumerStatefulWidget {
  const ProductFavoriteButton({required this.product, super.key});

  final Product product;

  @override
  ConsumerState<ProductFavoriteButton> createState() =>
      _ProductFavoriteButtonState();
}

class _ProductFavoriteButtonState extends ConsumerState<ProductFavoriteButton> {
  bool _busy = false;

  Future<void> _toggle(bool isSaved) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(customerApiProvider);
      if (isSaved) {
        await api.removeWishlist(widget.product.id);
      } else {
        await api.addWishlist(widget.product.id);
      }
      ref.invalidate(wishlistProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSaved
                  ? 'account.wishlist.removed'.tr()
                  : 'account.shop.saved'.tr(),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        final message =
            error is ApiException ? error.message : error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(wishlistProvider);
    final isSaved = wishlist.valueOrNull
            ?.any((product) => product.id == widget.product.id) ??
        false;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip:
            isSaved ? 'account.wishlist.remove'.tr() : 'account.shop.save'.tr(),
        onPressed: _busy ? null : () => _toggle(isSaved),
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                isSaved ? Icons.favorite : Icons.favorite_border,
                color: isSaved ? colors.error : colors.onSurfaceVariant,
              ),
      ),
    );
  }
}
