import 'package:flutter/material.dart';
import 'package:todow/bootstrap.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/presentation/app.dart';
import 'package:todow/presentation/screens/home_screen.dart';
import 'package:todow/presentation/screens/roadmap_list_screen.dart';
import 'package:todow/presentation/screens/notification_permission_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/presentation/providers/app_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.services, super.key});
  final AppServices services;
  @override
  ConsumerState<AppShell> createState() => AppShellState();
}

class AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _animationController;
  final Map<int, Offset> _pointerOrigins = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('has_prompted_notifications') ?? false;
    
    // We get the current permission status
    final hasPerms = await ref.read(notificationPermissionsProvider.future);
    
    if (!hasPerms && !hasPrompted && mounted) {
      await prefs.setBool('has_prompted_notifications', true);
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => NotificationPermissionScreen(
          onEnable: () async {
            await ref.read(notificationPermissionsProvider.notifier).requestPermissions();
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void toggleDrawer() {
    _animateDrawer(_animationController.value < 0.5);
  }

  void selectPage(int index) {
    if (index < 0 || index >= 5) return;
    setState(() => _index = index);
    _animateDrawer(false);
  }

  void _animateDrawer(bool open) {
    _animationController.animateTo(
      open ? 1 : 0,
      duration: Duration(milliseconds: open ? 320 : 220),
      curve: open ? Curves.easeOutCubic : Curves.easeInCubic,
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    final origin = _pointerOrigins.remove(event.pointer);
    if (origin == null) return;
    final delta = event.position - origin;
    if (delta.dx.abs() < 72 || delta.dx.abs() < delta.dy.abs() * 1.35) return;

    if (delta.dx > 0 && _animationController.value < 0.5) {
      _animateDrawer(true);
    } else if (delta.dx < 0 && _animationController.value >= 0.5) {
      _animateDrawer(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const TasksScreen(),
      const FocusScreen(),
      const TimetableScreen(),
      const RoadmapListScreen(),
    ];

    return AppShellScope(
      state: this,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Listener(
          onPointerDown: (event) =>
              _pointerOrigins[event.pointer] = event.position,
          onPointerUp: _onPointerUp,
          onPointerCancel: (event) => _pointerOrigins.remove(event.pointer),
          child: Stack(
            children: [
              ColoredBox(
                color: AppColors.background,
                child: SafeArea(
                  child: SizedBox(
                    width: 280,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.decorPink, width: 2),
                                    ),
                                    child: const CircleAvatar(
                                      radius: 23,
                                      backgroundColor: AppColors.action,
                                      child: Icon(Icons.person,
                                          color: Colors.white, size: 25),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  FutureBuilder<SharedPreferences>(
                                      future: SharedPreferences.getInstance(),
                                      builder: (context, snapshot) {
                                        final name = snapshot.data
                                                ?.getString('username') ??
                                            'Student';
                                        return Text(name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 21,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary));
                                      }),
                                  const SizedBox(height: 24),
                                  const _DrawerSectionLabel('MAIN'),
                                  const SizedBox(height: 10),
                                  _DrawerItem(
                                      animation: _animationController,
                                      index: 0,
                                      label: 'Home',
                                      accent: AppColors.action,
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.action,
                                          Color(0xFF0284C7),
                                        ],
                                      ),
                                      selected: _index == 0,
                                      onTap: () {
                                        setState(() => _index = 0);
                                        _animateDrawer(false);
                                      }),
                                  _DrawerItem(
                                      animation: _animationController,
                                      index: 1,
                                      label: 'Tasks',
                                      accent: AppColors.decorPink,
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.decorPink,
                                          AppColors.decorCoral,
                                        ],
                                      ),
                                      selected: _index == 1,
                                      onTap: () {
                                        setState(() => _index = 1);
                                        _animateDrawer(false);
                                      }),
                                  _DrawerItem(
                                      animation: _animationController,
                                      index: 2,
                                      label: 'Focus',
                                      accent: AppColors.attention,
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.attention,
                                          Color(0xFFF97316),
                                        ],
                                      ),
                                      selected: _index == 2,
                                      onTap: () {
                                        setState(() => _index = 2);
                                        _animateDrawer(false);
                                      }),
                                  const SizedBox(height: 8),
                                  const _DrawerSectionLabel('PLAN'),
                                  const SizedBox(height: 10),
                                  _DrawerItem(
                                      animation: _animationController,
                                      index: 3,
                                      label: 'Timetable',
                                      accent: AppColors.decorCoral,
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.decorCoral,
                                          Color(0xFFBE123C),
                                        ],
                                      ),
                                      selected: _index == 3,
                                      onTap: () {
                                        setState(() => _index = 3);
                                        _animateDrawer(false);
                                      }),
                                  _DrawerItem(
                                      animation: _animationController,
                                      index: 4,
                                      label: 'Roadmaps',
                                      accent: AppColors.decorNavy,
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.decorNavy,
                                          Color(0xFF3155A2),
                                        ],
                                      ),
                                      selected: _index == 4,
                                      onTap: () {
                                        setState(() => _index = 4);
                                        _animateDrawer(false);
                                      }),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10, bottom: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, _) => CustomPaint(
                                    size: const Size(104, 24),
                                    painter: _DrawerWavePainter(
                                        _animationController.value),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const SizedBox(
                                  width: 104,
                                  height: 28,
                                  child: Image(
                                    image: AssetImage(
                                        'assets/Tofow-App-Logo-Inapp-Transparent.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const SizedBox(
                                  width: 104,
                                  child: Text(
                                    'v1.0.2',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Main Content
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final slide = 280.0 * _animationController.value;
                  final scale = 1.0 - (0.15 * _animationController.value);
                  final radius = _animationController.value * 32.0;

                  return Transform(
                    transform: Matrix4.identity()
                      ..translate(slide, 0.0, 0.0)
                      ..scale(scale),
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: Container(
                        color: AppColors.background,
                        child: IgnorePointer(
                          ignoring: _animationController.value > 0.5,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: pages[_index],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Inherited scope so any descendant can open/close the drawer ───────────────
class AppShellScope extends InheritedWidget {
  const AppShellScope({required this.state, required super.child, super.key});
  final AppShellState state;

  static AppShellState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppShellScope>();
    assert(scope != null, 'AppShellScope not found in widget tree');
    return scope!.state;
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) => oldWidget.state != state;
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: AppColors.textSecondary,
        ),
      );
}

class _DrawerItem extends StatefulWidget {
  const _DrawerItem({
    required this.animation,
    required this.index,
    required this.label,
    required this.accent,
    required this.gradient,
    required this.selected,
    required this.onTap,
  });

  final Animation<double> animation;
  final int index;
  final String label;
  final Color accent;
  final Gradient gradient;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final start = widget.index * 0.055;
        final progress =
            ((widget.animation.value - start) / 0.48).clamp(0.0, 1.0);
        final entrance = Curves.easeOutCubic.transform(progress);
        return Opacity(
          opacity: entrance,
          child: Transform.translate(
            offset: Offset(-14 * (1 - entrance), 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          button: true,
          selected: widget.selected,
          label: widget.label,
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1,
            duration: const Duration(milliseconds: 100),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: (pressed) {
                  if (_pressed != pressed) {
                    setState(() => _pressed = pressed);
                  }
                },
                borderRadius: BorderRadius.circular(30),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: widget.selected ? widget.gradient : null,
                    color: widget.selected
                        ? null
                        : (_pressed
                            ? widget.accent.withValues(alpha: 0.12)
                            : const Color(0xFFF4F0E8)),
                    borderRadius: BorderRadius.circular(30),
                    border: widget.selected
                        ? null
                        : Border.all(
                            color: widget.accent.withValues(alpha: 0.24)),
                  ),
                  alignment: Alignment.centerLeft,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    style: TextStyle(
                      color: widget.selected
                          ? (widget.accent == AppColors.decorNavy
                              ? Colors.white
                              : AppColors.textPrimary)
                          : AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                    ),
                    child: Text(widget.label),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerWavePainter extends CustomPainter {
  const _DrawerWavePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.65)
      ..cubicTo(size.width * 0.12, size.height * 0.65, size.width * 0.12,
          size.height * 0.25, size.width * 0.25, size.height * 0.35)
      ..cubicTo(size.width * 0.39, size.height * 0.45, size.width * 0.4,
          size.height * 0.95, size.width * 0.54, size.height * 0.72)
      ..cubicTo(size.width * 0.68, size.height * 0.48, size.width * 0.67,
          size.height * 0.12, size.width * 0.79, size.height * 0.25)
      ..cubicTo(size.width * 0.9, size.height * 0.37, size.width * 0.9,
          size.height * 0.78, size.width, size.height * 0.5);
    final metric = path.computeMetrics().first;
    final visiblePath = metric.extractPath(0, metric.length * progress);
    final paint = Paint()
      ..color = AppColors.action
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(visiblePath, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawerWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
