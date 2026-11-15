import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/presentation/app_shell.dart';

class BeautifulBackButton extends StatelessWidget {
  const BeautifulBackButton({
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.surface;
    final fg = foregroundColor ?? AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap ??
          () {
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            } else {
              try {
                AppShellScope.of(context).selectPage(0);
              } catch (_) {
                // Not in AppShellScope
              }
            }
          },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showText = constraints.maxWidth >= 60;
          return Container(
            height: 34,
            padding: EdgeInsets.symmetric(
              horizontal: showText ? 12 : 8,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: fg,
                ),
                if (showText) ...[
                  const SizedBox(width: 4),
                  Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
