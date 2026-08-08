import 'package:flutter/material.dart';

import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/app_theme.dart';
import '../../../features/tutorial/tutorial_screen_helper.dart';
import '../../../features/tutorial/tutorial_target.dart';
import '../../../features/tutorial/tutorial_target_registry.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/animated_success_badge.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../widgets/auth_widgets.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';

class DocumentSubmissionSuccessView extends StatefulWidget {
  const DocumentSubmissionSuccessView({super.key});

  @override
  State<DocumentSubmissionSuccessView> createState() =>
      _DocumentSubmissionSuccessViewState();
}

class _DocumentSubmissionSuccessViewState
    extends State<DocumentSubmissionSuccessView> {
  final _tutorialRegistry = TutorialTargetRegistry();

  @override
  void initState() {
    super.initState();
    scheduleTutorialForRoute(
      state: this,
      route: AppRoutes.documentSubmissionSuccess,
      registry: _tutorialRegistry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStringsScope.of(context);
    final reviewSteps = s.documentReviewSteps;
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ResponsiveScreenShell(
      backgroundAsset: theme.formAuthBackgroundAsset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveGap(16),
          const Center(child: AnimatedSuccessBadge()),
          ResponsiveGap(28),
          Text(
            s.documentSubmissionSuccessTitle,
            textAlign: TextAlign.center,
            style: r.titleStyle(color: onSurface),
          ),
          ResponsiveGap(12),
          Text(
            s.documentSubmissionThankYou,
            textAlign: TextAlign.center,
            style: r.subtitleStyle(color: theme.mutedText),
          ),
          ResponsiveGap(32),
          TutorialTarget(
            registry: _tutorialRegistry,
            id: 'pending_review',
            child: Container(
            padding: EdgeInsets.all(r.gap(20)),
            decoration: BoxDecoration(
              color: theme.cardSurface,
              borderRadius: BorderRadius.circular(r.borderRadiusMd),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: r.gap(16),
                  offset: Offset(0, r.gap(4)),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.underReview,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.plusJakartaSans,
                    fontSize: r.sp(22).clamp(20.0, 26.0),
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                ResponsiveGap(8),
                Text(
                  s.estimatedReviewTime,
                  textAlign: TextAlign.center,
                  style: r.bodyStyle(color: theme.mutedText),
                ),
                ResponsiveGap(16),
                Divider(color: theme.authFieldBorder, height: 1),
                ResponsiveGap(16),
                for (var i = 0; i < reviewSteps.length; i++) ...[
                  if (i > 0) ResponsiveGap(12),
                  _ReviewStepItem(
                    number: i + 1,
                    text: reviewSteps[i],
                  ),
                ],
              ],
            ),
            ),
          ),
          ResponsiveGap(40),
          TutorialTarget(
            registry: _tutorialRegistry,
            id: 'pending_login',
            child: AuthPrimaryButton(
            label: s.backToLogin,
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed(AppRoutes.login),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewStepItem extends StatelessWidget {
  const _ReviewStepItem({
    required this.number,
    required this.text,
  });

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number.',
          style: TextStyle(
            fontFamily: AppFonts.plusJakartaSans,
            fontSize: r.bodySize,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
        ResponsiveHGap(8),
        Expanded(
          child: Text(
            text,
            style: r.bodyStyle(color: theme.mutedText),
          ),
        ),
      ],
    );
  }
}
