import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../core/providers/app_providers.dart';
import '../../config/dashboard_theme.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/location_tracker_service.dart';
import '../../shared/widgets/profile_avatar_image.dart';
import '../../shared/widgets/responsive_screen_shell.dart';
import '../home/widgets/driver_ad_placement_banner.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  var _isLoadingProfile = true;
  String? _avatarUrl;
  String _fullName = 'Driver';
  String? _memberSinceDate;
  String _ratingDisplay = '--';
  var _isLoadingLocation = false;
  var _isLoggingOut = false;
  var _isDeletingAccount = false;
  String? _currentLocationDisplay;
  LocationSettingsAction? _locationSettingsAction;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    unawaited(_loadCurrentLocation());
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);

    final response = await AuthService.getUserProfile();
    final profile = AuthService.extractUserProfile(response);

    if (!mounted) return;

    setState(() {
      _isLoadingProfile = false;
      if (profile != null) {
        _applyProfile(profile);
      }
    });
  }

  void _applyProfile(Map<String, dynamic> profile) {
    _fullName = AuthService.extractProfileFullName(profile) ?? 'Driver';
    _memberSinceDate = AuthService.extractMemberSinceFormatted(profile);
    final rating = AuthService.extractProfileRating(profile);
    _ratingDisplay = rating != null ? rating.toStringAsFixed(1) : '--';
    _avatarUrl = AuthService.extractAvatarUrl(profile);
  }

  Future<void> _loadCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() {
      _isLoadingLocation = true;
      _locationSettingsAction = null;
    });

    final result = await LocationTrackerService.getCurrentLocation(
      resolvePlaceName: true,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingLocation = false;
      if (result.isSuccess) {
        final strings = AppStrings.current();
        _currentLocationDisplay =
            result.location!.displayName ?? strings.locationUnavailable;
      } else {
        _currentLocationDisplay = result.error;
        _locationSettingsAction = result.settingsAction;
      }
    });
  }

  Future<void> _openPersonalInformation() async {
    await Navigator.of(context).pushNamed(AppRoutes.personalInformation);
    if (mounted) await _loadProfile();
  }

  Future<void> _logOut() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    final response = await AuthService.logout();
    if (!mounted) return;

    if (response['success'] != true) {
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthService.extractErrorMessage(
              response,
              fallback: AppStrings.current().errLogoutLocal,
            ),
          ),
        ),
      );
    }

    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  Future<void> _confirmAndDeleteAccount() async {
    if (_isDeletingAccount) return;

    final strings = AppStrings(isArabic: ref.watch(localeProvider));
    final dashboard = DashboardTheme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dashboard.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.responsive.gap(16)),
          ),
          title: Text(
            strings.deleteAccountConfirmTitle,
            textDirection: strings.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontWeight: FontWeight.w700,
              color: dashboard.primaryText,
            ),
          ),
          content: Text(
            strings.deleteAccountConfirmMessage,
            textDirection: strings.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              color: dashboard.secondaryText,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                strings.cancel,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontWeight: FontWeight.w600,
                  color: dashboard.primaryText,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                strings.delete,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);

    final response = await AuthService.deleteAccount();
    if (!mounted) return;

    setState(() => _isDeletingAccount = false);

    if (response['success'] == true) {
      final message = AuthService.extractSuccessMessage(
        response,
        fallback: AppStrings.current().errAccountDeleted,
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AuthService.extractErrorMessage(
            response,
            fallback: AppStrings.current().errDeleteAccount,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final isArabic = ref.watch(localeProvider);
    final strings = AppStrings(isArabic: isArabic);
    final displayName = _fullName == 'Driver' && strings.isArabic
        ? strings.driverFallback
        : _fullName;
    final memberSinceText = _memberSinceDate == null
        ? '--'
        : strings.memberSince(_memberSinceDate!);

    return Directionality(
      textDirection: strings.textDirection,
      child: Scaffold(
        backgroundColor: dashboard.screenBackground,
        appBar: AppBar(
          backgroundColor: dashboard.screenBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              strings.isArabic
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new,
              color: dashboard.primaryText,
              size: r.sp(18).clamp(16.0, 20.0),
            ),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: r.maxContentWidth),
            child: _isLoadingProfile
                ? const _LazyProfileContent()
                : SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: r.gap(8),
                      bottom: r.gap(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: r.gap(r.isTablet ? 32 : 20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ProfileHeader(
                                r: r,
                                strings: strings,
                                fullName: displayName,
                                memberSince: memberSinceText,
                                ratingDisplay: _ratingDisplay,
                                avatarUrl: _avatarUrl,
                                onAvatarTap: _openPersonalInformation,
                              ),
                              ResponsiveGap(28),
                              _SectionTitle(
                                title: strings.settings,
                                r: r,
                                textDirection: strings.textDirection,
                              ),
                              ResponsiveGap(12),
                              _SettingsCard(
                                r: r,
                                strings: strings,
                                englishSelected: !isArabic,
                                languageToggleOn: isArabic,
                                isDeletingAccount: _isDeletingAccount,
                                onPersonalInformationTap: _openPersonalInformation,
                                onManageVehicleTap: () {
                                  Navigator.of(context).pushNamed(
                                    AppRoutes.manageVehicle,
                                  );
                                },
                                onDeleteAccountTap: _confirmAndDeleteAccount,
                                onEnglishSelected: () => unawaited(
                                  ref.read(localeProvider.notifier).setEnglish(),
                                ),
                                onAlternateLanguageSelected: () => unawaited(
                                  ref.read(localeProvider.notifier).setArabic(true),
                                ),
                                onLanguageToggleChanged: (value) => unawaited(
                                  ref
                                      .read(localeProvider.notifier)
                                      .setArabic(value),
                                ),
                              ),
                              ResponsiveGap(28),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: r.gap(r.isTablet ? 32 : 20),
                          ),
                          child: const DriverAdPlacementBanner(
                            showFallbackWhenEmpty: false,
                          ),
                        ),
                        ResponsiveGap(28),
                        _SupportCard(
                          r: r,
                          strings: strings,
                          onLogOut: _logOut,
                          isLoggingOut: _isLoggingOut,
                          onHelpCenterTap: () {
                            Navigator.of(context).pushNamed(AppRoutes.helpCenter);
                          },
                          isLoadingLocation: _isLoadingLocation,
                          currentLocationDisplay: _currentLocationDisplay,
                          locationSettingsAction: _locationSettingsAction,
                          onCurrentLocationTap: _loadCurrentLocation,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.r,
    required this.strings,
    required this.fullName,
    required this.memberSince,
    required this.ratingDisplay,
    required this.onAvatarTap,
    this.avatarUrl,
  });

  final AppResponsive r;
  final AppStrings strings;
  final String fullName;
  final String memberSince;
  final String ratingDisplay;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    final avatarSize = r.w(72).clamp(62.0, 80.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment:
                    strings.isArabic ? Alignment.centerRight : Alignment.centerLeft,
                child: Text(
                  fullName,
                  maxLines: 1,
                  softWrap: false,
                  textDirection: strings.textDirection,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(29).clamp(26.0, 32.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                    height: 1.15,
                  ),
                ),
              ),
              ResponsiveGap(6),
              Text(
                memberSince,
                textDirection: strings.textDirection,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(19).clamp(17.0, 21.0),
                  color: dashboard.secondaryText,
                ),
              ),
              ResponsiveGap(10),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.gap(10),
                  vertical: r.gap(6),
                ),
                decoration: BoxDecoration(
                  color: dashboard.pillBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: r.iconSm,
                      color: AppColors.loginButton,
                    ),
                    SizedBox(width: r.gap(4)),
                    Text(
                      ratingDisplay,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(19).clamp(18.0, 21.0),
                        fontWeight: FontWeight.w600,
                        color: dashboard.bodyText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: r.gap(12)),
        _ProfileAvatar(
          r: r,
          size: avatarSize,
          avatarUrl: avatarUrl,
          displayName: fullName,
          onAvatarTap: onAvatarTap,
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.r,
    required this.size,
    required this.onAvatarTap,
    this.avatarUrl,
    this.displayName,
  });

  final AppResponsive r;
  final double size;
  final String? avatarUrl;
  final String? displayName;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final borderWidth = r.w(2.5).clamp(2.0, 3.0);
    final editSize = r.w(24).clamp(20.0, 28.0);
    final innerSize = size - (borderWidth * 2);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onAvatarTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: innerSize,
                height: innerSize,
                child: ClipOval(
                  child: ProfileAvatarImage(
                    size: innerSize,
                    avatarUrl: avatarUrl,
                    displayName: displayName,
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.loginButton,
                  width: borderWidth,
                ),
              ),
            ),
          ),
          Positioned(
            right: -editSize * 0.06,
            bottom: -editSize * 0.06,
            child: Material(
              color: AppColors.loginButton,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onAvatarTap,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: editSize,
                  height: editSize,
                  child: Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: editSize * 0.46,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.r,
    required this.textDirection,
  });

  final String title;
  final AppResponsive r;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);

    return Text(
      title,
      textDirection: textDirection,
      style: TextStyle(
        fontFamily: AppFonts.satoshi,
        fontSize: r.sp(24).clamp(22.0, 26.0),
        fontWeight: FontWeight.w700,
        color: dashboard.primaryText,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.r,
    required this.strings,
    required this.englishSelected,
    required this.languageToggleOn,
    required this.onPersonalInformationTap,
    required this.onManageVehicleTap,
    required this.onDeleteAccountTap,
    required this.onEnglishSelected,
    required this.onAlternateLanguageSelected,
    required this.onLanguageToggleChanged,
    this.isDeletingAccount = false,
  });

  final AppResponsive r;
  final AppStrings strings;
  final bool englishSelected;
  final bool languageToggleOn;
  final bool isDeletingAccount;
  final VoidCallback onPersonalInformationTap;
  final VoidCallback onManageVehicleTap;
  final VoidCallback onDeleteAccountTap;
  final VoidCallback onEnglishSelected;
  final VoidCallback onAlternateLanguageSelected;
  final ValueChanged<bool> onLanguageToggleChanged;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);

    return Column(
      children: [
        _ProfileMenuRow(
          r: r,
          strings: strings,
          icon: Icons.person_outline_rounded,
          title: strings.personalInformation,
          onTap: onPersonalInformationTap,
          trailing: Icon(
            strings.isArabic
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            color: dashboard.chevron,
          ),
        ),
        _ProfileDivider(r: r),
        _ProfileMenuRow(
          r: r,
          strings: strings,
          icon: Icons.directions_car_outlined,
          title: strings.manageVehicle,
          onTap: onManageVehicleTap,
          trailing: Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.gap(10),
              vertical: r.gap(4),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(r.gap(6)),
            ),
            child: Text(
              strings.approved,
              textDirection: strings.textDirection,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(15).clamp(14.0, 17.0),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        _ProfileDivider(r: r),
        _LanguageSegmentRow(
          r: r,
          strings: strings,
          englishSelected: englishSelected,
          onEnglishSelected: onEnglishSelected,
          onAlternateLanguageSelected: onAlternateLanguageSelected,
        ),
        _ProfileDivider(r: r),
        _ProfileMenuRow(
          r: r,
          strings: strings,
          icon: Icons.cookie_outlined,
          title: strings.language,
          trailing: _EmbossedToggle(
            r: r,
            value: languageToggleOn,
            onChanged: onLanguageToggleChanged,
          ),
        ),
        _ProfileDivider(r: r),
        _ProfileMenuRow(
          r: r,
          strings: strings,
          icon: Icons.delete_outline_rounded,
          title: strings.deleteAccount,
          titleColor: Colors.red.shade700,
          iconColor: Colors.red.shade700,
          onTap: isDeletingAccount ? null : onDeleteAccountTap,
          trailing: isDeletingAccount
              ? SizedBox(
                  width: r.iconSm,
                  height: r.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red.shade700,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.r,
    required this.strings,
    required this.onLogOut,
    required this.onHelpCenterTap,
    required this.isLoadingLocation,
    required this.isLoggingOut,
    required this.onCurrentLocationTap,
    this.currentLocationDisplay,
    this.locationSettingsAction,
  });

  final AppResponsive r;
  final AppStrings strings;
  final VoidCallback onLogOut;
  final VoidCallback onHelpCenterTap;
  final VoidCallback onCurrentLocationTap;
  final bool isLoadingLocation;
  final bool isLoggingOut;
  final String? currentLocationDisplay;
  final LocationSettingsAction? locationSettingsAction;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        r.gap(20),
        r.gap(16),
        r.gap(20),
        r.gap(16),
      ),
      decoration: BoxDecoration(
        color: dashboard.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(r.borderRadiusLg),
          topRight: Radius.circular(r.borderRadiusLg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            title: strings.support,
            r: r,
            textDirection: strings.textDirection,
          ),
          ResponsiveGap(12),
          _ProfileMenuRow(
            r: r,
            strings: strings,
            icon: Icons.help_outline_rounded,
            title: strings.helpCenter,
            onTap: onHelpCenterTap,
            trailing: Icon(
              strings.isArabic
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: dashboard.chevron,
            ),
          ),
          _ProfileDivider(r: r),
          _ProfileMenuRow(
            r: r,
            strings: strings,
            icon: Icons.my_location_rounded,
            title: strings.currentLocation,
            onTap: onCurrentLocationTap,
            trailing: _CurrentLocationTrailing(
              r: r,
              strings: strings,
              isLoading: isLoadingLocation,
              displayText: currentLocationDisplay,
              settingsAction: locationSettingsAction,
            ),
          ),
          ResponsiveGap(20),
          Material(
            color: const Color(0x45B60909),
            borderRadius: BorderRadius.circular(r.gap(12)),
            child: InkWell(
              onTap: isLoggingOut ? null : onLogOut,
              borderRadius: BorderRadius.circular(r.gap(12)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: r.h(16)),
                alignment: Alignment.center,
                child: isLoggingOut
                    ? SizedBox(
                        width: r.sp(24).clamp(22.0, 26.0),
                        height: r.sp(24).clamp(22.0, 26.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.goOfflineButton,
                        ),
                      )
                    : Text(
                        strings.logOut,
                        textDirection: strings.textDirection,
                        style: TextStyle(
                          fontFamily: AppFonts.satoshi,
                          fontSize: r.sp(21).clamp(19.0, 23.0),
                          fontWeight: FontWeight.w600,
                          color: AppColors.goOfflineButton,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationTrailing extends StatelessWidget {
  const _CurrentLocationTrailing({
    required this.r,
    required this.strings,
    required this.isLoading,
    this.displayText,
    this.settingsAction,
  });

  final AppResponsive r;
  final AppStrings strings;
  final bool isLoading;
  final String? displayText;
  final LocationSettingsAction? settingsAction;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);

    if (isLoading) {
      return SizedBox(
        width: r.iconSm,
        height: r.iconSm,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.loginButton,
        ),
      );
    }

    final text = displayText ?? strings.locationUnavailable;
    final isError = settingsAction != null;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: r.w(190).clamp(140.0, 220.0)),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        textDirection: strings.textDirection,
        style: TextStyle(
          fontFamily: AppFonts.satoshi,
          fontSize: r.sp(15).clamp(13.0, 16.0),
          fontWeight: FontWeight.w500,
          color: isError ? AppColors.goOfflineButton : dashboard.bodyText,
        ),
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.r,
    required this.strings,
    required this.icon,
    required this.title,
    this.trailing = const SizedBox.shrink(),
    this.onTap,
    this.titleColor,
    this.iconColor,
  });

  final AppResponsive r;
  final AppStrings strings;
  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    final iconBoxSize = r.w(40).clamp(36.0, 44.0);

    final row = Row(
      children: [
        Container(
          width: iconBoxSize,
          height: iconBoxSize,
          decoration: BoxDecoration(
            color: dashboard.iconBox,
            borderRadius: BorderRadius.circular(r.gap(10)),
          ),
          child: Icon(
            icon,
            size: r.iconSm,
            color: iconColor ?? dashboard.secondaryText,
          ),
        ),
        SizedBox(width: r.gap(12)),
        Expanded(
          child: Text(
            title,
            textDirection: strings.textDirection,
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(19).clamp(18.0, 21.0),
              color: titleColor ?? dashboard.secondaryText,
            ),
          ),
        ),
        trailing,
      ],
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.gap(12)),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: r.gap(2)),
          child: row,
        ),
      ),
    );
  }
}

class _EmbossedToggle extends StatelessWidget {
  const _EmbossedToggle({
    required this.r,
    required this.value,
    required this.onChanged,
  });

  final AppResponsive r;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    final height = r.h(30).clamp(26.0, 34.0);
    final width = r.w(52).clamp(46.0, 58.0);
    final thumbSize = height - r.gap(6);
    final inset = (height - thumbSize) / 2;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: EdgeInsets.all(inset),
        decoration: BoxDecoration(
          color: dashboard.toggleTrack,
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: dashboard.toggleBorder),
          boxShadow: [
            BoxShadow(
              color: dashboard.embossedShadow,
              offset: const Offset(1.5, 1.5),
              blurRadius: 3,
            ),
            BoxShadow(
              color: dashboard.embossedHighlight,
              offset: const Offset(-1.5, -1.5),
              blurRadius: 3,
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumbSize,
            height: thumbSize,
            decoration: BoxDecoration(
              color: value ? AppColors.loginButton : dashboard.toggleThumbOff,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dashboard.embossedShadow,
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: dashboard.embossedHighlight,
                  offset: const Offset(-1, -1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSegmentRow extends StatelessWidget {
  const _LanguageSegmentRow({
    required this.r,
    required this.strings,
    required this.englishSelected,
    required this.onEnglishSelected,
    required this.onAlternateLanguageSelected,
  });

  final AppResponsive r;
  final AppStrings strings;
  final bool englishSelected;
  final VoidCallback onEnglishSelected;
  final VoidCallback onAlternateLanguageSelected;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    final iconBoxSize = r.w(40).clamp(36.0, 44.0);

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: dashboard.iconBox,
                borderRadius: BorderRadius.circular(r.gap(10)),
              ),
              child: Icon(
                Icons.language_rounded,
                size: r.iconSm,
                color: dashboard.secondaryText,
              ),
            ),
            SizedBox(width: r.gap(12)),
            Expanded(
              child: Text(
                strings.language,
                textDirection: strings.textDirection,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontSize: r.sp(19).clamp(18.0, 21.0),
                  color: dashboard.secondaryText,
                ),
              ),
            ),
          ],
        ),
        ResponsiveGap(12),
        Container(
          padding: EdgeInsets.all(r.gap(4)),
          decoration: BoxDecoration(
            color: dashboard.toggleTrack,
            borderRadius: BorderRadius.circular(r.gap(8)),
            border: Border.all(color: dashboard.toggleBorder),
            boxShadow: [
              BoxShadow(
                color: dashboard.embossedShadow,
                offset: const Offset(1.5, 1.5),
                blurRadius: 3,
              ),
              BoxShadow(
                color: dashboard.embossedHighlight,
                offset: const Offset(-1.5, -1.5),
                blurRadius: 3,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _LanguageSegmentButton(
                  label: strings.english,
                  strings: strings,
                  isSelected: englishSelected,
                  onTap: onEnglishSelected,
                  r: r,
                ),
              ),
              Expanded(
                child: _LanguageSegmentButton(
                  label: strings.arabic,
                  strings: strings,
                  isSelected: !englishSelected,
                  onTap: onAlternateLanguageSelected,
                  r: r,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageSegmentButton extends StatelessWidget {
  const _LanguageSegmentButton({
    required this.label,
    required this.strings,
    required this.isSelected,
    required this.onTap,
    required this.r,
  });

  final String label;
  final AppStrings strings;
  final bool isSelected;
  final VoidCallback onTap;
  final AppResponsive r;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);
    final segmentRadius = BorderRadius.circular(r.gap(6));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: r.h(10)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.loginButton : Colors.transparent,
          borderRadius: segmentRadius,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: dashboard.embossedShadow,
                    offset: const Offset(2, 2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: dashboard.embossedHighlight,
                    offset: const Offset(-1.5, -1.5),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textDirection: strings.textDirection,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(18).clamp(17.0, 20.0),
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : dashboard.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider({required this.r});

  final AppResponsive r;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.gap(14)),
      child: Divider(
        height: 1,
        thickness: 1,
        color: dashboard.divider,
      ),
    );
  }
}

class _LazyProfileContent extends StatefulWidget {
  const _LazyProfileContent();

  @override
  State<_LazyProfileContent> createState() => _LazyProfileContentState();
}

class _LazyProfileContentState extends State<_LazyProfileContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);
    final iconBoxSize = r.w(40).clamp(36.0, 44.0);
    final avatarSize = r.w(72).clamp(62.0, 80.0);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            top: r.gap(8),
            bottom: r.gap(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LazyBlock(
                                opacity: opacity,
                                color: dashboard.primaryText,
                                height: r.sp(29).clamp(26.0, 32.0),
                                width: r.w(180).clamp(140.0, 220.0),
                                borderRadius: r.gap(8),
                              ),
                              ResponsiveGap(6),
                              _LazyBlock(
                                opacity: opacity,
                                color: dashboard.secondaryText,
                                height: r.sp(19).clamp(17.0, 21.0),
                                width: r.w(150).clamp(120.0, 180.0),
                              ),
                              ResponsiveGap(10),
                              _LazyBlock(
                                opacity: opacity,
                                color: dashboard.pillBackground,
                                height: r.sp(31).clamp(28.0, 34.0),
                                width: r.w(72).clamp(60.0, 88.0),
                                borderRadius: 999,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: r.gap(12)),
                        _LazyBlock(
                          opacity: opacity,
                          color: dashboard.secondaryText,
                          height: avatarSize,
                          width: avatarSize,
                          borderRadius: 999,
                        ),
                      ],
                    ),
                    ResponsiveGap(28),
                    _LazyBlock(
                      opacity: opacity,
                      color: dashboard.primaryText,
                      height: r.sp(24).clamp(22.0, 26.0),
                      width: r.w(110).clamp(90.0, 130.0),
                      borderRadius: r.gap(6),
                    ),
                    ResponsiveGap(12),
                    for (var i = 0; i < 4; i++) ...[
                      _LazyProfileMenuRow(
                        r: r,
                        opacity: opacity,
                        dashboard: dashboard,
                        iconBoxSize: iconBoxSize,
                      ),
                      if (i < 3) _ProfileDivider(r: r),
                    ],
                    ResponsiveGap(28),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  r.gap(20),
                  r.gap(16),
                  r.gap(20),
                  r.gap(16),
                ),
                decoration: BoxDecoration(
                  color: dashboard.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(r.borderRadiusLg),
                    topRight: Radius.circular(r.borderRadiusLg),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LazyBlock(
                      opacity: opacity,
                      color: dashboard.primaryText,
                      height: r.sp(24).clamp(22.0, 26.0),
                      width: r.w(100).clamp(80.0, 120.0),
                      borderRadius: r.gap(6),
                    ),
                    ResponsiveGap(12),
                    for (var i = 0; i < 2; i++) ...[
                      _LazyProfileMenuRow(
                        r: r,
                        opacity: opacity,
                        dashboard: dashboard,
                        iconBoxSize: iconBoxSize,
                      ),
                      if (i < 1) _ProfileDivider(r: r),
                    ],
                    ResponsiveGap(20),
                    _LazyBlock(
                      opacity: opacity,
                      color: const Color(0x45B60909),
                      height: r.h(52).clamp(48.0, 58.0),
                      borderRadius: r.gap(12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LazyProfileMenuRow extends StatelessWidget {
  const _LazyProfileMenuRow({
    required this.r,
    required this.opacity,
    required this.dashboard,
    required this.iconBoxSize,
  });

  final AppResponsive r;
  final double opacity;
  final DashboardTheme dashboard;
  final double iconBoxSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LazyBlock(
          opacity: opacity,
          color: dashboard.iconBox,
          height: iconBoxSize,
          width: iconBoxSize,
          borderRadius: r.gap(10),
        ),
        SizedBox(width: r.gap(12)),
        Expanded(
          child: _LazyBlock(
            opacity: opacity,
            color: dashboard.secondaryText,
            height: r.sp(19).clamp(18.0, 21.0),
            width: r.w(160).clamp(120.0, 200.0),
          ),
        ),
        SizedBox(width: r.gap(12)),
        _LazyBlock(
          opacity: opacity,
          color: dashboard.chevron,
          height: r.sp(20).clamp(18.0, 22.0),
          width: r.w(52).clamp(40.0, 64.0),
          borderRadius: r.gap(6),
        ),
      ],
    );
  }
}

class _LazyBlock extends StatelessWidget {
  const _LazyBlock({
    required this.opacity,
    required this.color,
    required this.height,
    this.width,
    this.borderRadius = 6,
  });

  final double opacity;
  final Color color;
  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
