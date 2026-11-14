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
    final isCoding = preset == FocusPreset.coding;
    final isFlow = preset == FocusPreset.flow;
    final isDark = isCoding || isFlow;
    final accent = _presetAccentColor(preset);

    final bgColor = isCoding
        ? const Color(0xFF0F141C)
        : (isFlow ? const Color(0xFF0A1815) : AppColors.background);
    final textPrimaryColor =
        isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final textSecondaryColor =
        isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final isCompact = MediaQuery.sizeOf(context).height < 700;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. FULL-SCREEN ANIMATION CANVAS: Covers the whole screen
          Positioned.fill(
            child: AnimatedBuilder(
              animation:
                  Listenable.merge([_breatheController, _loopController]),
              builder: (context, _) {
                final time = reduceMotion ? 0.35 : _loopController.value;
                final pulse = reduceMotion ? 0.45 : _breatheController.value;

                return CustomPaint(
                  painter: switch (preset) {
                    FocusPreset.coding => _CodingWorkspacePainter(
                        time: time,
                        progress: progress,
                        isRunning: isRunning,
                        isEndingSoon: isEndingSoon,
                      ),
                    FocusPreset.reading => _ReadingWorkspacePainter(
                        time: time,
                        pulse: pulse,
                        progress: progress,
                        isRunning: isRunning,
                        isEndingSoon: isEndingSoon,
                      ),
                    FocusPreset.study => _StudyWorkspacePainter(
                        time: time,
                        progress: progress,
                        isRunning: isRunning,
                        isEndingSoon: isEndingSoon,
                      ),
                    FocusPreset.deepWork => _DeepWorkWorkspacePainter(
                        time: time,
                        pulse: pulse,
                        progress: progress,
                        isRunning: isRunning,
                        isEndingSoon: isEndingSoon,
                      ),
                    FocusPreset.assignment => _AssignmentWorkspacePainter(
                        time: time,
                        progress: progress,
                        isRunning: isRunning,
                        isEndingSoon: isEndingSoon,
                      ),
                    FocusPreset.flow => _FlowWorkspacePainter(
                        time: time,
                        pulse: pulse,
                        progress: progress,
                        isRunning: isRunning,
                        isEndingSoon: isEndingSoon,
                      ),
                  },
                );
              },
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FocusAnchorPainter(
                  accent: accent,
                  progress: progress,
                  phase: reduceMotion ? 0.35 : _loopController.value,
                  breath: reduceMotion ? 0.45 : _breatheController.value,
                  isRunning: isRunning,
                  isEndingSoon: isEndingSoon,
                  isDark: isDark,
                ),
              ),
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
                        backgroundColor:
                            isDark ? const Color(0xFF1E2836) : null,
                        foregroundColor:
                            isDark ? const Color(0xFFF1F5F9) : null,
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
                                backgroundColor: isDark
                                    ? const Color(0xFF1E2836)
                                    : AppColors.divider.withValues(alpha: 0.6),
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
                            backgroundColor: isRunning
                                ? (isDark
                                    ? const Color(0xFF1E2836)
                                    : AppColors.surface)
                                : accent,
                            foregroundColor:
                                isRunning ? textPrimaryColor : Colors.white,
                            elevation: 0,
                            side: BorderSide(
                              color: isRunning
                                  ? (isDark
                                      ? const Color(0xFF2C394B)
                                      : AppColors.divider)
                                  : accent,
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

class _FocusAnchorPainter extends CustomPainter {
  const _FocusAnchorPainter({
    required this.accent,
    required this.progress,
    required this.phase,
    required this.breath,
    required this.isRunning,
    required this.isEndingSoon,
    required this.isDark,
  });

  final Color accent;
  final double progress;
  final double phase;
  final double breath;
  final bool isRunning;
  final bool isEndingSoon;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    final baseRadius = (size.shortestSide * 0.31).clamp(104.0, 156.0);
    final radius = baseRadius + breath * 8;
    final quietColor = isDark ? Colors.white : AppColors.textPrimary;
    final opacity = isRunning ? 0.14 : 0.07;

    final haloPaint = Paint()
      ..color = quietColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, haloPaint);

    final progressPaint = Paint()
      ..color = (isEndingSoon ? AppColors.attention : accent)
          .withValues(alpha: isRunning ? 0.62 : 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isEndingSoon ? 2.5 : 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + phase * math.pi * 2,
      math.pi * 1.35 * progress.clamp(0.06, 1),
      false,
      progressPaint,
    );

    final cuePaint = Paint()
      ..color = accent.withValues(alpha: isRunning ? 0.28 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 14),
      math.pi * 0.15 + phase * math.pi * 2,
      math.pi * 0.32,
      false,
      cuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FocusAnchorPainter old) =>
      old.accent != accent ||
      old.progress != progress ||
      old.phase != phase ||
      old.breath != breath ||
      old.isRunning != isRunning ||
      old.isEndingSoon != isEndingSoon ||
      old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. CODING WORKSPACE PAINTER: Developer IDE, syntax lines, and typing cursor.
// ─────────────────────────────────────────────────────────────────────────────

class _CodingWorkspacePainter extends CustomPainter {
  _CodingWorkspacePainter({
    required this.time,
    required this.progress,
    required this.isRunning,
    required this.isEndingSoon,
  });

  final double time;
  final double progress;
  final bool isRunning;
  final bool isEndingSoon;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0F141C);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Gutter line
    const gutterX = 42.0;
    canvas.drawLine(
      const Offset(gutterX, 0),
      Offset(gutterX, size.height),
      Paint()
        ..color = const Color(0xFF1E2633)
        ..strokeWidth = 1.0,
    );

    // Line numbers
    final activeLineIndex = isRunning ? (6 + ((time * 4).toInt() % 4)) : 7;
    final totalLines = (size.height / 24).floor();

    for (int i = 1; i <= totalLines; i++) {
      final y = 20.0 + (i * 24.0);
      final isCurrent = i == activeLineIndex;

      if (isCurrent && isRunning) {
        canvas.drawRect(
          Rect.fromLTWH(gutterX, y - 4, size.width - gutterX, 22),
          Paint()
            ..color = isEndingSoon
                ? const Color(0xFF282012)
                : const Color(0xFF162030),
        );
      }

      final lineStr = i.toString().padLeft(2, '0');
      final numPainter = TextPainter(
        text: TextSpan(
          text: lineStr,
          style: TextStyle(
            color: isCurrent && isRunning
                ? (isEndingSoon ? AppColors.attention : const Color(0xFF38BDF8))
                : const Color(0xFF334155),
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      numPainter.paint(canvas, Offset(10, y));
    }

    // Background code tokens
    final codeSnippets = [
      [
        ('import ', const Color(0xFF38BDF8)),
        ('\'package:todow/core.dart\';', const Color(0xFF34D399))
      ],
      [
        ('class ', const Color(0xFF38BDF8)),
        ('DeepFocusController ', const Color(0xFFFBBF24)),
        ('{', const Color(0xFF94A3B8))
      ],
      [
        ('  final ', const Color(0xFF38BDF8)),
        ('state = ', const Color(0xFF94A3B8)),
        ('ActiveSession();', const Color(0xFFF8FAFC))
      ],
      [
        ('  Stream<', const Color(0xFF38BDF8)),
        ('FocusTick', const Color(0xFFFBBF24)),
        ('> tick() ', const Color(0xFF60A5FA)),
        ('async* {', const Color(0xFF38BDF8))
      ],
      [
        ('    while ', const Color(0xFF38BDF8)),
        ('(session.isRunning) {', const Color(0xFF94A3B8))
      ],
      [
        ('      yield ', const Color(0xFF38BDF8)),
        ('session.', const Color(0xFFF8FAFC)),
        ('elapsed();', const Color(0xFF34D399))
      ],
      [
        ('      await ', const Color(0xFF38BDF8)),
        ('Future.', const Color(0xFFF8FAFC)),
        ('delayed(1.sec);', const Color(0xFF34D399))
      ],
      [('    }', const Color(0xFF94A3B8))],
      [('  }', const Color(0xFF94A3B8))],
      [
        ('  void ', const Color(0xFF38BDF8)),
        ('commitSprint() ', const Color(0xFF60A5FA)),
        ('{', const Color(0xFF94A3B8))
      ],
      [
        ('    metrics.', const Color(0xFFF8FAFC)),
        ('recordBlock(progress);', const Color(0xFF34D399))
      ],
      [('  }', const Color(0xFF94A3B8))],
      [('}', const Color(0xFF94A3B8))],
    ];

    double snippetY = 68.0;
    for (int i = 0;
        i < codeSnippets.length && snippetY < size.height - 120;
        i++) {
      final tokens = codeSnippets[i];
      final inCenterZone =
          snippetY > (size.height * 0.32) && snippetY < (size.height * 0.68);
      final alphaFactor = inCenterZone ? 0.08 : 0.40;

      double x = gutterX + 14.0;
      for (final t in tokens) {
        final text = t.$1;
        final color = t.$2.withValues(alpha: alphaFactor);

        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(x, snippetY));
        x += painter.width;
      }

      if (i == (activeLineIndex % codeSnippets.length) && isRunning) {
        final cursorVisible = (time * 4).toInt() % 2 == 0;
        if (cursorVisible) {
          canvas.drawRect(
            Rect.fromLTWH(x + 2, snippetY + 1, 7, 13),
            Paint()
              ..color =
                  isEndingSoon ? AppColors.attention : const Color(0xFF38BDF8),
          );
        }
      }

      snippetY += 24.0;
    }

    // Status line at the bottom
    final footerY = size.height - 76;
    canvas.drawLine(
      Offset(0, footerY),
      Offset(size.width, footerY),
      Paint()..color = const Color(0xFF1E2633),
    );

    final statusText = !isRunning
        ? 'NORMAL  ·  UTF-8  ·  Dart 3.6  ·  PAUSED'
        : (isEndingSoon
            ? 'COMPLETING  ·  SPRINT COMMIT READY  ·  WRAP UP'
            : 'NORMAL  ·  UTF-8  ·  Dart 3.6  ·  ACTIVE FLOW');
    final statusPainter = TextPainter(
      text: TextSpan(
        text: statusText,
        style: TextStyle(
          color: isEndingSoon
              ? AppColors.attention
              : (isRunning ? const Color(0xFF475569) : const Color(0xFFF59E0B)),
          fontSize: 9.5,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    statusPainter.paint(canvas, Offset(16, footerY + 6));
  }

  @override
  bool shouldRepaint(covariant _CodingWorkspacePainter old) =>
      old.time != time ||
      old.progress != progress ||
      old.isRunning != isRunning ||
      old.isEndingSoon != isEndingSoon;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. READING WORKSPACE PAINTER: Open book layout, typographic guides, ribbon.
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingWorkspacePainter extends CustomPainter {
  _ReadingWorkspacePainter({
    required this.time,
    required this.pulse,
    required this.progress,
    required this.isRunning,
    required this.isEndingSoon,
  });

  final double time;
  final double pulse;
  final double progress;
  final bool isRunning;
  final bool isEndingSoon;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFFAF7F2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final midX = size.width / 2;

    // Center crease
    canvas.drawLine(
      Offset(midX, 60),
      Offset(midX, size.height - 80),
      Paint()
        ..color = const Color(0xFFE5DFD4)
        ..strokeWidth = 1.0,
    );

    final leftX = 28.0;
    final rightX = midX + 16.0;
    final colWidth = midX - 44.0;
    final pageFlutter = isRunning ? math.sin(time * 2 * math.pi) * 3.0 : 0.0;

    final totalLines = ((size.height - 160) / 24).floor();
    final activeLine =
        ((progress * totalLines).toInt()).clamp(0, totalLines - 1);

    for (int i = 0; i < totalLines; i++) {
      final y = 70.0 + (i * 24.0);
      final inCenterZone = y > (size.height * 0.30) && y < (size.height * 0.65);
      final isCurrent = i == activeLine;

      final alpha = inCenterZone ? 0.05 : 0.18;
      final linePaint = Paint()
        ..color = isCurrent && isRunning
            ? (isEndingSoon
                ? AppColors.attention
                : AppColors.decorCoral.withValues(alpha: 0.65))
            : AppColors.textSecondary.withValues(alpha: alpha)
        ..strokeWidth = isCurrent && isRunning ? 2.0 : 1.2
        ..strokeCap = StrokeCap.round;

      final leftLen = (i % 3 == 0) ? colWidth * 0.72 : colWidth;
      canvas.drawLine(Offset(leftX, y), Offset(leftX + leftLen, y), linePaint);

      final rightLen = (i % 2 == 0) ? colWidth * 0.85 : colWidth;
      canvas.drawLine(
        Offset(rightX, y + pageFlutter * 0.2),
        Offset(rightX + rightLen, y + pageFlutter * 0.2),
        linePaint,
      );

      if (isCurrent && isRunning && !inCenterZone) {
        final guidePaint = Paint()
          ..color = (isEndingSoon ? AppColors.attention : AppColors.decorCoral)
              .withValues(alpha: 0.09)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(leftX - 4, y - 6, colWidth + 8, 14),
            const Radius.circular(3),
          ),
          guidePaint,
        );
      }
    }

    // Silk bookmark ribbon
    final ribbonX = size.width - 32;
    final ribbonH = (isEndingSoon ? 140.0 : 110.0) + pageFlutter;
    final ribbonPath = Path()
      ..moveTo(ribbonX, 0)
      ..lineTo(ribbonX, ribbonH)
      ..lineTo(ribbonX + 5, ribbonH - 6)
      ..lineTo(ribbonX + 10, ribbonH)
      ..lineTo(ribbonX + 10, 0);
    canvas.drawPath(
      ribbonPath,
      Paint()
        ..color = (isEndingSoon ? AppColors.attention : AppColors.decorCoral)
            .withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _ReadingWorkspacePainter old) =>
      old.time != time ||
      old.pulse != pulse ||
      old.progress != progress ||
      old.isRunning != isRunning ||
      old.isEndingSoon != isEndingSoon;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. STUDY WORKSPACE PAINTER: Academic notebook, margin rules, derivations.
// ─────────────────────────────────────────────────────────────────────────────

class _StudyWorkspacePainter extends CustomPainter {
  _StudyWorkspacePainter({
    required this.time,
    required this.progress,
    required this.isRunning,
    required this.isEndingSoon,
  });

  final double time;
  final double progress;
  final bool isRunning;
  final bool isEndingSoon;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFFCFBF7);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Margin rule
    const marginX = 46.0;
    canvas.drawLine(
      const Offset(marginX, 0),
      Offset(marginX, size.height),
      Paint()
        ..color = AppColors.decorCoral.withValues(alpha: 0.45)
        ..strokeWidth = 1.2,
    );

    // Ruled lines
    final rulePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.9;
    final totalLines = ((size.height - 120) / 24).floor();

    for (int i = 0; i < totalLines; i++) {
      final y = 60.0 + (i * 24.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
    }

    // Progressive study notes & derivations
    final activeCount = ((progress * 14).toInt() + 1).clamp(1, 12);
    final notePaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < activeCount; i++) {
      final y = 84.0 + (i * 48.0);
      if (y > size.height - 100) break;

      final inCenterZone = y > (size.height * 0.32) && y < (size.height * 0.65);
      final alpha = inCenterZone ? 0.08 : 0.65;

      canvas.drawCircle(
        Offset(marginX + 8, y - 6),
        2.2,
        Paint()
          ..color = (isEndingSoon ? AppColors.attention : AppColors.action)
              .withValues(alpha: alpha),
      );

      final strokeW = (i % 2 == 0 ? size.width * 0.55 : size.width * 0.42);
      final strokePath = Path()..moveTo(marginX + 16, y - 6);
      strokePath.quadraticBezierTo(
        marginX + (strokeW * 0.5),
        y - 6 - (i % 2 == 0 ? 3.0 : -2.0),
        marginX + strokeW,
        y - 6,
      );
      canvas.drawPath(strokePath,
          notePaint..color = AppColors.textPrimary.withValues(alpha: alpha));

      if (i == activeCount - 1 && isRunning && !inCenterZone) {
        final tipX = marginX + strokeW + 6;
        canvas.drawCircle(
          Offset(tipX, y - 6),
          3.0,
          Paint()
            ..color = isEndingSoon ? AppColors.attention : AppColors.action,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StudyWorkspacePainter old) =>
      old.time != time ||
      old.progress != progress ||
      old.isRunning != isRunning ||
      old.isEndingSoon != isEndingSoon;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. DEEP WORK WORKSPACE PAINTER: Architectural coordinate grid, harmonic lattice.
// ─────────────────────────────────────────────────────────────────────────────

class _DeepWorkWorkspacePainter extends CustomPainter {
  _DeepWorkWorkspacePainter({
    required this.time,
    required this.pulse,
    required this.progress,
    required this.isRunning,
    required this.isEndingSoon,
  });

  final double time;
  final double pulse;
  final double progress;
  final bool isRunning;
  final bool isEndingSoon;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF7F6F2);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Architectural grid dots
    final dotPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.50);
    for (double x = 20; x < size.width; x += 28) {
      for (double y = 30; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
      }
    }

    final center = Offset(size.width / 2, size.height * 0.44);

    // Crosshairs
    final crossPaint = Paint()
      ..color = (isEndingSoon ? AppColors.attention : AppColors.textSecondary)
          .withValues(alpha: 0.25)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - 24, center.dy),
        Offset(center.dx + 24, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 24),
        Offset(center.dx, center.dy + 24), crossPaint);

    // Expanding harmonic resonance wave
    final baseRadius = isEndingSoon ? size.width * 0.32 : size.width * 0.38;
    final waveR = baseRadius + (pulse * (isEndingSoon ? 20.0 : 30.0));
    canvas.drawCircle(
      center,
      waveR,
      Paint()
        ..color = (isEndingSoon ? AppColors.attention : const Color(0xFFF59E0B))
            .withValues(alpha: (1.0 - pulse) * 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isEndingSoon ? 1.6 : 1.2,
    );

    // Rotating orbital ellipses
    final orbitAngles = [
      -math.pi / 6 + (time * 0.35 * (isRunning ? 1.0 : 0.0)),
      math.pi / 3 - (time * 0.25 * (isRunning ? 1.0 : 0.0)),
    ];

    for (int i = 0; i < 2; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(orbitAngles[i]);

      final ellipsePaint = Paint()
        ..color = (isEndingSoon
                ? AppColors.attention
                : (i == 0 ? AppColors.attention : AppColors.action))
            .withValues(alpha: 0.24 + (pulse * 0.12))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: baseRadius * 2.2,
        height: baseRadius * 1.1,
      );
      canvas.drawOval(rect, ellipsePaint);

      final nodeAngle = (time * 2 * math.pi * (i == 0 ? 0.9 : -0.7));
      final nodeX = (baseRadius * 1.1) * math.cos(nodeAngle);
      final nodeY = (baseRadius * 0.55) * math.sin(nodeAngle);

      canvas.drawCircle(
        Offset(nodeX, nodeY),
        3.5,
        Paint()
          ..color = isEndingSoon
              ? AppColors.attention
              : (i == 0 ? AppColors.attention : AppColors.action),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DeepWorkWorkspacePainter old) =>
      old.time != time ||
      old.pulse != pulse ||
      old.progress != progress ||
      old.isRunning != isRunning ||
      old.isEndingSoon != isEndingSoon;
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. ASSIGNMENT WORKSPACE PAINTER: Deliverable checklist with progressive ticks.
// ─────────────────────────────────────────────────────────────────────────────

class _AssignmentWorkspacePainter extends CustomPainter {
  _AssignmentWorkspacePainter({
    required this.time,
    required this.progress,
    required this.isRunning,
    required this.isEndingSoon,
  });

  final double time;
  final double progress;
  final bool isRunning;
  final bool isEndingSoon;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF8F9FA);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.6)
      ..strokeWidth = 0.8;
    canvas.drawLine(
        const Offset(32, 60), Offset(32, size.height - 80), gridPaint);
    canvas.drawLine(Offset(size.width - 32, 60),
        Offset(size.width - 32, size.height - 80), gridPaint);

    final items = [
      'Problem scope and objectives',
      'Literature & methodology notes',
      'Execution and core solution',
      'Quality review and conclusion',
    ];

    double y = 80.0;
    final completedCount =
        isEndingSoon ? items.length : (progress * items.length).floor();

    for (int i = 0; i < items.length; i++) {
      final isDone = i < completedCount;
      final isCurrent = i == completedCount;

      final inCenterZone = y > (size.height * 0.32) && y < (size.height * 0.65);
      final alpha = inCenterZone ? 0.08 : 1.0;

      final boxRect = Rect.fromLTWH(38, y, 13, 13);
      final boxPaint = Paint()
        ..color = (isDone
                ? (isEndingSoon ? const Color(0xFF10B981) : AppColors.action)
                : (isCurrent ? AppColors.attention : AppColors.divider))
            .withValues(alpha: alpha)
        ..style = isDone ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.3;
      canvas.drawRRect(
          RRect.fromRectAndRadius(boxRect, const Radius.circular(3)), boxPaint);

      if (isDone) {
        final checkPath = Path()
          ..moveTo(41, y + 6.5)
          ..lineTo(43.5, y + 9.5)
          ..lineTo(48, y + 3.5);
        canvas.drawPath(
          checkPath,
          Paint()
            ..color = Colors.white.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
      }

      final itemPainter = TextPainter(
        text: TextSpan(
          text: items[i],
          style: TextStyle(
            color: (isDone
                    ? AppColors.textSecondary
                    : (isCurrent
                        ? AppColors.textPrimary
                        : AppColors.textSecondary))
                .withValues(alpha: alpha),
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            decoration: isDone ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.textSecondary.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      itemPainter.paint(canvas, Offset(58, y));

      y += 28.0;
    }
  }

  @override
  bool shouldRepaint(covariant _AssignmentWorkspacePainter old) =>
      old.time != time ||
      old.progress != progress ||
      old.isRunning != isRunning ||
      old.isEndingSoon != isEndingSoon;
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. FLOW WORKSPACE PAINTER: Ultradian BRAC cycle canvas (Kleitman, 1963 — 90m focus / 20m rest).
// ─────────────────────────────────────────────────────────────────────────────

class _FlowWorkspacePainter extends CustomPainter {
  _FlowWorkspacePainter({
    required this.time,
    required this.pulse,
    required this.progress,
    required this.isRunning,
    required this.isEndingSoon,
  });

  final double time;
  final double pulse;
  final double progress;
  final bool isRunning;
  final bool isEndingSoon;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0A1815);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final midY = size.height * 0.44;

    // Soft matrix dots
    final dotPaint = Paint()
      ..color = const Color(0xFF13362E).withValues(alpha: 0.60);
    for (double x = 20; x < size.width; x += 32) {
      for (double y = 40; y < size.height; y += 32) {
        canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
      }
    }

    // Dual flowing sine waves (Ultradian Focus & Rest cycle)
    final wavePaint1 = Paint()
      ..color = (isEndingSoon ? AppColors.attention : const Color(0xFF10B981))
          .withValues(alpha: isEndingSoon ? 0.45 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final wavePaint2 = Paint()
      ..color = (isEndingSoon ? AppColors.attention : const Color(0xFF0EA5E9))
          .withValues(alpha: isEndingSoon ? 0.35 : 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path1 = Path();
    final path2 = Path();

    final waveSpeed = isRunning ? (time * 2 * math.pi) : 0.0;
    final waveAmplitude = isEndingSoon ? 22.0 + (pulse * 6.0) : 34.0;

    for (double x = 0; x <= size.width; x += 4) {
      final normalizedX = x / size.width;
      final y1 = midY +
          math.sin((normalizedX * 3.0 * math.pi) + waveSpeed) * waveAmplitude;
      final y2 = midY +
          math.cos((normalizedX * 2.5 * math.pi) - waveSpeed * 0.7) *
              (waveAmplitude * 0.75);

      if (x == 0) {
        path1.moveTo(x, y1);
        path2.moveTo(x, y2);
      } else {
        path1.lineTo(x, y1);
        path2.lineTo(x, y2);
      }
    }

    canvas.drawPath(path1, wavePaint1);
    canvas.drawPath(path2, wavePaint2);

    // Focal breathing glow behind timer
    final center = Offset(size.width / 2, midY);
    final glowRadius = (size.width * 0.35) + (pulse * 18.0);
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..color = (isEndingSoon ? AppColors.attention : const Color(0xFF10B981))
            .withValues(alpha: (1.0 - pulse) * (isEndingSoon ? 0.16 : 0.10))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Status baseline
    final footerY = size.height - 76;
    canvas.drawLine(
      Offset(0, footerY),
      Offset(size.width, footerY),
      Paint()..color = const Color(0xFF15332B),
    );

    final statusText = !isRunning
        ? 'ULTRADIAN FLOW  ·  90M FOCUS / 20M REST  ·  PAUSED'
        : (isEndingSoon
            ? 'ULTRADIAN FLOW  ·  RECOVERY PHASE  ·  20M BREAK APPROACHING'
            : 'ULTRADIAN FLOW  ·  90M FOCUS PHASE  ·  PEAK CYCLE');
    final statusPainter = TextPainter(
      text: TextSpan(
        text: statusText,
        style: TextStyle(
          color: isEndingSoon
              ? AppColors.attention
              : (isRunning ? const Color(0xFF34D399) : const Color(0xFF94A3B8)),
          fontSize: 9.5,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    statusPainter.paint(canvas, Offset(16, footerY + 6));
  }

  @override
  bool shouldRepaint(covariant _FlowWorkspacePainter old) =>
      old.time != time ||
      old.pulse != pulse ||
      old.progress != progress ||
      old.isRunning != isRunning ||
      old.isEndingSoon != isEndingSoon;
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER FUNCTIONS & DIALOGS
// ─────────────────────────────────────────────────────────────────────────────

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
