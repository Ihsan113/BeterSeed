import 'package:flutter/material.dart';
import '../checklist/checklist_style.dart';
import '../data/pack_downloads.dart';
import '../l10n/app_localizations.dart';
import '../logic/growth.dart';

/// The same six installed tree sprites as the Garden, in growth order.
class GardenMilestones extends StatefulWidget {
  const GardenMilestones(
      {super.key, required this.xp, required this.treeImages});
  final int xp;
  final List<String> treeImages;
  @override
  State<GardenMilestones> createState() => _GardenMilestonesState();
}

class _GardenMilestonesState extends State<GardenMilestones> {
  final scroll = ScrollController();
  int? positionedStage;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final current = treeStageForXp(widget.xp);
        final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
        final visibleCount = (box.maxWidth / (88 * scale)).floor().clamp(1, 6);
        final width = box.maxWidth / visibleCount;
        if (positionedStage != current) {
          positionedStage = current;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && scroll.hasClients) {
              scroll.jumpTo(
                  ((current - visibleCount ~/ 2).clamp(0, 6 - visibleCount) *
                          width)
                      .clamp(0.0, scroll.position.maxScrollExtent));
            }
          });
        }
        return RawScrollbar(
            thumbColor: checklistPrimary.withValues(alpha: .35),
            controller: scroll,
            thumbVisibility: true,
            thickness: 2,
            radius: const Radius.circular(4),
            child: SingleChildScrollView(
                key: const ValueKey('milestone-row'),
                controller: scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < treeStageThresholds.length; i++)
                        Semantics(
                            selected: i == current,
                            label: '${context.tr('Stage {p0}', {
                                  'p0': i + 1
                                })}, ${treeStageThresholds[i]} XP${i == current ? ', ${context.tr('Current stage')}' : ''}',
                            child: ExcludeSemantics(
                                child: SizedBox(
                                    key: ValueKey('milestone-stage-$i'),
                                    width: width,
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Opacity(
                                              opacity: i > current ? .38 : 1,
                                              child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
                                                  child: GardenImage.asset(
                                                      widget.treeImages[i],
                                                      key: ValueKey(
                                                          'milestone-tree-$i'),
                                                      height: 100,
                                                      width: width - 16,
                                                      fit: BoxFit.contain))),
                                          SizedBox(
                                              height: 24,
                                              child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Container(
                                                        height: 1,
                                                        color: i <= current
                                                            ? checklistPrimary
                                                                .withValues(
                                                                    alpha: .4)
                                                            : checklistBorder),
                                                    Container(
                                                        width: 24,
                                                        color: checklistSurface,
                                                        alignment: Alignment
                                                            .center,
                                                        child: i < current
                                                            ? const Icon(
                                                                Icons
                                                                    .check_rounded,
                                                                size: 14,
                                                                color:
                                                                    checklistPrimary)
                                                            : Container(
                                                                width:
                                                                    i == current
                                                                        ? 8
                                                                        : 4,
                                                                height:
                                                                    i == current
                                                                        ? 8
                                                                        : 4,
                                                                decoration: BoxDecoration(
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    color: i ==
                                                                            current
                                                                        ? checklistPrimary
                                                                        : checklistMuted))),
                                                  ])),
                                          Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6),
                                              child: Text(
                                                  context.tr('Stage {p0}',
                                                      {'p0': i + 1}),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: i == current
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                      color: i == current
                                                          ? checklistPrimary
                                                          : checklistMuted))),
                                          const SizedBox(height: 4),
                                          Text('${treeStageThresholds[i]} XP',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: checklistMuted)),
                                        ]))))
                    ])));
      });
}
