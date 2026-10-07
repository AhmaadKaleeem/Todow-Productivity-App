import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/roadmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/presentation/providers/roadmap_providers.dart';
import 'package:todow/presentation/screens/roadmap_detail_screen.dart';
import 'package:todow/presentation/screens/roadmap_import_screen.dart';
import 'package:todow/presentation/widgets/beautiful_back_button.dart';

// 12 curated key-pairs — solid accent + gradient skin, aligned to design spec.
// Index -1 = no explicit choice; colour is derived from roadmap.id hash.
const _kPalette = [
  // 0 Navy
  (
    solid: Color(0xFF1E3A8A),
    grad: LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF3155A2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
  // 1 Sky / Azure
  (
    solid: Color(0xFF0EA5E9),
    grad: LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
  // 2 Teal
  (
    solid: Color(0xFF0D9488),
    grad: LinearGradient(
        colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
  // 3 Emerald
  (
    solid: Color(0xFF059669),
    grad: LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF047857)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
  // 4 Amber
  (
    solid: Color(0xFFF59E0B),
    grad: LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
  // 5 Coral
  (
    solid: Color(0xFFFB7185),
    grad: LinearGradient(
        colors: [Color(0xFFFB7185), Color(0xFFF43F5E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
  // 6 Pink
  (
    solid: Color(0xFFF472B6),
    grad: LinearGradient(
        colors: [Color(0xFFF472B6), Color(0xFFEC4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
  // 7 Violet
  (
    solid: Color(0xFF7C3AED),
    grad: LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
  // 8 Indigo
  (
    solid: Color(0xFF4F46E5),
    grad: LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
  // 9 Rose
  (
    solid: Color(0xFFEF4444),
    grad: LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
  // 10 Slate
  (
    solid: Color(0xFF475569),
    grad: LinearGradient(
        colors: [Color(0xFF475569), Color(0xFF334155)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
  // 11 Amber-Pink fusion
  (
    solid: Color(0xFFF59E0B),
    grad: LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFFB7185)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight)
  ),
];

const _kColorNames = [
  'Navy',
  'Sky',
  'Teal',
  'Emerald',
  'Amber',
  'Coral',
  'Pink',
  'Violet',
  'Indigo',
  'Rose',
  'Slate',
  'Fusion',
];

/// Resolve the display index: -1 means auto-derive from id hash.
int _resolvedIndex(Roadmap roadmap) {
  if (roadmap.colorIndex >= 0) return roadmap.colorIndex % _kPalette.length;
  return roadmap.id.hashCode.abs() % _kPalette.length;
}

/// For the picker preview — derive from title text (no ID yet).
int _autoPreviewIndex(String title) =>
    title.isEmpty ? 0 : title.hashCode.abs() % _kPalette.length;

LinearGradient _gradient(Roadmap r) => _kPalette[_resolvedIndex(r)].grad;
Color _accent(Roadmap r) => _kPalette[_resolvedIndex(r)].solid;

class RoadmapListScreen extends ConsumerWidget {
  const RoadmapListScreen({super.key});

  Future<void> _editRoadmap(BuildContext context, WidgetRef ref, Roadmap roadmap) async {
    final edits = await showDialog<_RoadmapEdits>(
      context: context,
      builder: (_) => _RoadmapEditDialog(roadmap: roadmap),
    );
    if (edits == null || !context.mounted) return;
    await ref.read(roadmapsProvider.notifier).updateRoadmap(
          roadmap.copyWith(
            title: edits.title,
            description: edits.description,
            clearDescription: edits.description.isEmpty,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar — back + actions
                  Row(
                    children: [
                      const BeautifulBackButton(),
                      const SizedBox(width: 8),
                      const Spacer(),
                      _ImportButton(),
                      const SizedBox(width: 8),
                      _NewRoadmapButton(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Title + subtitle — always full width, never wraps
                  const Text(
                    'Roadmaps',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your long-term learning paths',
                    style:
                        TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final state = ref.watch(roadmapsProvider);
                  if (state.isLoading) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.action, strokeWidth: 2));
                  }
                  final roadmaps = state.valueOrNull ?? [];
                  if (roadmaps.isEmpty) {
                    return _EmptyState(
                      onCreate: () =>
                          _NewRoadmapButton().showCreateDialog(context, ref),
                      onImport: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RoadmapImportScreen())),
                    );
                  }
                  return ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) =>
                        ref.read(roadmapsProvider.notifier).reorderRoadmaps(oldIndex, newIndex),
                    itemCount: roadmaps.length,
                    itemBuilder: (context, i) {
                      final roadmap = roadmaps[i];
                      return _RoadmapCard(
                        key: ValueKey(roadmap.id),
                        roadmap: roadmap,
                        index: i,
                        isLead: i == 0,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  RoadmapDetailScreen(roadmap: roadmap)),
                        ),
                        onDelete: () => ref
                            .read(roadmapsProvider.notifier)
                            .deleteRoadmap(roadmap.id),
                        onEdit: () => _editRoadmap(context, ref, roadmap),
                        onMoveUp: i == 0
                            ? null
                            : () => ref
                                .read(roadmapsProvider.notifier)
                                .reorderRoadmaps(i, i - 1),
                        onMoveDown: i == roadmaps.length - 1
                            ? null
                            : () => ref
                                .read(roadmapsProvider.notifier)
                                .reorderRoadmaps(i, i + 2),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoadmapEdits {
  const _RoadmapEdits(this.title, this.description);

  final String title;
  final String description;
}

class _RoadmapEditDialog extends StatefulWidget {
  const _RoadmapEditDialog({required this.roadmap});

  final Roadmap roadmap;

  @override
  State<_RoadmapEditDialog> createState() => _RoadmapEditDialogState();
}

class _RoadmapEditDialogState extends State<_RoadmapEditDialog> {
  late final _title = TextEditingController(text: widget.roadmap.title);
  late final _description =
      TextEditingController(text: widget.roadmap.description ?? '');
  late final _accent = _accentForEdit(widget.roadmap);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit roadmap',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4)),
              const SizedBox(height: 18),
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: _editFieldDecoration('Roadmap name', _accent),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration:
                    _editFieldDecoration('Description (optional)', _accent),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: _accent == const Color(0xFFF59E0B)
                          ? AppColors.textPrimary
                          : Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, _RoadmapEdits(title, _description.text.trim()));
  }
}

Color _accentForEdit(Roadmap roadmap) =>
    _kPalette[_resolvedIndex(roadmap)].solid;

InputDecoration _editFieldDecoration(String label, Color accent) =>
    InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    );

class _ImportButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const RoadmapImportScreen())),
        icon: const Icon(Icons.upload_file_rounded, size: 18),
        label: const Text('Import'),
        style: TextButton.styleFrom(
            foregroundColor: AppColors.action, minimumSize: const Size(48, 48)),
      );
}

class _NewRoadmapButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton(
        onPressed: () => showCreateDialog(context, ref),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('New',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      );

  void showCreateDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    // -1 = user has not explicitly chosen a colour yet
    int selectedColor = -1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          // Rebuild sheet when title changes so auto-preview updates
          titleCtrl.addListener(() => setState(() {}));
          return _CreateRoadmapSheet(
            titleCtrl: titleCtrl,
            descCtrl: descCtrl,
            selectedColor: selectedColor,
            autoPreviewIndex: _autoPreviewIndex(titleCtrl.text.trim()),
            onColorSelected: (i) => setState(() => selectedColor = i),
            onSave: () {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;
              ref.read(roadmapsProvider.notifier).createRoadmap(
                  title: title,
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                  colorIndex: selectedColor);
              Navigator.pop(ctx);
            },
            onImport: () {
              Navigator.pop(ctx);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RoadmapImportScreen()));
            },
          );
        },
      ),
    );
  }
}

class _RoadmapCard extends StatefulWidget {
  const _RoadmapCard({
    super.key,
    required this.roadmap,
    required this.index,
    required this.isLead,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final Roadmap roadmap;
  final int index;
  final bool isLead;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  State<_RoadmapCard> createState() => _RoadmapCardState();
}

class _RoadmapCardState extends State<_RoadmapCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(widget.roadmap);
    final grad = _gradient(widget.roadmap);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutExpo,
        child: Container(
          constraints: BoxConstraints(minHeight: widget.isLead ? 210 : 190),
          decoration: BoxDecoration(
            gradient: grad,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative arc in top-right
              Positioned(
                right: -24,
                top: -24,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: -36,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.route_rounded,
                                  size: 11, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'ROADMAP',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          tooltip: 'Roadmap options',
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          onSelected: (value) {
                            if (value == 'edit') widget.onEdit();
                            if (value == 'delete') _confirmDelete(context);
                            if (value == 'up') widget.onMoveUp?.call();
                            if (value == 'down') widget.onMoveDown?.call();
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'up',
                              enabled: widget.onMoveUp != null,
                              child: Row(children: [
                                Icon(Icons.arrow_upward_rounded,
                                    size: 18,
                                    color: widget.onMoveUp != null
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary),
                                const SizedBox(width: 12),
                                Text('Move up',
                                    style: TextStyle(
                                        color: widget.onMoveUp != null
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'down',
                              enabled: widget.onMoveDown != null,
                              child: Row(children: [
                                Icon(Icons.arrow_downward_rounded,
                                    size: 18,
                                    color: widget.onMoveDown != null
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary),
                                const SizedBox(width: 12),
                                Text('Move down',
                                    style: TextStyle(
                                        color: widget.onMoveDown != null
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary)),
                              ]),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(children: const [
                                Icon(Icons.edit_outlined,
                                    size: 18, color: AppColors.action),
                                SizedBox(width: 12),
                                Text('Edit roadmap'),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(children: const [
                                Icon(Icons.delete_outline_rounded,
                                    size: 18, color: AppColors.alert),
                                SizedBox(width: 12),
                                Text('Delete',
                                    style: TextStyle(
                                        color: AppColors.alert,
                                        fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ],
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.more_horiz_rounded,
                                size: 20, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Drag handle: uses immediate listener so it wins over
                        // the outer GestureDetector long-press competition.
                        ReorderableDragStartListener(
                          index: widget.index,
                          child: Tooltip(
                            message: 'Drag to reorder',
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.drag_handle_rounded,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.isLead ? 40 : 28),
                    Text(
                      widget.roadmap.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.6,
                      ),
                    ),
                    if (widget.roadmap.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.roadmap.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                            0, // roadmap list doesn't have progress data, placeholder
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: AppColors.background,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Roadmap?',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: const Text('This also deletes all Topics. Tasks are kept.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete();
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.alert, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate, required this.onImport});

  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: AppColors.divider.withValues(alpha: 0.4),
                  shape: BoxShape.circle),
              child: const Icon(Icons.route_outlined,
                  size: 32, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text('No roadmaps yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
                'Create a roadmap to plan your learning journey in structured stages.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create manually'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.action,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import CSV or Excel'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.divider)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateRoadmapSheet extends StatelessWidget {
  const _CreateRoadmapSheet({
    required this.titleCtrl,
    required this.descCtrl,
    required this.selectedColor,
    required this.autoPreviewIndex,
    required this.onColorSelected,
    required this.onSave,
    required this.onImport,
  });

  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;

  /// -1 = no explicit choice; autoPreviewIndex is the hashed fallback
  final int selectedColor;
  final int autoPreviewIndex;
  final ValueChanged<int> onColorSelected;
  final VoidCallback onSave;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 24),
          const Text(
            'New Roadmap',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 20),
          // Title — letters, spaces, underscores only
          _NameField(controller: titleCtrl, hint: 'Title', autofocus: true),
          const SizedBox(height: 12),
          _SheetField(controller: descCtrl, hint: 'Description (optional)'),
          const SizedBox(height: 24),
          // Colour label — bold name changes with selection
          Row(
            children: [
              const Text(
                'Colour',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  '— ${selectedColor == -1 ? 'Auto' : _kColorNames[selectedColor]}',
                  key: ValueKey(selectedColor),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selectedColor == -1
                        ? AppColors.textSecondary
                        : _kPalette[selectedColor].solid,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Auto swatch — shows resolved preview colour with dashed ring
              GestureDetector(
                onTap: () => onColorSelected(-1),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kPalette[autoPreviewIndex].solid.withValues(
                            alpha: selectedColor == -1 ? 1.0 : 0.25),
                        shape: BoxShape.circle,
                        border: selectedColor == -1
                            ? Border.all(color: AppColors.textPrimary, width: 2)
                            : null,
                      ),
                    ),
                    // Dashed-ring overlay when auto is active
                    if (selectedColor == -1)
                      const Positioned.fill(
                        child: _DashedCircle(color: Colors.white),
                      ),
                    const Icon(Icons.auto_awesome_rounded,
                        size: 14, color: Colors.white),
                  ],
                ),
              ),
              ...List.generate(_kPalette.length, (i) {
                final chosen = selectedColor == i;
                return GestureDetector(
                  onTap: () => onColorSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _kPalette[i].solid,
                      shape: BoxShape.circle,
                      border: chosen
                          ? Border.all(color: AppColors.textPrimary, width: 2.5)
                          : null,
                    ),
                    child: chosen
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.action,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('Create Roadmap',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Import CSV or Excel instead'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.action,
                minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }
}

/// Title field: only letters (a-z A-Z), spaces, underscores allowed.
class _NameField extends StatelessWidget {
  const _NameField(
      {required this.controller, required this.hint, this.autofocus = false});

  final TextEditingController controller;
  final String hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      inputFormatters: [
        // Allow only letters, spaces, underscores
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z _]')),
      ],
      decoration: _fieldDecoration(hint),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: _fieldDecoration(hint),
    );
  }
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6)),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.action)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

/// Dashed circle overlay for the auto-colour swatch.
class _DashedCircle extends StatelessWidget {
  const _DashedCircle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashedCirclePainter(color));
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final r = size.shortestSide / 2 - 2;
    const dashes = 12;
    const dashAngle = 3.14159 * 2 / dashes;
    for (var i = 0; i < dashes; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: r),
        i * dashAngle,
        dashAngle * 0.7,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
