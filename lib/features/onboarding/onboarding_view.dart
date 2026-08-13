import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_colors.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../shared/widgets/app_strings_scope.dart';
import '../../core/providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../../services/app_tutorial_service.dart';
import 'onboarding_controller.dart';
import 'onboarding_page_model.dart';
import '../../routes/app_routes.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  static const _footerHeight = 148.0;

  OnboardingController get _controller => ref.read(onboardingControllerProvider);

  Future<void> _finishOnboarding() async {
    await AuthService.markOnboardingCompleted();
    await AppTutorialService.activateJourney();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
  }

  Future<void> _handleNext() async {
    if (_controller.isLastPage) {
      _finishOnboarding();
      return;
    }

    await _controller.nextPage();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(onboardingControllerProvider);
    final s = AppStringsScope.of(context);
    final r = context.responsive;
    final footerHeight =
        r.isCompact ? r.onboardingFooterHeight : _footerHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _controller.isFirstPage
                ? const SizedBox(width: 44, height: 44)
                : _BackButton(
                    onPressed: () {
                      _controller.previousPage();
                    },
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _finishOnboarding,
            child: Text(
              s.skip,
              style: TextStyle(
                color: Colors.white,
                fontSize: r.isCompact ? r.sp(16) : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller.pageController,
            itemCount: _controller.pageCount,
            onPageChanged: _controller.onPageChanged,
            itemBuilder: (context, index) {
              return _OnboardingPageContent(
                page: _controller.pages[index],
                pageIndex: index,
                footerHeight: footerHeight,
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PageIndicator(
                      count: _controller.pageCount,
                      activeIndex: _controller.currentPage,
                      activeColor: AppColors.accentYellowSolid,
                    ),
                    const SizedBox(height: 24),
                    _GlassNextButton(
                      label: _controller.isLastPage ? s.getStarted : s.next,
                      isGetStarted: _controller.isLastPage,
                      onPressed: _handleNext,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageContent extends StatelessWidget {
  const _OnboardingPageContent({
    required this.page,
    required this.pageIndex,
    required this.footerHeight,
  });

  final OnboardingPageModel page;
  final int pageIndex;
  final double footerHeight;

  @override
  Widget build(BuildContext context) {
    final s = AppStringsScope.of(context);
    final r = context.responsive;
    final compact = r.isCompact;
    final headlineSize = compact ? r.sp(42) : 48.0;
    final subtitleSize = compact ? r.sp(16) : 18.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          page.imageAsset,
          fit: BoxFit.cover,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x80000000),
                Color(0xB3000000),
                Color(0xE6000000),
              ],
              stops: [0.0, 0.35, 0.65, 1.0],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Column(
            children: [
              const Spacer(flex: 4),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, footerHeight),
                child: Column(
                  children: [
                    Text(
                      s.onboardingHeadline(pageIndex),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.plusJakartaSans,
                        color: Colors.white,
                        fontSize: headlineSize,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.onboardingSubtitle(pageIndex),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.plusJakartaSans,
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: subtitleSize,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassNextButton extends StatelessWidget {
  const _GlassNextButton({
    required this.label,
    required this.isGetStarted,
    required this.onPressed,
  });

  final String label;
  final bool isGetStarted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(999));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.04),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.25),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                splashColor: Colors.white.withValues(alpha: 0.08),
                highlightColor: Colors.white.withValues(alpha: 0.04),
                child: Ink(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.18),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.plusJakartaSans,
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: isGetStarted
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: 0.15,
                        height: 1.1,
                      ),
                    ),
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentYellowSolid,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.activeIndex,
    required this.activeColor,
  });

  final int count;
  final int activeIndex;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 18,
          height: 4,
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
