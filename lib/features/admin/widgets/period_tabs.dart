// lib/features/admin/widgets/period_tabs.dart
import 'package:flutter/material.dart';

import '../../../models/admin/system_report.dart';

class PeriodTabs extends StatelessWidget {
  const PeriodTabs(
      {super.key, required this.selected, required this.onChanged});

  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onChanged;

  static const _labels = {
    ReportPeriod.week: 'Tuần',
    ReportPeriod.month: 'Tháng',
    ReportPeriod.quarter: 'Quý',
    ReportPeriod.year: 'Năm',
  };

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ReportPeriod>(
      segments: [
        for (final p in ReportPeriod.values)
          ButtonSegment(value: p, label: Text(_labels[p]!)),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
