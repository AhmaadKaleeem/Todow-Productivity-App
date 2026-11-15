import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/core/utils/date_format.dart';
import 'package:todow/data/local/focus_activity_store.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/focus_activity.dart';
import 'package:todow/domain/models/focus_activity_template.dart';
import 'package:todow/domain/models/focus_session.dart';
import 'package:todow/domain/models/focus_timeline.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/presentation/providers/focus_providers.dart';
import 'package:todow/presentation/providers/task_providers.dart';
import 'package:todow/presentation/widgets/beautiful_back_button.dart';
import 'package:todow/presentation/widgets/corner_arc_decor.dart';
import 'package:todow/presentation/widgets/focus_activity_scene.dart';
import 'package:uuid/uuid.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  FocusPreset _preset = FocusPreset.study;
  FocusActivityCategory _activityCategory = FocusActivityCategory.learning;
  final FocusActivityStore _activityStore = FocusActivityStore();
  FocusActivitySettings _activitySettings = const FocusActivitySettings();
  FocusActivityTemplate? _selectedTemplate;
  Duration _customDuration = const Duration(minutes: 50);
  String? _taskId;
  bool _zenMode = false;
  bool _showWorkspace = true;
  late final TextEditingController _manualTimeController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _manualTimeController =
        TextEditingController(text: '${_customDuration.inMinutes}');
    _loadActivitySettings();
  }

  @override
  void dispose() {
    _manualTimeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = ref.read(focusSessionProvider);
    final shouldRun = state == AppLifecycleState.resumed &&
        session?.status == FocusSessionStatus.running &&
        session!.remainingAt(DateTime.now()) > Duration.zero;
    _syncTicker(enabled: shouldRun);
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _syncTicker({bool enabled = false}) {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (!enabled ||
        lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.hidden ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onPresetSelected(FocusPreset preset) {
    setState(() {
      _preset = preset;
      _selectedTemplate = null;
      _customDuration =
          Duration(minutes: _activitySettings.durationFor(preset));
      _manualTimeController.text = '${_customDuration.inMinutes}';
    });
  }

  Future<void> _loadActivitySettings() async {
    final settings = await _activityStore.load();
    if (!mounted) return;
    setState(() {
      _activitySettings = settings;
      if (_selectedTemplate == null) {
        _customDuration = Duration(minutes: settings.durationFor(_preset));
        _manualTimeController.text = '${_customDuration.inMinutes}';
      }
    });
  }

  Future<void> _persistActivitySettings(
    FocusActivitySettings settings,
  ) async {
    setState(() => _activitySettings = settings);
    try {
      await _activityStore.save(settings);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save focus activity settings.')),
      );
    }
  }

  void _onTemplateSelected(FocusActivityTemplate activity) {
    final visualPreset = activity.visualPreset ?? FocusPreset.deepWork;
    setState(() {
      _activityCategory = FocusActivityCategory.userActivities;
      _selectedTemplate = activity;
      _preset = visualPreset;
      _customDuration = Duration(minutes: activity.defaultDurationMinutes);
      _manualTimeController.text = '${_customDuration.inMinutes}';
    });
  }

  Future<void> _saveSelectedDurationAsDefault() async {
    final template = _selectedTemplate;
    if (template != null) {
      final updated = template.copyWith(
        defaultDurationMinutes: _customDuration.inMinutes,
      );
      final activities = _activitySettings.customActivities
          .map((item) => item.id == template.id ? updated : item)
          .toList();
      setState(() => _selectedTemplate = updated);
      await _persistActivitySettings(
        _activitySettings.copyWith(customActivities: activities),
      );
      return;
    }
    final defaults = Map<String, int>.from(_activitySettings.defaultDurations)
      ..[_preset.name] = _customDuration.inMinutes;
    await _persistActivitySettings(
      _activitySettings.copyWith(defaultDurations: defaults),
    );
  }

  void _onActivityCategorySelected(FocusActivityCategory category) {
    if (category == FocusActivityCategory.userActivities) {
      setState(() {
        _activityCategory = category;
        _selectedTemplate = null;
      });
      return;
    }
    final first = FocusActivityDefinition.inCategory(category).first.activity;
    setState(() {
      _activityCategory = category;
      _selectedTemplate = null;
      _preset = first;
      _customDuration = Duration(minutes: _activitySettings.durationFor(first));
      _manualTimeController.text = '${_customDuration.inMinutes}';
    });
  }

  void _adjustDuration(int minutesDelta) {
    final newMin = (_customDuration.inMinutes + minutesDelta).clamp(1, 360);
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
    _syncTicker(
      enabled: session?.status == FocusSessionStatus.running &&
          session!.remainingAt(DateTime.now()) > Duration.zero,
    );

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
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                          : 'FOCUS ACTIVITY'),
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
        ],
      ),
      bottomNavigationBar: session == null
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: _buildStartButton(focus, tasks),
              ),
            )
          : null,
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
              session.activityName ?? session.preset.label,
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
    final isCustom = _activityCategory == FocusActivityCategory.userActivities;
    final activities = isCustom
        ? const <FocusActivityDefinition>[]
        : FocusActivityDefinition.inCategory(_activityCategory);
    final customActivities = _activitySettings.customActivities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FocusActivityCategory.values.map((category) {
            return ChoiceChip(
              label: Text(category.label),
              selected: _activityCategory == category,
              onSelected: (_) => _onActivityCategorySelected(category),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const StadiumBorder(),
              selectedColor: AppColors.action.withValues(alpha: 0.14),
              side: BorderSide(
                color: _activityCategory == category
                    ? AppColors.action
                    : AppColors.divider,
              ),
              labelStyle: TextStyle(
                color: _activityCategory == category
                    ? AppColors.action
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        if (isCustom) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _editCustomActivity(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create activity'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.action,
                side: const BorderSide(color: AppColors.action),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (customActivities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Create your own activity, with an optional group and subgroup.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            )
          else
            ...customActivities.map(_buildCustomActivityOption),
        ] else
          ...activities.map(_buildActivityOption),
        const SizedBox(height: 12),
        FocusActivityScene(
          preset: _preset,
          timeline: FocusTimeline.preview,
          isRunning: false,
          compact: true,
          showPhaseLabel: false,
          activityLabel: _selectedTemplate?.name,
          mixedEnvironment: _selectedTemplate?.visualPreset == null &&
              _selectedTemplate != null,
          accent: _selectedTemplate == null
              ? null
              : _templateAccent(_selectedTemplate!),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedTemplate == null
              ? FocusActivityDefinition.forActivity(_preset).description
              : _selectedTemplate!.categoryLabel.isEmpty
                  ? 'A custom activity in your saved collection.'
                  : _selectedTemplate!.categoryLabel,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        if (_selectedTemplate == null && _preset == FocusPreset.flow) ...[
          const SizedBox(height: 10),
          _buildUltradianCard(),
        ],
      ],
    );
  }

  Widget _buildActivityOption(FocusActivityDefinition definition) {
    final preset = definition.activity;
    final selected = _selectedTemplate == null && _preset == preset;
    final gradient = _activityGradient(_activityCategory);
    final workSurface = preset == FocusPreset.flow
        ? 'FOCUS  ${_customDuration.inMinutes} MIN  ·  RECOVER  20 MIN'
        : definition.workSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: InkWell(
          onTap: () => _onPresetSelected(preset),
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? null : AppColors.surface,
              gradient: selected ? gradient : null,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? gradient.colors.first : AppColors.divider,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.label,
                        style: TextStyle(
                          color:
                              selected ? Colors.white : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        workSurface,
                        style: TextStyle(
                          color: selected
                              ? Colors.white70
                              : AppColors.textSecondary,
                          fontSize: 9,
                          letterSpacing: 0.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${selected ? _customDuration.inMinutes : _activitySettings.durationFor(preset)}m',
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? Colors.white : AppColors.divider,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomActivityOption(FocusActivityTemplate activity) {
    final selected = _selectedTemplate?.id == activity.id;
    final gradient = _templateGradient(activity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTemplateSelected(activity),
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(13, 10, 4, 10),
            decoration: BoxDecoration(
              color: selected ? null : AppColors.surface,
              gradient: selected ? gradient : null,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? gradient.colors.first : AppColors.divider,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              selected ? Colors.white : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (activity.categoryLabel.isNotEmpty)
                        Text(
                          activity.categoryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? Colors.white70
                                : AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${selected ? _customDuration.inMinutes : activity.defaultDurationMinutes}m',
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Activity options',
                  icon: Icon(
                    Icons.more_vert,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  onSelected: (action) {
                    if (action == 'edit') _editCustomActivity(activity);
                    if (action == 'delete') _deleteCustomActivity(activity);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit activity')),
                    PopupMenuItem(
                        value: 'delete', child: Text('Delete activity')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editCustomActivity([
    FocusActivityTemplate? existing,
  ]) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final groupController =
        TextEditingController(text: existing?.groupName ?? '');
    final subgroupController =
        TextEditingController(text: existing?.subgroupName ?? '');
    final durationController = TextEditingController(
      text: '${existing?.defaultDurationMinutes ?? 50}',
    );
    var visualPresetName = existing?.visualPresetName;

    final saved = await showDialog<FocusActivityTemplate>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Create activity' : 'Edit activity'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Activity name',
                        hintText: 'Workout',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter an activity name'
                              : null,
                    ),
                    TextFormField(
                      controller: groupController,
                      maxLength: 30,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Group (optional)',
                        hintText: 'Fitness',
                      ),
                    ),
                    TextFormField(
                      controller: subgroupController,
                      maxLength: 30,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Subgroup (optional)',
                        hintText: 'Strength, cardio',
                      ),
                    ),
                    TextFormField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Default duration (minutes)',
                        hintText: '50',
                      ),
                      validator: (value) {
                        final minutes = int.tryParse(value?.trim() ?? '');
                        return minutes == null || minutes < 1 || minutes > 360
                            ? 'Choose between 1 and 360 minutes'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: visualPresetName,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Environment',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Auto match, or use mixed environment'),
                        ),
                        ...FocusPreset.values.map(
                          (preset) => DropdownMenuItem<String?>(
                            value: preset.name,
                            child: Text(preset.label),
                          ),
                        ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => visualPresetName = value,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose a matching activity scene, or use the mixed environment for activities without a close match.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  dialogContext,
                  FocusActivityTemplate(
                    id: existing?.id ?? const Uuid().v4(),
                    name: nameController.text.trim(),
                    groupName: _optionalValue(groupController.text),
                    subgroupName: _optionalValue(subgroupController.text),
                    defaultDurationMinutes:
                        int.parse(durationController.text.trim()),
                    visualPresetName: visualPresetName,
                  ),
                );
              },
              child: const Text('Save activity'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    groupController.dispose();
    subgroupController.dispose();
    durationController.dispose();
    if (saved == null || !mounted) return;

    final activities = [..._activitySettings.customActivities];
    final index = activities.indexWhere((activity) => activity.id == saved.id);
    if (index < 0) {
      activities.add(saved);
    } else {
      activities[index] = saved;
    }
    await _persistActivitySettings(
      _activitySettings.copyWith(customActivities: activities),
    );
    _onTemplateSelected(saved);
  }

  Future<void> _deleteCustomActivity(FocusActivityTemplate activity) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete activity?'),
        content: Text('“${activity.name}” will be removed from your list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete != true || !mounted) return;
    final activities = _activitySettings.customActivities
        .where((item) => item.id != activity.id)
        .toList();
    await _persistActivitySettings(
      _activitySettings.copyWith(customActivities: activities),
    );
    if (_selectedTemplate?.id == activity.id) {
      _onActivityCategorySelected(FocusActivityCategory.userActivities);
    }
  }

  LinearGradient _activityGradient(FocusActivityCategory category) {
    final palette = switch (category) {
      FocusActivityCategory.development ||
      FocusActivityCategory.personalGrowth ||
      FocusActivityCategory.userActivities =>
        0,
      FocusActivityCategory.learning || FocusActivityCategory.creativeWork => 1,
      FocusActivityCategory.professionalWork ||
      FocusActivityCategory.analyticalWork =>
        2,
    };
    return _gradientPalette(palette);
  }

  LinearGradient _templateGradient(FocusActivityTemplate activity) {
    final visualPreset = activity.visualPreset;
    if (visualPreset != null) {
      return _activityGradient(
        FocusActivityDefinition.forActivity(visualPreset).category,
      );
    }
    final group = (activity.groupName ?? activity.name).toLowerCase();
    final palette = group.contains('art') ||
            group.contains('creative') ||
            group.contains('learn')
        ? 1
        : group.contains('work') ||
                group.contains('finance') ||
                group.contains('fitness') ||
                group.contains('health')
            ? 2
            : 0;
    return _gradientPalette(palette);
  }

  Color _templateAccent(FocusActivityTemplate activity) =>
      _templateGradient(activity).colors.first;

  LinearGradient _gradientPalette(int index) => switch (index) {
        0 => const LinearGradient(
            colors: [AppColors.action, Color(0xFF0284C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        1 => const LinearGradient(
            colors: [AppColors.decorPink, AppColors.decorCoral],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        _ => const LinearGradient(
            colors: [AppColors.attention, AppColors.decorCoral],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
      };

  String? _optionalValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Widget _buildUltradianCard() {
    final isSelected = _preset == FocusPreset.flow;

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
                    _durationChip('${_customDuration.inMinutes}m', isSelected,
                        work: true),
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
                    _durationChip(
                        '${FocusPreset.flow.restDuration.inMinutes}m break',
                        isSelected,
                        work: false),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Plain-language benefit line for student reader
            Text(
              'A longer work block paired with a full break. Treat these durations as a starting point and adjust them to your task and energy.',
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
                _statPill('${_customDuration.inMinutes} min', 'Work block',
                    isSelected),
                const SizedBox(width: 8),
                _statPill('${FocusPreset.flow.restDuration.inMinutes} min',
                    'Recovery', isSelected),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = Column(
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
          );
          final stepper = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _durationButton(
                icon: Icons.remove_rounded,
                onTap: () => _adjustDuration(-5),
              ),
              const SizedBox(width: 8),
              Container(
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
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
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
              const SizedBox(width: 8),
              _durationButton(
                icon: Icons.add_rounded,
                onTap: () => _adjustDuration(5),
              ),
            ],
          );
          final saveDefault = TextButton.icon(
            onPressed:
                _activityCategory == FocusActivityCategory.userActivities &&
                        _selectedTemplate == null
                    ? null
                    : _saveSelectedDurationAsDefault,
            icon: const Icon(Icons.bookmark_add_outlined, size: 17),
            label: const Text('Save duration as default'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.action,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: summary),
                  stepper,
                ],
              ),
              if (constraints.maxWidth < 400)
                saveDefault
              else
                Align(alignment: Alignment.centerRight, child: saveDefault),
            ],
          );
        },
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
            activity: _selectedTemplate,
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

class _ActiveFocusViewState extends State<_ActiveFocusView> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeline = FocusTimeline.fromSession(widget.session, now);
    final progress = timeline.progress;
    final isComplete = widget.remaining == Duration.zero;
    final isRunning =
        widget.session.status == FocusSessionStatus.running && !isComplete;
    final isEndingSoon = !isComplete &&
        ((widget.remaining.inSeconds <= 300 &&
                widget.remaining > Duration.zero) ||
            progress >= 0.88);
    final preset = widget.session.preset;
    final accent = widget.session.activityName == null
        ? _presetAccentColor(preset)
        : _sessionActivityAccent(widget.session);
    const bgColor = AppColors.background;
    const textPrimaryColor = AppColors.textPrimary;
    const textSecondaryColor = AppColors.textSecondary;
    final isCompact = MediaQuery.sizeOf(context).height < 700;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: FocusActivityScene(
              preset: preset,
              timeline: timeline,
              isRunning: isRunning,
              activityLabel: widget.session.activityName,
              mixedEnvironment: widget.session.mixedEnvironment,
              accent: widget.session.activityName == null ? null : accent,
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.session.activityName ?? preset.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: textSecondaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                            isComplete
                                ? _motivationMessage(timeline, preset)
                                : isRunning
                                    ? _motivationMessage(timeline, preset)
                                    : 'Session paused',
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
                          onPressed: isComplete
                              ? null
                              : isRunning
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
                            isComplete
                                ? 'Session complete'
                                : isRunning
                                    ? 'Pause Session'
                                    : 'Resume Session',
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

  String _motivationMessage(FocusTimeline timeline, FocusPreset preset) {
    if (timeline.phase == FocusAnimationPhase.completion) {
      return preset == FocusPreset.flow
          ? 'Work block complete. Begin your ${preset.restDuration.inMinutes}-minute recovery break.'
          : 'Session complete. Take a well-earned rest.';
    }
    return switch (timeline.phase) {
      FocusAnimationPhase.entry =>
        'Arrive at the task. Let your attention settle.',
      FocusAnimationPhase.settling => 'Choose one clear next step and begin.',
      FocusAnimationPhase.deepFocus => 'Stay with the thread of work.',
      FocusAnimationPhase.progression => 'Keep one goal in view.',
      FocusAnimationPhase.finalPhase =>
        'Find a good stopping point and leave a note for next time.',
      FocusAnimationPhase.completion => 'Session complete.',
    };
  }
}

Color _presetAccentColor(FocusPreset preset) {
  return switch (FocusActivityDefinition.forActivity(preset).category) {
    FocusActivityCategory.development => AppColors.action,
    FocusActivityCategory.learning => AppColors.decorNavy,
    FocusActivityCategory.creativeWork => AppColors.decorPink,
    FocusActivityCategory.professionalWork => AppColors.attention,
    FocusActivityCategory.personalGrowth => AppColors.decorCoral,
    FocusActivityCategory.analyticalWork => const Color(0xFF43877F),
    FocusActivityCategory.userActivities => AppColors.action,
  };
}

Color _sessionActivityAccent(FocusSession session) {
  final group =
      (session.activityGroup ?? session.activityName ?? '').toLowerCase();
  if (group.contains('creative') ||
      group.contains('art') ||
      group.contains('learn')) {
    return AppColors.decorPink;
  }
  if (group.contains('work') ||
      group.contains('finance') ||
      group.contains('fitness') ||
      group.contains('health')) {
    return AppColors.attention;
  }
  return AppColors.action;
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
