import 'package:flutter/material.dart';

import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/app_theme.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';
import 'password_requirements.dart';

class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({
    super.key,
    required this.requirements,
    this.showConfirmMatch = false,
    this.passwordsMatch = false,
  });

  final PasswordRequirements requirements;
  final bool showConfirmMatch;
  final bool passwordsMatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RequirementRow(
          label: 'At least 8 characters',
          met: requirements.hasMinLength,
        ),
        ResponsiveGap(6),
        _RequirementRow(
          label: 'Contains a number',
          met: requirements.hasNumber,
        ),
        ResponsiveGap(6),
        _RequirementRow(
          label: 'Contains a symbol',
          met: requirements.hasSymbol,
        ),
        if (showConfirmMatch) ...[
          ResponsiveGap(6),
          _RequirementRow(
            label: 'Passwords match',
            met: passwordsMatch,
          ),
        ],
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.label,
    required this.met,
  });

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final color = met ? theme.linkAccent : theme.mutedText;

    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: r.iconSm,
          color: color,
        ),
        ResponsiveHGap(8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.plusJakartaSans,
              fontSize: r.captionSize,
              fontWeight: met ? FontWeight.w600 : FontWeight.w500,
              color: met ? onSurface : theme.mutedText,
            ),
          ),
        ),
      ],
    );
  }
}
