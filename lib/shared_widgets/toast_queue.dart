import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme.dart';

enum ToastType { success, error }

class _ToastItem {
  _ToastItem(this.id, this.message, this.type);
  final int id;
  final String message;
  final ToastType type;
}

/// Global key gắn ở app.dart để `app_toast.dart` gọi vào overlay này
/// mà không cần BuildContext của widget hiện tại.
final GlobalKey<ToastOverlayState> toastOverlayKey = GlobalKey<ToastOverlayState>();

/// Mount MỘT LẦN ở gốc cây widget (app.dart), không lặp lại ở từng màn hình.
class ToastOverlay extends StatefulWidget {
  const ToastOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<ToastOverlay> createState() => ToastOverlayState();
}

class ToastOverlayState extends State<ToastOverlay> {
  final List<_ToastItem> _items = [];
  int _nextId = 0;

  static const int _maxVisible = 3;

  void push(String message, ToastType type) {
    if (_items.length >= _maxVisible) {
      _items.removeAt(0);
    }
    final item = _ToastItem(_nextId++, message, type);
    setState(() => _items.add(item));
  }

  void _dismiss(int id) {
    setState(() => _items.removeWhere((e) => e.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + AppSpace.space1,
          left: AppSpace.space2,
          right: AppSpace.space2,
          child: Column(
            children: _items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.space1),
                    child: _ToastCard(
                      key: ValueKey(item.id),
                      item: item,
                      onDone: () => _dismiss(item.id),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({super.key, required this.item, required this.onDone});
  final _ToastItem item;
  final VoidCallback onDone;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance =
      AnimationController(vsync: this, duration: AppDurations.toastTransition)..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.item.type == ToastType.error;
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
          .animate(CurvedAnimation(parent: _entrance, curve: AppCurves.easeOut)),
      child: FadeTransition(
        opacity: _entrance,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: AppColors.border),
              boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8)],
            ),
            padding: const EdgeInsets.all(AppSpace.space2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isError ? Icons.error_outline : Icons.check_circle_outline,
                      color: isError ? AppColors.danger : AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpace.space1),
                    Expanded(
                      child: Text(widget.item.message, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.space1),
                _ProgressBar(onDone: widget.onDone),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.toastVisible,
  )
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: 1 - _controller.value,
          minHeight: 2,
          backgroundColor: AppColors.border,
          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
    );
  }
}
