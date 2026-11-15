import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/bootstrap.dart';
import 'package:todow/core/routing/app_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  final AppServices services;
  const SplashScreen({super.key, required this.services});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final TextEditingController _nameController = TextEditingController();

  bool _needsName = false;
  bool _hasName = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('username');
    final hasName = name != null && name.isNotEmpty;

    if (mounted) {
      setState(() {
        _hasName = hasName;
        if (!hasName) {
          _needsName = true;
        }
      });
    }

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    if (_hasName) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _proceed() async {
    if (_hasName) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 820;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 480), // Mobile width constraint
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: compact ? 12 : 40),

                    // TOP: Logo and Interlocking Floating Pills
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Logo (Now much more prominent)
                        Transform.scale(
                          scale: compact ? 1.35 : 1.8,
                          child: Image.asset(
                            'assets/Tofow-App-Logo-Inapp.png',
                            height: 100,
                            fit: BoxFit.contain,
                          )
                              .animate()
                              .fadeIn(duration: 2000.ms, curve: Curves.easeOut)
                              .slideY(
                                  begin: -0.15,
                                  end: 0,
                                  duration: 1500.ms,
                                  curve: Curves.easeOutQuint),
                        ),

                        SizedBox(height: compact ? 12 : 60),

                        // Interlocking Pills (Massive scale to bleed off edges)
                        // Interlocking Pills (Contained within screen edges, Fitplan staggered layout)
                        LayoutBuilder(builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          return SizedBox(
                            height: compact ? 210 : 280,
                            width: w,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Feature labels around the welcome message.
                                _FloatingPill(
                                  text: "Roadmaps",
                                  color: const Color(0xFFF97316),
                                  angle: 0,
                                  width: w * 0.435,
                                  right: 15,
                                  top: compact ? 139 : 185,
                                  delay: 500.ms,
                                ),
                                // 2. Reminders (Bottom left, side-by-side with Roadmaps)
                                _FloatingPill(
                                  text: "Reminders",
                                  color: const Color(0xFF60A5FA),
                                  angle: 0,
                                  width: w * 0.435,
                                  left: 15,
                                  top: compact ? 139 : 185,
                                  delay: 400.ms,
                                ),
                                // 3. Smart Tasks (Middle Left)
                                _FloatingPill(
                                  text: "Tasks",
                                  color: const Color(0xFFFBBF24),
                                  angle: 0,
                                  width: w * 0.52,
                                  left: 15,
                                  top: compact ? 79 : 105,
                                  delay: 300.ms,
                                  textColor: Colors.black87,
                                ),
                                // 4. Timetables (Top Right, staggered down to fit between Focus and Smart Tasks)
                                _FloatingPill(
                                  text: "Class schedules",
                                  color: const Color(0xFF4ADE80),
                                  angle: 0.12,
                                  width: w * 0.55,
                                  right: 10,
                                  top: compact ? 41 : 55,
                                  delay: 200.ms,
                                ),
                                // 5. Deep Focus (Top Left)
                                _FloatingPill(
                                  text: "Focus sessions",
                                  color: const Color(0xFFF2623E),
                                  angle: -0.12,
                                  width: w * 0.50,
                                  left: 10,
                                  top: compact ? 8 : 10,
                                  delay: 100.ms,
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),

                    SizedBox(height: compact ? 12 : 40),

                    // MIDDLE: Typography Section
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: _WelcomeMessage(),
                    ),

                    SizedBox(height: compact ? 16 : 56),

                    // BOTTOM: Circular Proceed Button Section
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(children: [
                          // Expandable name input / Proceed button
                          _ExpandableNameInput(
                            needsName: _needsName,
                            controller: _nameController,
                            onProceed: _proceed,
                          ).animate().fadeIn(delay: 600.ms).scale(
                              begin: const Offset(0.5, 0.5),
                              curve: Curves.elasticOut,
                              duration: 1000.ms),

                          SizedBox(height: compact ? 12 : 40),
                        ]))
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Components ---

class _FloatingPill extends StatelessWidget {
  final String text;
  final Color color;
  final double angle;
  final double? width;
  final double? left;
  final double? right;
  final double top;
  final Duration delay;
  final Color textColor;

  const _FloatingPill({
    required this.text,
    required this.color,
    required this.angle,
    this.width,
    this.left,
    this.right,
    required this.top,
    required this.delay,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ]),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                )),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
            begin: -6, end: 6, duration: 2500.ms, curve: Curves.easeInOutSine),
      ),
    )
        .animate()
        .scale(
            delay: delay,
            duration: 800.ms,
            curve: Curves.elasticOut,
            begin: const Offset(0.5, 0.5))
        .fadeIn(delay: delay, duration: 400.ms);
  }
}

class _WelcomeMessage extends StatelessWidget {
  const _WelcomeMessage();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 820;
    return Text(
        'Plan your day.\nStart with one task.',
        style: TextStyle(
          fontSize: compact ? 34 : 44,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          height: 1.15,
          letterSpacing: -1.2,
        ),
      );
  }
}

class _ExpandableNameInput extends StatefulWidget {
  final bool needsName;
  final TextEditingController controller;
  final VoidCallback onProceed;
  const _ExpandableNameInput(
      {required this.needsName,
      required this.controller,
      required this.onProceed});

  @override
  State<_ExpandableNameInput> createState() => _ExpandableNameInputState();
}

class _ExpandableNameInputState extends State<_ExpandableNameInput> {
  bool _isPressed = false;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.needsName;
  }

  @override
  void didUpdateWidget(_ExpandableNameInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.needsName != oldWidget.needsName) {
      setState(() => _expanded = widget.needsName);
    }
  }

  void _handleTap() {
    setState(() => _isPressed = false);
    if (_expanded) {
      widget.onProceed();
    } else {
      widget.onProceed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = _expanded
        ? (MediaQuery.sizeOf(context).width - 64).clamp(90.0, 300.0).toDouble()
        : 90.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => _handleTap(),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutExpo,
          width: width,
          height: 90,
          decoration: BoxDecoration(
            color: _expanded ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(45),
            boxShadow: _expanded
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              if (!_expanded) ...[
                // Outer ring track
                const SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white30),
                  ),
                ),
                // Segmented dark ring portion
                const SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: 0.25,
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.background),
                  ),
                ),
              ],

              if (_expanded)
                Positioned(
                  left: 24,
                  right: 90,
                  child: TextField(
                    controller: widget.controller,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Your name',
                      hintStyle: TextStyle(fontSize: 18, color: Colors.black38),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => widget.onProceed(),
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                ),

              // Inner Orange Button
              Container(
                width: 74,
                height: 74,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                    color: Color(0xFFF97316),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66F97316),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      )
                    ]),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
