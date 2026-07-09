import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/dashboard_theme.dart';
import '../../config/app_constants.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../services/auth_service.dart';
import '../../services/driver_status_service.dart';
import '../../shared/widgets/app_strings_scope.dart';
import '../../shared/widgets/responsive_screen_shell.dart';
import '../../shared/widgets/ride_panel_shared.dart';
import '../../../routes/app_routes.dart';

class ManageVehicleArgs {
  const ManageVehicleArgs({this.fromOnboarding = false});

  final bool fromOnboarding;
}

class ManageVehicleView extends StatefulWidget {
  const ManageVehicleView({super.key, this.fromOnboarding = false});

  final bool fromOnboarding;

  @override
  State<ManageVehicleView> createState() => _ManageVehicleViewState();
}

class _ManageVehicleViewState extends State<ManageVehicleView> {
  var _isEditing = false;
  var _isLoading = true;
  var _isSaving = false;
  var _isOnboardingFlow = false;
  String? _errorMessage;
  String? _vehicleImageUrl;

  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _colourController;
  late final TextEditingController _licensePlateController;

  @override
  void initState() {
    super.initState();
    _makeController = TextEditingController();
    _modelController = TextEditingController();
    _yearController = TextEditingController();
    _colourController = TextEditingController();
    _licensePlateController = TextEditingController();
    _isOnboardingFlow = widget.fromOnboarding;
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final onboarding = await _resolveOnboardingFlow();
    if (!mounted) return;
    setState(() => _isOnboardingFlow = onboarding);
    await _loadVehicle();
  }

  Future<bool> _resolveOnboardingFlow() async {
    if (widget.fromOnboarding) return true;

    if (AuthService.isLoggedIn) {
      final backendRoute = await AuthService.resolveSignupRouteFromBackend();
      if (backendRoute == DriverAccessRoute.manageVehicle) return true;
      if (backendRoute == DriverAccessRoute.dashboard) return false;
    }

    final resumeRoute = await DriverStatusService.resolveStoredAccessRoute();
    if (resumeRoute == DriverAccessRoute.manageVehicle) return true;

    final stored = await DriverStatusService.loadStored();
    if (stored != null && !stored.isFullyApproved) {
      final route = DriverStatusService.resolveRoute(status: stored);
      if (route == DriverAccessRoute.manageVehicle) return true;
    }

    return false;
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colourController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await AuthService.getManageVehicle();
    final payload = AuthService.extractManageVehiclePayload(response);

    if (!mounted) return;

    if (payload != null) {
      setState(() {
        _applyVehiclePayload(payload);
        _isLoading = false;
        if (_isOnboardingFlow) {
          _isEditing = true;
        }
      });
      return;
    }

    setState(() {
      _isLoading = false;
      if (_isOnboardingFlow) {
        _isEditing = true;
        _errorMessage = null;
      } else {
        _errorMessage = AuthService.extractErrorMessage(
          response,
          fallback: AppStrings.current().errLoadVehicle,
        );
      }
    });
  }

  void _applyVehiclePayload(Map<String, dynamic> payload) {
    final fields = AuthService.extractVehicleFormFields(payload);
    _makeController.text = fields['make'] ?? '';
    _modelController.text = fields['model'] ?? '';
    _yearController.text = fields['year'] ?? '';
    _colourController.text = fields['color'] ?? '';
    _licensePlateController.text = fields['license_plate'] ?? '';
    _vehicleImageUrl = AuthService.extractVehicleImageUrl(payload);
  }

  void _startEditing() {
    setState(() => _isEditing = true);
  }

  String? _extractSuccessMessage(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
      final nested = data['data'];
      if (nested is Map) {
        final nestedMessage = nested['message'];
        if (nestedMessage is String && nestedMessage.isNotEmpty) {
          return nestedMessage;
        }
      }
    }
    return null;
  }

  Future<void> _saveChanges() async {
    final s = AppStrings.current();
    final year = int.tryParse(_yearController.text.trim());
    if (year == null || year < 1900 || year > 2100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.invalidYear,
            style: TextStyle(fontFamily: AppFonts.satoshi),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final response = await AuthService.manageVehicle(
      make: _makeController.text,
      model: _modelController.text,
      year: year,
      color: _colourController.text,
      licensePlate: _licensePlateController.text,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      setState(() {
        final payload = AuthService.extractManageVehiclePayload(response);
        if (payload != null) {
          _applyVehiclePayload(payload);
        }
        _isSaving = false;
        _isEditing = false;
      });

      if (_isOnboardingFlow) {
        await _completeOnboardingSubmission(response);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _extractSuccessMessage(response) ?? s.vehicleUpdated,
            style: TextStyle(fontFamily: AppFonts.satoshi),
          ),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AuthService.extractErrorMessage(
            response,
            fallback: s.errUpdateVehicle,
          ),
          style: TextStyle(fontFamily: AppFonts.satoshi),
        ),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Future<void> _completeOnboardingSubmission(
    Map<String, dynamic> response,
  ) async {
    await DriverStatusService.recordSignupStep(
      accessRoute: DriverAccessRoute.pendingApproval,
      status: const DriverStatus(
        isVerified: false,
        isApproved: false,
        canAcceptRides: false,
        phoneVerified: true,
        onboarding: DriverOnboarding(
          documents: DriverDocumentsOnboarding(complete: true),
          vehicleDetails: DriverVehicleDetailsOnboarding(complete: true),
          onboardingComplete: false,
          nextStep: 'await_approval',
        ),
      ),
      statusResponse: response,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.documentSubmissionSuccess,
    );
  }

  void _onPrimaryAction() {
    if (_isSaving) return;
    if (_isEditing || _isOnboardingFlow) {
      _saveChanges();
    } else {
      _startEditing();
    }
  }

  String _primaryButtonLabel(AppStrings s) {
    if (_isSaving) {
      return _isOnboardingFlow ? s.submitting : s.saving;
    }
    if (_isOnboardingFlow) {
      return _isEditing ? s.submit : s.edit;
    }
    if (_isEditing) return s.saveChanges;
    return s.edit;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStringsScope.of(context);
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);

    return PopScope(
      canPop: !_isOnboardingFlow && Navigator.canPop(context),
      child: Scaffold(
      backgroundColor: dashboard.screenBackground,
      appBar: AppBar(
        backgroundColor: dashboard.screenBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: !_isOnboardingFlow,
        leading: _isOnboardingFlow
            ? null
            : IconButton(
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
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const _LazyManageVehicleContent()
                    : _errorMessage != null
                        ? _VehicleErrorState(
                            message: _errorMessage!,
                            onRetry: _loadVehicle,
                          )
                        : SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              0,
                              horizontalPadding,
                              r.gap(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  s.manageVehicle,
                                  style: TextStyle(
                                    fontFamily: AppFonts.satoshi,
                                    fontSize: r.sp(27).clamp(24.0, 30.0),
                                    fontWeight: FontWeight.w700,
                                    color: dashboard.primaryText,
                                    height: 1.15,
                                  ),
                                ),
                                ResponsiveGap(20),
                                _VehiclePhoto(
                                  r: r,
                                  imageUrl: _vehicleImageUrl,
                                ),
                                ResponsiveGap(24),
                                _SectionHeading(
                                  title: s.vehicleInformation,
                                  r: r,
                                ),
                                ResponsiveGap(16),
                                _InfoField(
                                  label: s.make,
                                  value: _makeController.text,
                                  controller: _makeController,
                                  isEditing: _isEditing,
                                ),
                                ResponsiveGap(16),
                                _InfoField(
                                  label: s.model,
                                  value: _modelController.text,
                                  controller: _modelController,
                                  isEditing: _isEditing,
                                ),
                                ResponsiveGap(16),
                                _InfoField(
                                  label: s.year,
                                  value: _yearController.text,
                                  controller: _yearController,
                                  isEditing: _isEditing,
                                  keyboardType: TextInputType.number,
                                ),
                                ResponsiveGap(16),
                                _InfoField(
                                  label: s.colour,
                                  value: _colourController.text,
                                  controller: _colourController,
                                  isEditing: _isEditing,
                                ),
                                ResponsiveGap(16),
                                _InfoField(
                                  label: s.licensePlate,
                                  value: _licensePlateController.text,
                                  controller: _licensePlateController,
                                  isEditing: _isEditing,
                                ),
                              ],
                            ),
                          ),
              ),
              if (!_isLoading && _errorMessage == null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    r.gap(24),
                  ),
                  child: RideActionButton(
                    label: _primaryButtonLabel(s),
                    color: AppColors.loginButton,
                    onPressed: _isSaving ? () {} : _onPrimaryAction,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _VehicleErrorState extends StatelessWidget {
  const _VehicleErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = AppStringsScope.of(context);
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.gap(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: r.iconMd * 1.6,
              color: dashboard.secondaryText,
            ),
            ResponsiveGap(12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.sp(16).clamp(15.0, 18.0),
                color: dashboard.secondaryText,
              ),
            ),
            ResponsiveGap(16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                s.retry,
                style: TextStyle(
                  fontFamily: AppFonts.satoshi,
                  fontWeight: FontWeight.w600,
                  color: AppColors.loginButton,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LazyManageVehicleContent extends StatefulWidget {
  const _LazyManageVehicleContent();

  @override
  State<_LazyManageVehicleContent> createState() =>
      _LazyManageVehicleContentState();
}

class _LazyManageVehicleContentState extends State<_LazyManageVehicleContent>
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

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.35 + (_pulseController.value * 0.35);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            r.gap(r.isTablet ? 32 : 20),
            0,
            r.gap(r.isTablet ? 32 : 20),
            r.gap(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LazyBlock(
                opacity: opacity,
                color: dashboard.primaryText,
                height: r.sp(27).clamp(24.0, 30.0),
                width: r.w(180).clamp(150.0, 220.0),
                borderRadius: r.gap(8),
              ),
              ResponsiveGap(20),
              _LazyBlock(
                opacity: opacity,
                color: dashboard.secondaryText,
                height: r.w(180).clamp(150.0, 220.0),
                borderRadius: r.gap(14),
              ),
              ResponsiveGap(24),
              _LazyBlock(
                opacity: opacity,
                color: dashboard.primaryText,
                height: r.sp(18).clamp(16.0, 20.0),
                width: r.w(160).clamp(130.0, 190.0),
                borderRadius: r.gap(6),
              ),
              ResponsiveGap(16),
              for (var i = 0; i < 5; i++) ...[
                _LazyBlock(
                  opacity: opacity,
                  color: dashboard.secondaryText,
                  height: r.h(52).clamp(48.0, 58.0),
                  borderRadius: r.gap(10),
                ),
                if (i < 4) ResponsiveGap(16),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LazyBlock extends StatelessWidget {
  const _LazyBlock({
    required this.opacity,
    required this.color,
    required this.height,
    this.width,
    this.borderRadius = 8,
  });

  final double opacity;
  final Color color;
  final double height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class _VehiclePhoto extends StatelessWidget {
  const _VehiclePhoto({
    required this.r,
    this.imageUrl,
  });

  final AppResponsive r;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = imageUrl;

    Widget image;
    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      image = Image.network(
        resolvedUrl,
        key: ValueKey(resolvedUrl),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        headers: AuthService.storageImageHeaders,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.loginButton,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Image.asset(
          AppConstants.manageVehiclePhotoAsset,
          fit: BoxFit.cover,
        ),
      );
    } else {
      image = Image.asset(
        AppConstants.manageVehiclePhotoAsset,
        fit: BoxFit.cover,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(r.gap(14)),
      child: AspectRatio(
        aspectRatio: 434 / 284,
        child: image,
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.r});

  final String title;
  final AppResponsive r;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardTheme.of(context);

    return Text(
      title,
      style: TextStyle(
        fontFamily: AppFonts.satoshi,
        fontSize: r.sp(18).clamp(16.0, 20.0),
        fontWeight: FontWeight.w700,
        color: dashboard.primaryText,
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({
    required this.label,
    required this.value,
    required this.controller,
    required this.isEditing,
    this.keyboardType,
  });

  final String label;
  final String value;
  final TextEditingController controller;
  final bool isEditing;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final borderRadius = BorderRadius.circular(r.gap(10));
    final fieldStyle = TextStyle(
      fontFamily: AppFonts.satoshi,
      fontSize: r.sp(15).clamp(14.0, 17.0),
      color: dashboard.primaryText,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(16).clamp(15.0, 18.0),
            fontWeight: FontWeight.w600,
            color: dashboard.primaryText,
          ),
        ),
        ResponsiveGap(8),
        if (isEditing)
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: fieldStyle,
            decoration: InputDecoration(
              hintText: label,
              hintStyle: fieldStyle.copyWith(color: dashboard.mutedText),
              filled: true,
              fillColor: dashboard.surface,
              contentPadding: EdgeInsets.symmetric(
                horizontal: r.gap(14),
                vertical: r.h(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: BorderSide(color: dashboard.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: BorderSide(
                  color: AppColors.loginButton,
                  width: 1.5,
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: r.gap(14),
              vertical: r.h(14),
            ),
            decoration: BoxDecoration(
              color: dashboard.surface,
              borderRadius: borderRadius,
              border: Border.all(color: dashboard.borderSubtle),
            ),
            child: Text(
              value.isEmpty ? '--' : value,
              style: fieldStyle.copyWith(
                color: value.isEmpty ? dashboard.mutedText : dashboard.primaryText,
              ),
            ),
          ),
      ],
    );
  }
}
