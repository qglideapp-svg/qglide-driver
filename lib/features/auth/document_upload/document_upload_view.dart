import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_fonts.dart';
import '../../../config/app_responsive.dart';
import '../../../config/app_strings.dart';
import '../../../config/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import 'document_upload_controller.dart';
import 'driver_document_type.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../services/driver_status_service.dart';
import '../../../utils/driver_auth_navigation.dart';
import '../../profile/manage_vehicle_view.dart';
import '../widgets/auth_top_toast.dart';
import '../widgets/auth_widgets.dart';
import '../../../shared/widgets/app_strings_scope.dart';
import '../../../shared/widgets/responsive_screen_shell.dart';

class DocumentUploadView extends ConsumerStatefulWidget {
  const DocumentUploadView({super.key});

  @override
  ConsumerState<DocumentUploadView> createState() =>
      _DocumentUploadViewState();
}

class _DocumentUploadViewState extends ConsumerState<DocumentUploadView> {
  var _currentStep = 1;
  var _sessionReady = false;

  static const _totalSteps = DriverDocumentType.contentStepCount + 1;
  static const _contentSteps = DriverDocumentType.contentStepCount;

  DocumentUploadController get _controller =>
      ref.read(documentUploadControllerProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    final restored =
        await DriverAuthNavigation.ensureSessionOrRedirectToLogin(context);
    if (!mounted) return;
    if (restored) {
      await _controller.syncUploadedDocuments();
      if (!mounted) return;
      setState(() {
        _sessionReady = true;
        _currentStep = _controller.firstIncompleteStep;
      });
    }
  }

  int get _progressStep =>
      _currentStep == _contentSteps ? _totalSteps - 1 : _currentStep;

  List<_DocumentItem> _documents(AppStrings s) {
    final types = DriverDocumentType.typesForStep(_currentStep);
    return types
        .map(
          (type) {
            final isProfilePicture =
                type == DriverDocumentType.profilePicture;
            return _DocumentItem(
            documentType: type,
            icon: isProfilePicture
                ? Icons.person_outline
                : Icons.description_outlined,
            title: DriverDocumentType.label(type),
            subtitle: _controller.isUploading(type)
                ? s.uploading
                : _controller.isDeleting(type)
                    ? s.deleting
                    : _controller.isUploaded(type)
                        ? s.documentUploaded
                        : s.uploadRequired,
            buttonLabel: isProfilePicture ? s.uploadPhoto : s.uploadDocument,
            isUploaded: _controller.isUploaded(type),
            isUploading: _controller.isUploading(type),
            isDeleting: _controller.isDeleting(type),
            highlighted: types.first == type,
          );
          },
        )
        .toList();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    AuthTopToast.showError(context, message);
  }

  Future<void> _handleUpload(String documentType) async {
    if (!_sessionReady) {
      await _restoreSession();
      if (!mounted || !_sessionReady) return;
    }
    final error = await _controller.pickAndUploadDocument(documentType);
    if (!mounted) return;
    if (error == null) return;
    if (DriverAuthNavigation.isSessionExpiredMessage(error)) {
      final recovered = await AuthService.recoverStoredSession();
      if (!mounted) return;
      if (recovered) {
        final retryError = await _controller.pickAndUploadDocument(documentType);
        if (!mounted) return;
        if (retryError == null) return;
        _showMessage(retryError);
        return;
      }
      _showMessage(error);
      return;
    }
    _showMessage(error);
  }

  Future<void> _handleDelete(String documentType) async {
    if (_controller.isUploading(documentType) ||
        _controller.isDeleting(documentType)) {
      return;
    }
    if (!_sessionReady) {
      await _restoreSession();
      if (!mounted || !_sessionReady) return;
    }

    final error = await _controller.deleteUploadedDocument(documentType);
    if (!mounted) return;
    if (error == null) return;
    if (DriverAuthNavigation.isSessionExpiredMessage(error)) {
      final recovered = await AuthService.recoverStoredSession();
      if (!mounted) return;
      if (recovered) {
        final retryError =
            await _controller.deleteUploadedDocument(documentType);
        if (!mounted) return;
        if (retryError == null) return;
        _showMessage(retryError);
        return;
      }
      _showMessage(error);
      return;
    }
    _showMessage(error);
  }

  void _handlePrevious() {
    if (_currentStep <= 1) return;
    setState(() => _currentStep--);
  }

  Future<void> _handleNext(AppStrings s) async {
    if (_controller.isAnyBusy) {
      _showMessage(s.waitForUploads);
      return;
    }

    if (!_controller.isStepComplete(_currentStep)) {
      _showMessage(s.uploadAllStepDocs);
      return;
    }

    if (_currentStep < _contentSteps) {
      setState(() => _currentStep++);
      return;
    }

    if (!_controller.allDocumentsUploaded) {
      _showMessage(s.uploadAllBeforeSubmit);
      return;
    }

    await DriverStatusService.recordSignupStep(
      accessRoute: DriverAccessRoute.manageVehicle,
      status: const DriverStatus(
        isVerified: false,
        isApproved: false,
        canAcceptRides: false,
        phoneVerified: true,
        onboarding: DriverOnboarding(
          documents: DriverDocumentsOnboarding(complete: true),
          vehicleDetails: DriverVehicleDetailsOnboarding(complete: false),
          onboardingComplete: false,
          nextStep: 'manage_vehicle',
        ),
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.manageVehicle,
      arguments: const ManageVehicleArgs(fromOnboarding: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStringsScope.of(context);
    ref.watch(documentUploadControllerProvider);
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final documents = _documents(s);
    final isBusy = _controller.isAnyBusy;

    return ResponsiveScreenShell(
      backgroundAsset: theme.formAuthBackgroundAsset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.documentUploadTitleSingular,
            style: r.titleStyle(color: onSurface),
          ),
          ResponsiveGap(12),
          Text(
            s.documentUploadSubtitleDriver,
            style: r.subtitleStyle(color: theme.mutedText),
          ),
          ResponsiveGap(24),
          _ProgressBar(currentStep: _progressStep, totalSteps: _totalSteps),
          ResponsiveGap(28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: offsetAnimation,
                  child: child,
                ),
              );
            },
            child: Column(
              key: ValueKey(_currentStep),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < documents.length; i++) ...[
                  if (i > 0) ResponsiveGap(16),
                  _DocumentCard(
                    icon: documents[i].icon,
                    title: documents[i].title,
                    subtitle: documents[i].subtitle,
                    buttonLabel: documents[i].buttonLabel,
                    isUploaded: documents[i].isUploaded,
                    isUploading: documents[i].isUploading,
                    isDeleting: documents[i].isDeleting,
                    highlighted: documents[i].highlighted,
                    onUpload: documents[i].isUploaded
                        ? null
                        : (isBusy || documents[i].isUploading
                            ? null
                            : () => unawaited(
                                  _handleUpload(documents[i].documentType),
                                )),
                    onDelete: documents[i].isUploaded &&
                            !isBusy &&
                            !documents[i].isDeleting
                        ? () => unawaited(
                              _handleDelete(documents[i].documentType),
                            )
                        : null,
                  ),
                ],
              ],
            ),
          ),
          ResponsiveGap(32),
          if (_currentStep > 1) ...[
            _StepNavButton(
              label: s.previous,
              onPressed: isBusy ? null : _handlePrevious,
            ),
            ResponsiveGap(12),
          ],
          AuthPrimaryButton(
            label: _currentStep == _contentSteps ? s.submit : s.next,
            onPressed: isBusy ? null : () => unawaited(_handleNext(s)),
          ),
          ResponsiveGap(24),
          _InfoFooter(message: s.documentUploadInfoFooter),
        ],
      ),
    );
  }
}

class _DocumentItem {
  const _DocumentItem({
    required this.documentType,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.isUploaded,
    required this.isUploading,
    required this.isDeleting,
    this.highlighted = false,
  });

  final String documentType;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool isUploaded;
  final bool isUploading;
  final bool isDeleting;
  final bool highlighted;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        return Expanded(
          child: Container(
            height: r.h(4),
            margin: EdgeInsets.only(
              right: index < totalSteps - 1 ? r.gap(6) : 0,
            ),
            decoration: BoxDecoration(
              color: isActive ? theme.loginButton : onSurface,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _StepNavButton extends StatelessWidget {
  const _StepNavButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: theme.socialButtonBackground,
          foregroundColor: onSurface,
          side: BorderSide(color: theme.authFieldBorder, width: 1),
          padding: EdgeInsets.symmetric(vertical: r.h(16)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.borderRadiusLg),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.plusJakartaSans,
            fontSize: r.buttonTextSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.isUploaded,
    required this.isUploading,
    required this.isDeleting,
    this.onUpload,
    this.onDelete,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool isUploaded;
  final bool isUploading;
  final bool isDeleting;
  final VoidCallback? onUpload;
  final VoidCallback? onDelete;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = context.appTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final iconBox = r.w(44).clamp(40.0, 52.0);

    return Container(
      padding: EdgeInsets.all(r.gap(16)),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
        border: Border.all(
          color: highlighted ? const Color(0xFF22C55E) : theme.authFieldBorder,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: theme.socialButtonBackground,
                  borderRadius: BorderRadius.circular(r.gap(10)),
                ),
                child: Icon(
                  icon,
                  size: r.iconMd,
                  color: theme.iconMuted,
                ),
              ),
              SizedBox(width: r.gap(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppFonts.plusJakartaSans,
                        fontSize: r.subtitleSize,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                    SizedBox(height: r.gap(2)),
                    Text(
                      subtitle,
                      style: r.captionStyle(color: theme.iconMuted),
                    ),
                  ],
                ),
              ),
              if (isUploading || isDeleting)
                SizedBox(
                  width: r.iconMd,
                  height: r.iconMd,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.loginButton,
                  ),
                )
              else if (isUploaded) ...[
                Icon(
                  Icons.check_circle,
                  color: theme.loginButton,
                  size: r.iconMd,
                ),
                if (onDelete != null) ...[
                  SizedBox(width: r.gap(4)),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      size: r.iconMd,
                      color: theme.iconMuted,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: r.w(36),
                      minHeight: r.w(36),
                    ),
                    tooltip: AppStringsScope.of(context).delete,
                  ),
                ],
              ],
            ],
          ),
          if (!isUploaded) ...[
            ResponsiveGap(16),
            OutlinedButton(
              onPressed: onUpload,
              style: OutlinedButton.styleFrom(
                backgroundColor: theme.socialButtonBackground,
                foregroundColor: onSurface,
                side: BorderSide(color: theme.authFieldBorder, width: 1),
                padding: EdgeInsets.symmetric(vertical: r.h(14)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.borderRadiusMd),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    size: r.iconSm,
                    color: theme.iconMuted,
                  ),
                  SizedBox(width: r.gap(8)),
                  Text(
                    buttonLabel,
                    style: TextStyle(
                      fontFamily: AppFonts.plusJakartaSans,
                      fontSize: r.captionSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoFooter extends StatelessWidget {
  const _InfoFooter({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = context.appTheme;

    return Container(
      padding: EdgeInsets.all(r.gap(16)),
      decoration: BoxDecoration(
        color: theme.infoSurface,
        borderRadius: BorderRadius.circular(r.borderRadiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: r.w(24),
            height: r.w(24),
            decoration: BoxDecoration(
              color: theme.loginButton,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline,
              size: r.sp(16),
              color: theme.primaryButtonForeground,
            ),
          ),
          SizedBox(width: r.gap(12)),
          Expanded(
            child: Text(
              message,
              style: r.captionStyle(color: theme.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}
