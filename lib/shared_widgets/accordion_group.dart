import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme.dart';

class AccordionItemData {
  const AccordionItemData({required this.title, required this.body});
  final String title;
  final String body;
}

/// Nhóm accordion tuỳ biến (không dùng ExpansionPanelList mặc định của
/// Flutter để kiểm soát style/animation nhất quán với token app_motion).
/// Đặt ở shared_widgets vì FAQ (1.6) và các màn hình khác (vd. chi tiết sản
/// phẩm) đều có thể cần accordion.
class AccordionGroup extends StatelessWidget {
  const AccordionGroup({super.key, required this.items});
  final List<AccordionItemData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) => _AccordionItem(data: item)).toList(),
    );
  }
}

class _AccordionItem extends StatefulWidget {
  const _AccordionItem({required this.data});
  final AccordionItemData data;

  @override
  State<_AccordionItem> createState() => _AccordionItemState();
}

class _AccordionItemState extends State<_AccordionItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.space1),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.space2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.data.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: AppDurations.micro,
                    curve: AppCurves.easeOut,
                    child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.standard,
            curve: AppCurves.easeOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.space2,
                      0,
                      AppSpace.space2,
                      AppSpace.space2,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.data.body,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}
