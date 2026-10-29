import 'package:flutter/material.dart';

/// Keeps editor controls outside a uniformly scaled, full Garden viewport.
/// The preview's logical size never depends on the selected editing tool.
class GardenEditorFrame extends StatelessWidget {
  const GardenEditorFrame({
    super.key,
    required this.viewport,
    required this.mediaQuery,
    required this.preview,
    required this.tool,
    required this.onToolChanged,
    required this.controls,
    required this.onCancel,
    required this.onSave,
  });

  final Size viewport;
  final MediaQueryData mediaQuery;
  final Widget preview;
  final String tool;
  final ValueChanged<String> onToolChanged;
  final Widget controls;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF071B22),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('asset-editor-cancel'),
                      tooltip: 'Cancel changes',
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const Expanded(
                      child: Text('Edit garden',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    FilledButton(
                      key: const ValueKey('asset-editor-save'),
                      onPressed: onSave,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final sideBySide = constraints.maxWidth >= 700 ||
                      (constraints.maxHeight < 430 &&
                          constraints.maxWidth > constraints.maxHeight * 1.4);
                  final canvas = Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: viewport.width,
                                height: viewport.height,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: MediaQuery(
                                    data: mediaQuery,
                                    child: SizedBox.expand(
                                      key: const ValueKey(
                                          'editor-garden-viewport'),
                                      child: preview,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tool == 'position'
                              ? 'Drag the tree or adjust below'
                              : 'Preview your garden before saving',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                  final tools = ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              for (final item in const [
                                (
                                  'preview',
                                  Icons.visibility_outlined,
                                  'Preview'
                                ),
                                (
                                  'position',
                                  Icons.open_with_rounded,
                                  'Position'
                                ),
                                ('assets', Icons.palette_outlined, 'Assets'),
                              ])
                                Expanded(
                                  child: Semantics(
                                    selected: tool == item.$1,
                                    child: TextButton(
                                      key: ValueKey('editor-tool-${item.$1}'),
                                      onPressed: () => onToolChanged(item.$1),
                                      style: TextButton.styleFrom(
                                        foregroundColor: tool == item.$1
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.white70,
                                        backgroundColor: tool == item.$1
                                            ? const Color(0xFF183A3D)
                                            : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(item.$2, size: 20),
                                          const SizedBox(height: 4),
                                          Text(item.$3,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (tool != 'preview')
                          Expanded(
                            child: SingleChildScrollView(
                              key: ValueKey('editor-controls-$tool'),
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: controls,
                            ),
                          ),
                      ],
                    ),
                  );
                  if (sideBySide) {
                    return Row(
                      children: [
                        Expanded(child: canvas),
                        SizedBox(
                            width: constraints.maxWidth * .46, child: tools),
                      ],
                    );
                  }
                  final navigationHeight =
                      64 + MediaQuery.textScalerOf(context).scale(14) * 1.5;
                  final panelHeight = tool == 'preview'
                      ? navigationHeight
                      : (constraints.maxHeight * .42).clamp(180.0, 240.0);
                  return Column(
                    children: [
                      Expanded(child: canvas),
                      SizedBox(height: panelHeight, child: tools),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      );
}
