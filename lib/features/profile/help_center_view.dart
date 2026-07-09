import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/dashboard_theme.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../routes/app_routes.dart';
import 'call_support_modal.dart';
import '../../shared/widgets/app_strings_scope.dart';
import '../../shared/widgets/responsive_screen_shell.dart';

class HelpCenterView extends StatefulWidget {
  const HelpCenterView({super.key});

  @override
  State<HelpCenterView> createState() => _HelpCenterViewState();
}

class _HelpCenterViewState extends State<HelpCenterView> {
  var _expandedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final s = AppStringsScope.of(context);
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);

    return Scaffold(
      backgroundColor: dashboard.screenBackground,
      appBar: AppBar(
        backgroundColor: dashboard.screenBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: dashboard.primaryText,
            size: r.sp(18).clamp(16.0, 20.0),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.maxContentWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              r.gap(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.frequentlyAskedQuestions,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(27).clamp(24.0, 30.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                    height: 1.15,
                  ),
                ),
                ResponsiveGap(20),
                ...List.generate(AppStrings.faqCount, (index) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: r.gap(10)),
                    child: _FaqItemTile(
                      r: r,
                      question: s.faqQuestion(index),
                      isExpanded: _expandedIndex == index,
                      onTap: () {
                        setState(() {
                          _expandedIndex =
                              _expandedIndex == index ? -1 : index;
                        });
                      },
                      expandedChild: index == _expandedIndex
                          ? _FaqAnswerBody(r: r, answer: s.faqAnswer(index))
                          : null,
                    ),
                  );
                }),
                ResponsiveGap(20),
                Text(
                  s.stillNeedHelp,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(18).clamp(16.0, 20.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                  ),
                ),
                ResponsiveGap(12),
                _SupportActionCard(
                  r: r,
                  icon: Icons.phone_rounded,
                  title: s.callSupport,
                  subtitle: s.callSupportSubtitle,
                  onTap: () => CallSupportModal.show(context),
                ),
                ResponsiveGap(10),
                _SupportActionCard(
                  r: r,
                  icon: Icons.confirmation_number_outlined,
                  title: s.submitTicketAction,
                  subtitle: s.submitTicketSubtitle,
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.submittedTickets,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqAnswerBody extends StatelessWidget {
  const _FaqAnswerBody({required this.r, required this.answer});

  final AppResponsive r;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    final blocks = answer.split('\n\n');

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(r.gap(10), r.gap(10), r.gap(10), r.gap(10)),
      padding: EdgeInsets.all(r.gap(12)),
      decoration: BoxDecoration(
        color: dashboard.surface,
        borderRadius: BorderRadius.circular(r.gap(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) ...[
            if (blockIndex > 0) ResponsiveGap(8),
            ..._buildBlock(blocks[blockIndex], dashboard),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildBlock(String block, DashboardTheme dashboard) {
    final lines = block.split('\n');
    final isBulletBlock = lines.every(
      (line) => line.trim().isEmpty || line.trim().startsWith('•'),
    );
    final isNumberedBlock = lines.every(
      (line) =>
          line.trim().isEmpty || RegExp(r'^\d+\.\s').hasMatch(line.trim()),
    );

    if (isBulletBlock) {
      return lines
          .where((line) => line.trim().isNotEmpty)
          .map(
            (line) => Padding(
              padding: EdgeInsets.only(bottom: r.gap(6)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: r.gap(2), right: r.gap(6)),
                    child: Icon(
                      Icons.check_rounded,
                      size: r.sp(14).clamp(13.0, 15.0),
                      color: dashboard.mutedText,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line.trim().replaceFirst('• ', ''),
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(15).clamp(14.0, 16.0),
                        color: dashboard.secondaryText,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList();
    }

    if (isNumberedBlock) {
      return lines
          .where((line) => line.trim().isNotEmpty)
          .map(
            (line) => Padding(
              padding: EdgeInsets.only(bottom: r.gap(6)),
              child: Text(
                line.trim(),
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(15).clamp(14.0, 16.0),
                  color: dashboard.secondaryText,
                  height: 1.45,
                ),
              ),
            ),
          )
          .toList();
    }

    return [
      Text(
        block,
        style: TextStyle(
          fontFamily: AppFonts.satoshi,
          fontSize: r.sp(15).clamp(14.0, 16.0),
          color: dashboard.secondaryText,
          height: 1.45,
        ),
      ),
    ];
  }
}

class _FaqItemTile extends StatelessWidget {
  const _FaqItemTile({
    required this.r,
    required this.question,
    required this.isExpanded,
    required this.onTap,
    this.expandedChild,
  });

  final AppResponsive r;
  final String question;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget? expandedChild;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);

    return Material(
      color: dashboard.inputFill,
      borderRadius: BorderRadius.circular(r.gap(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: r.gap(14),
                vertical: r.h(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      question,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(17).clamp(16.0, 19.0),
                        fontWeight:
                            isExpanded ? FontWeight.w700 : FontWeight.w500,
                        color: isExpanded
                            ? dashboard.primaryText
                            : dashboard.secondaryText,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: dashboard.secondaryText,
                    size: r.iconMd,
                  ),
                ],
              ),
            ),
            ?expandedChild,
          ],
        ),
      ),
    );
  }
}

class _SupportActionCard extends StatelessWidget {
  const _SupportActionCard({
    required this.r,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final AppResponsive r;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    final iconBox = r.w(44).clamp(40.0, 48.0);

    return Material(
      color: dashboard.inputFill,
      borderRadius: BorderRadius.circular(r.gap(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.gap(12)),
        child: Padding(
          padding: EdgeInsets.all(r.gap(12)),
          child: Row(
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: AppColors.loginButton.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.gap(10)),
                ),
                child: Icon(
                  icon,
                  color: AppColors.loginButton,
                  size: r.iconSm,
                ),
              ),
              SizedBox(width: r.gap(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(18).clamp(17.0, 20.0),
                        fontWeight: FontWeight.w700,
                        color: dashboard.primaryText,
                      ),
                    ),
                    SizedBox(height: r.gap(2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(15).clamp(14.0, 16.0),
                        color: dashboard.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: dashboard.chevron,
                size: r.iconMd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
