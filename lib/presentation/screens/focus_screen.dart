import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/core/utils/date_format.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/focus_session.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/presentation/providers/focus_providers.dart';
import 'package:todow/presentation/providers/task_providers.dart';
import 'package:todow/presentation/widgets/beautiful_back_button.dart';
import 'package:todow/presentation/widgets/corner_arc_decor.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  Timer? _ticker;
  FocusPreset _preset = FocusPreset.study;
  Duration _customDuration = const Duration(minutes: 50);
  String? _taskId;
  bool _zenMode = false;
  bool _showWorkspace = true;
  late final TextEditingController _manualTimeController;

  @override
  void initState() {
    super.initState();
    _manualTimeController =
        TextEditingController(text: '${_customDuration.inMinutes}');
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _manualTimeController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _onPresetSelected(FocusPreset preset) {
    setState(() {
      _preset = preset;
      _customDuration = preset.defaultDuration;
      _manualTimeController.text = '${_customDuration.inMinutes}';
    });
  }

  void _adjustDuration(int minutesDelta) {
    final newMin = (_customDuration.inMinutes + minutesDelta).clamp(1, 180);
    setState(() {
      _customDuration = Duration(minutes: newMin);
      _manualTimeController.text = '$newMin';
    });
  }

  void _setManualDuration(String val) {
    final parsed = int.tryParse(val.trim());
    if (parsed != null && parsed >= 1 && parsed <= 360) {
      setState(() {
        _customDuration = Duration(minutes: parsed);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(focusSessionProvider);
    final focus = ref.read(focusSessionProvider.notifier);
    final tasks = ref.watch(activeTasksProvider).valueOrNull ?? [];

    if (session != null && _showWorkspace) {
      return _ActiveFocusView(
        session: session,
        remaining: focus.remaining(DateTime.now()),
        focus: focus,
        zenMode: _zenMode,
        onToggleZen: () => setState(() => _zenMode = !_zenMode),
        onCloseWorkspace: () => setState(() => _showWorkspace = false),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const CornerArcDecor(corner: Alignment.topLeft, scale: 1.1),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        20, 8, 20, session == null ? 100 : 32),
                    children: [
                      if (session != null) ...[
                        _buildFocusCommandCard(
                          session: session,
                          remaining: focus.remaining(DateTime.now()),
                          focus: focus,
                          onOpenWorkspace: () =>
                              setState(() => _showWorkspace = true),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        _buildHeroCard(),
                        const SizedBox(height: 20),
                      ],
                      _buildSectionTitle(session != null
                          ? 'CHOOSE NEXT ENVIRONMENT'
                          : 'STUDY DURATION'),
                      const SizedBox(height: 10),
                      _buildPresetGrid(),
                      const SizedBox(height: 16),
                      _buildDurationAdjuster(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('LINKED TASK (OPTIONAL)'),
                      const SizedBox(height: 10),
                      _buildTaskSelector(tasks),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (session == null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: SafeArea(
                child: _buildStartButton(focus, tasks),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFocusCommandCard({
    required FocusSession session,
    required Duration remaining,
    required FocusNotifier focus,
    required VoidCallback onOpenWorkspace,
  }) {
    final isPaused = session.status == FocusSessionStatus.paused;
    final progress = session.progressAt(DateTime.now()).clamp(0.0, 1.0);
    final isEnded = remaining == Duration.zero;
    final accent = _presetAccentColor(session.preset);

    return GestureDetector(
      onTap: onOpenWorkspace,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isPaused
                ? AppColors.attention.withValues(alpha: 0.6)
                : AppColors.divider,
            width: isPaused ? 1.5 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top status line
            Row(
              children: [
                Text(
                  isEnded ? 'Completed' : (isPaused ? 'Paused' : 'In Progress'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isPaused ? AppColors.attention : accent,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Open Workspace →',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Activity name + Task title
            Text(
              session.preset.label,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              session.taskTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Centerpiece Timer
            Text(
              _formatRemainingTime(remaining),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 10),

            // Thin progress indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isPaused ? AppColors.attention : accent,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toInt()}% completed',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${remaining.inMinutes}m left',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Actions row: [ Resume / Pause ] + [ End ]
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: isPaused ? focus.resume : focus.pause,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isPaused ? accent : AppColors.surfaceElevated,
                      foregroundColor:
                          isPaused ? Colors.white : AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isPaused ? accent : AppColors.divider,
                        ),
                      ),
                    ),
                    child: Text(
                      isPaused ? 'Resume' : 'Pause',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _showEndSessionDialog(context, focus),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.alert,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'End',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const BeautifulBackButton(),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Focus Session',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${_customDuration.inMinutes} min block',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Your Dedicated Time For Tasks',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Track uninterrupted time on coursework, revisions, or papers.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildPresetGrid() {
    const normalPresets = [
      FocusPreset.study,
      FocusPreset.coding,
      FocusPreset.assignment,
      FocusPreset.reading,
      FocusPreset.deepWork,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Normal activity chips ──────────────────────────────────────────
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: normalPresets.map((preset) {
            final isSelected = _preset == preset;
            return GestureDetector(
              onTap: () => _onPresetSelected(preset),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _presetAccentColor(preset).withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isSelected
                        ? _presetAccentColor(preset)
                        : AppColors.divider,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      preset.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? _presetAccentColor(preset)
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${preset.defaultDuration.inMinutes}m',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? _presetAccentColor(preset)
                            : AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // ── Ultradian full-row research card ──────────────────────────────
        const SizedBox(height: 10),
        _buildUltradianCard(),
      ],
    );
  }

  // Ultradian rhythm card — full-width, student-friendly copy, visually distinct
  Widget _buildUltradianCard() {
    final isSelected = _preset == FocusPreset.flow;

    // 90 min focused work / 20 min real rest — matches the brain's natural
    // alertness cycle (Kleitman BRAC, 1963). Used here without jargon.
    return GestureDetector(
      onTap: () => _onPresetSelected(FocusPreset.flow),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F4F3A) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF34D399) : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF34D399).withValues(alpha: 0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: name + duration chips
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Ultradian',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? const Color(0xFF34D399)
                          : AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Row(
                  children: [
                    _durationChip('90m', isSelected, work: true),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        '·',
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? const Color(0xFF6EE7B7).withValues(alpha: 0.5)
                              : AppColors.textSecondary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    _durationChip('20m break', isSelected, work: false),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Plain-language benefit line for student reader
            Text(
              'Your brain can only hold real focus for about 90 minutes before it needs a break. Push past that and you get slower, not sharper. Work for 90 minutes, then step away for 20. When you return, the next block feels like a fresh start.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: isSelected
                    ? const Color(0xFFA7F3D0).withValues(alpha: 0.85)
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            // Stat tiles — plain labels, no jargon
            Row(
              children: [
                _statPill('90 min', 'Focus', isSelected),
                const SizedBox(width: 8),
                _statPill('20 min', 'Real break', isSelected),
                const SizedBox(width: 8),
                _statPill('4 blocks', 'Full day', isSelected),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _durationChip(String label, bool isSelected, {required bool work}) {
    final activeColor = work
        ? const Color(0xFF34D399)
        : const Color(0xFF6EE7B7).withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? activeColor.withValues(alpha: 0.15)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? activeColor.withValues(alpha: 0.4)
              : AppColors.divider,
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isSelected ? activeColor : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _statPill(String value, String label, bool isSelected) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF34D399).withValues(alpha: 0.08)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF34D399).withValues(alpha: 0.2)
                : AppColors.divider,
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? const Color(0xFF34D399)
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF6EE7B7).withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationAdjuster() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Duration',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_customDuration.inMinutes} minutes selected',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Direct interactive stepper with inline editable duration
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _durationButton(
                icon: Icons.remove_rounded,
                onTap: () => _adjustDuration(-5),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  // Focus the text field when tapping the pill
                  _manualTimeController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _manualTimeController.text.length,
                  );
                },
                child: Container(
                  width: 72,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        child: TextField(
                          controller: _manualTimeController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            fillColor: Colors.transparent,
                          ),
                          onChanged: _setManualDuration,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Text(
                        'm',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _durationButton(
                icon: Icons.add_rounded,
                onTap: () => _adjustDuration(5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _durationButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(icon, size: 16, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildTaskSelector(List<Task> tasks) {
    final selectedTask = _taskId == null
        ? null
        : tasks.where((t) => t.id == _taskId).firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showTaskPicker(tasks),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selectedTask != null
                        ? AppColors.action.withValues(alpha: 0.12)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    selectedTask != null
                        ? Icons.task_alt_rounded
                        : Icons.link_rounded,
                    color: selectedTask != null
                        ? AppColors.action
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedTask?.title ?? 'No task linked',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selectedTask != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedTask != null
                            ? 'Tap to switch or detach task'
                            : 'Link an active task to focus on',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedTask != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                    onPressed: () => setState(() => _taskId = null),
                  )
                else
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTaskPicker(List<Task> tasks) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Text(
                      'Select Focus Task',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() => _taskId = null);
                        Navigator.pop(context);
                      },
                      child: const Text('None'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(
                        child: Text(
                          'No active tasks found.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final isCurrent = task.id == _taskId;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isCurrent
                                    ? AppColors.action
                                    : AppColors.divider,
                              ),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              leading: Icon(
                                isCurrent
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isCurrent
                                    ? AppColors.action
                                    : AppColors.textSecondary,
                              ),
                              title: Text(
                                task.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: task.dueAt != null
                                  ? Text(
                                      AppDateFormat.dueLabel(task.dueAt),
                                      style: const TextStyle(fontSize: 11.5),
                                    )
                                  : null,
                              onTap: () {
                                setState(() => _taskId = task.id);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStartButton(FocusNotifier focus, List<Task> tasks) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0EA5E9),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: () async {
          final task = _taskId == null
              ? null
              : tasks.where((t) => t.id == _taskId).firstOrNull;
          await focus.start(
            task: task,
            preset: _preset,
            duration: _customDuration,
          );
          if (mounted) {
            setState(() {
              _showWorkspace = true;
            });
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow_rounded, size: 24),
            const SizedBox(width: 8),
            Text(
              'Start Focus • ${_customDuration.inMinutes} min',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE FOCUS WORKSPACE: Immersive, activity-based environment (Coding,
// Reading, Study, Deep Work, Assignment) with contextual live animations.
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveFocusView extends StatefulWidget {
  const _ActiveFocusView({
    required this.session,
    required this.remaining,
    required this.focus,
    required this.zenMode,
    required this.onToggleZen,
    required this.onCloseWorkspace,
  });

  final FocusSession session;
  final Duration remaining;
  final FocusNotifier focus;
  final bool zenMode;
  final VoidCallback onToggleZen;
  final VoidCallback onCloseWorkspace;

  @override
  State<_ActiveFocusView> createState() => _ActiveFocusViewState();
}

class _ActiveFocusViewState extends State<_ActiveFocusView>
    with TickerProviderStateMixin {
  late final AnimationController _breatheController;
  late final AnimationController _loopController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (widget.session.status == FocusSessionStatus.running) {
      _breatheController.repeat(reverse: true);
      _loopController.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion(MediaQuery.disableAnimationsOf(context));
  }

  @override
  void didUpdateWidget(covariant _ActiveFocusView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isRunning = widget.session.status == FocusSessionStatus.running;
    _syncMotion(!isRunning || MediaQuery.disableAnimationsOf(context));
  }

  void _syncMotion(bool shouldStop) {
    final isRunning = widget.session.status == FocusSessionStatus.running;
    if (isRunning && !shouldStop) {
      if (!_breatheController.isAnimating) {
        _breatheController.repeat(reverse: true);
      }
      if (!_loopController.isAnimating) {
        _loopController.repeat();
      }
    } else {
      if (_breatheController.isAnimating) {
        _breatheController.stop();
      }
      if (_loopController.isAnimating) {
        _loopController.stop();
      }
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final progress = widget.session.progressAt(now).clamp(0.0, 1.0);
    final isRunning = widget.session.status == FocusSessionStatus.running;
    final isEnded = widget.remaining == Duration.zero;
    final isEndingSoon = (widget.remaining.inSeconds <= 300 &&
            widget.remaining > Duration.zero) ||
        progress >= 0.88;
    final preset = widget.session.preset;
    final accent = _presetAccentColor(preset);
    const bgColor = AppColors.background;
    const textPrimaryColor = AppColors.textPrimary;
    const textSecondaryColor = AppColors.textSecondary;
    final isCompact = MediaQuery.sizeOf(context).height < 700;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // A quiet work surface gives the session a place without competing
          // with the countdown or the task title.
          Positioned.fill(
            child: AnimatedBuilder(
              animation:
                  Listenable.merge([_breatheController, _loopController]),
              builder: (context, _) {
                return CustomPaint(
                  painter: _FocusEnvironmentPainter(
                    preset: preset,
                    progress: progress,
                    time: (progress + (_loopController.value * 0.02))
                        .clamp(0.0, 1.0),
                    isRunning: isRunning,
                    isEndingSoon: isEndingSoon,
                  ),
                );
              },
            ),
          ),

          // 2. FOREGROUND CONTENT: Safe Area with Back button, Central Timer & Controls
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar: Clean back button + activity label (No circular pills or dots)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      BeautifulBackButton(
                        onTap: widget.onCloseWorkspace,
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textPrimary,
                      ),
                      const Spacer(),
                      Text(
                        preset.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: textSecondaryColor,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                // Center area: Task title + Huge Timer + Thin Progress + Status
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Task title (Clean, authentic typography, no // prefix)
                          Text(
                            widget.session.taskTitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Large centerpiece countdown timer
                          Text(
                            _formatRemainingTime(widget.remaining),
                            style: TextStyle(
                              fontSize: isCompact ? 56 : 68,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2.5,
                              color: textPrimaryColor,
                              height: 1.0,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Clean thin progress indicator
                          SizedBox(
                            width: 240,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor:
                                    AppColors.divider.withValues(alpha: 0.6),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isEndingSoon
                                      ? AppColors.attention
                                      : (isRunning
                                          ? accent
                                          : AppColors.attention),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Progress percentage & time left
                          Text(
                            '${(progress * 100).toInt()}% completed · ${widget.remaining.inMinutes}m left',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Motivational prompt or paused status
                          Text(
                            !isRunning
                                ? 'Session paused'
                                : _motivationMessage(
                                    progress, isEnded, isEndingSoon, preset),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: !isRunning
                                  ? AppColors.attention
                                  : (isEndingSoon
                                      ? AppColors.attention
                                      : textSecondaryColor.withValues(
                                          alpha: 0.85)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom actions: Pause/Resume + End Session
                SafeArea(
                  top: false,
                  minimum: EdgeInsets.fromLTRB(24, 0, 24, isCompact ? 10 : 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: isRunning
                              ? widget.focus.pause
                              : widget.focus.resume,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                isRunning ? AppColors.surface : accent,
                            foregroundColor:
                                isRunning ? textPrimaryColor : Colors.white,
                            elevation: 0,
                            side: BorderSide(
                              color: isRunning ? AppColors.divider : accent,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isRunning ? 'Pause Session' : 'Resume Session',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () =>
                              _showEndSessionDialog(context, widget.focus),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.alert,
                            side: BorderSide(
                              color: AppColors.alert.withValues(alpha: 0.55),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'End session',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _motivationMessage(
      double progress, bool isEnded, bool isEndingSoon, FocusPreset preset) {
    if (isEnded) return 'Session complete. Take a well-earned rest.';
    if (isEndingSoon) {
      if (preset == FocusPreset.flow) {
        return 'Almost there. Your 20-minute break starts soon.';
      }
      return 'Final minutes. Bring this session to a clean completion.';
    }
    if (preset == FocusPreset.flow) {
      return '90 minutes of real focus, then 20 minutes of real rest. That is the rhythm your brain works best with.';
    }
    if (progress < 0.25) {
      return 'Settle into the task. Remove distractions.';
    }
    if (progress < 0.50) {
      return 'Steady flow. Keep this momentum.';
    }
    if (progress < 0.85) {
      return 'Past the halfway mark. Keep your attention right here.';
    }
    return 'Approaching the finish. Stay focused.';
  }
}

class _FocusEnvironmentPainter extends CustomPainter {
  const _FocusEnvironmentPainter({
    required this.preset,
    required this.progress,
    required this.time,
    required this.isRunning,
    required this.isEndingSoon,
  });

  final FocusPreset preset;
  final double progress;
  final double time;
  final bool isRunning;
  final bool isEndingSoon;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = AppColors.background;
    canvas.drawRect(Offset.zero & size, background);

    final deskTop = size.height * 0.77;
    canvas.drawRect(
      Rect.fromLTWH(0, deskTop, size.width, size.height - deskTop),
      Paint()..color = const Color(0xFFE7DED0),
    );

    final window = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.73, 92, size.width * 0.18, 170),
      const Radius.circular(6),
    );
    canvas.drawRRect(window, Paint()..color = const Color(0xFFDCE8E9));
    canvas.drawLine(
      Offset(size.width * 0.82, 92),
      Offset(size.width * 0.82, 262),
      Paint()
        ..color = const Color(0xFFB8C9C9)
        ..strokeWidth = 1,
    );

    final quietObject = Paint()..color = const Color(0xFFD5CEC0);
    final left = size.width * 0.08;
    switch (preset) {
      case FocusPreset.coding:
        final monitor = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height * 0.25, size.width * 0.25, 190),
          const Radius.circular(8),
        );
        canvas.drawRRect(monitor, Paint()..color = const Color(0xFF34434A));
        canvas.drawRRect(
          monitor.deflate(12),
          Paint()..color = const Color(0xFF53656A),
        );
        for (var i = 0; i < 7; i++) {
          canvas.drawLine(
            Offset(left + 28, size.height * 0.31 + i * 18),
            Offset(
                left + 120 + (i.isEven ? 28 : 0), size.height * 0.31 + i * 18),
            Paint()
              ..color = const Color(0xFFA8C5C6)
              ..strokeWidth = 2,
          );
        }
        canvas.drawRect(
          Rect.fromLTWH(left + 92, size.height * 0.69, 40, 28),
          quietObject,
        );
      case FocusPreset.reading:
        final book = Path()
          ..moveTo(left, size.height * 0.66)
          ..lineTo(size.width * 0.34, size.height * 0.57)
          ..lineTo(size.width * 0.55, size.height * 0.66)
          ..lineTo(size.width * 0.34, size.height * 0.75)
          ..close();
        canvas.drawPath(book, Paint()..color = const Color(0xFFFFFCF2));
        for (var i = 0; i < 5; i++) {
          canvas.drawLine(
            Offset(left + 30, size.height * 0.63 + i * 14),
            Offset(size.width * 0.30, size.height * 0.60 + i * 14),
            Paint()..color = const Color(0xFFD2C9B8),
          );
        }
      case FocusPreset.assignment:
        final paper =
            Rect.fromLTWH(left, size.height * 0.23, size.width * 0.31, 260);
        canvas.drawRect(paper, Paint()..color = const Color(0xFFFFFCF6));
        for (var i = 0; i < 8; i++) {
          final y = paper.top + 34 + i * 25;
          canvas.drawLine(
            Offset(paper.left + 42, y),
            Offset(paper.right - 24, y),
            Paint()..color = const Color(0xFFD8DFDA),
          );
          if (progress > (i + 1) / 8) {
            canvas.drawLine(
              Offset(paper.left + 14, y - 3),
              Offset(paper.left + 18, y + 2),
              Paint()
                ..color = AppColors.action
                ..strokeWidth = 2,
            );
            canvas.drawLine(
              Offset(paper.left + 18, y + 2),
              Offset(paper.left + 26, y - 7),
              Paint()
                ..color = AppColors.action
                ..strokeWidth = 2,
            );
          }
        }
      case FocusPreset.study:
        for (var i = 0; i < 3; i++) {
          final x = left + i * 76;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, size.height * 0.31 + i * 12, 62, 92),
              const Radius.circular(5),
            ),
            Paint()..color = const Color(0xFFFFFCF5),
          );
          canvas.drawLine(
            Offset(x + 14, size.height * 0.37 + i * 12),
            Offset(x + 48, size.height * 0.37 + i * 12),
            Paint()..color = const Color(0xFFC9D2C7),
          );
        }
      case FocusPreset.deepWork || FocusPreset.flow:
        final notebook = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height * 0.28, size.width * 0.28, 230),
          const Radius.circular(6),
        );
        canvas.drawRRect(notebook, Paint()..color = const Color(0xFFFAF8EF));
        for (var i = 0; i < 7; i++) {
          canvas.drawLine(
            Offset(left + 44, size.height * 0.36 + i * 22),
            Offset(left + 188, size.height * 0.36 + i * 22),
            Paint()..color = const Color(0xFFBFC0B2),
          );
        }
    }

    final progressX = size.width * (0.12 + progress * 0.46);
    canvas.drawLine(
      Offset(progressX, deskTop + 12),
      Offset(progressX, deskTop + 34),
      Paint()
        ..color = isEndingSoon ? AppColors.attention : AppColors.action
        ..strokeWidth = 3,
    );

    if (isRunning) {
      final ambientX =
          size.width * (0.12 + 0.08 * math.sin(time * math.pi * 2));
      canvas.drawCircle(
        Offset(ambientX, deskTop + 8),
        3,
        Paint()..color = const Color(0xFFB86B4B),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FocusEnvironmentPainter oldDelegate) =>
      oldDelegate.preset != preset ||
      oldDelegate.progress != progress ||
      oldDelegate.time != time ||
      oldDelegate.isRunning != isRunning ||
      oldDelegate.isEndingSoon != isEndingSoon;
}

Color _presetAccentColor(FocusPreset preset) {
  return switch (preset) {
    FocusPreset.coding => AppColors.action,
    FocusPreset.reading => AppColors.decorCoral,
    FocusPreset.study => AppColors.decorNavy,
    FocusPreset.deepWork => AppColors.attention,
    FocusPreset.assignment => AppColors.decorPink,
    FocusPreset.flow => const Color(0xFF10B981),
  };
}

String _formatRemainingTime(Duration duration) {
  if (duration.isNegative || duration == Duration.zero) return '00:00';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

Future<void> _showEndSessionDialog(
    BuildContext context, FocusNotifier focus) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'End focus session?',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: const Text(
        'Your elapsed study time will be saved. Are you sure you want to wrap up early?',
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Continue Focusing'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.alert,
          ),
          onPressed: () {
            Navigator.pop(context);
            focus.end();
          },
          child: const Text('End Session'),
        ),
      ],
    ),
  );
}
