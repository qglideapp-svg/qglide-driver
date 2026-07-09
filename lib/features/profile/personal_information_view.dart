import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_colors.dart';
import '../../config/app_strings.dart';
import '../../config/dashboard_theme.dart';
import '../../config/app_fonts.dart';
import '../../config/app_responsive.dart';
import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/app_strings_scope.dart';
import '../../shared/widgets/profile_avatar_image.dart';
import '../../shared/widgets/responsive_screen_shell.dart';
import '../../shared/widgets/ride_panel_shared.dart';

class PersonalInformationView extends StatefulWidget {
  const PersonalInformationView({super.key});

  @override
  State<PersonalInformationView> createState() =>
      _PersonalInformationViewState();
}

class _PersonalInformationViewState extends State<PersonalInformationView> {
  var _isEditing = false;
  var _isLoading = true;
  var _isSaving = false;
  var _isUploadingAvatar = false;
  String? _errorMessage;
  String? _avatarUrl;
  File? _selectedImage;
  String _driverIdDisplay = '--';
  String _memberSinceDisplay = '--';
  String _countryCode = ApiConfig.defaultCountryCode;
  String _dateOfBirthRaw = '';

  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _dobController;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _dobController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await AuthService.getUserProfile();
    final profile = AuthService.extractUserProfile(response);

    if (!mounted) return;

    if (profile != null) {
      setState(() {
        _applyProfile(profile);
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = AuthService.extractErrorMessage(
        response,
        fallback: AppStrings.current().errLoadProfile,
      );
    });
  }

  void _applyProfile(Map<String, dynamic> profile) {
    final personal = profile['personal_details'];
    final account = profile['account_details'];
    final personalMap =
        personal is Map<String, dynamic> ? personal : <String, dynamic>{};
    final accountMap =
        account is Map<String, dynamic> ? account : <String, dynamic>{};

    _fullNameController.text = _readString(personalMap['full_name']) ??
        _readString(profile['full_name']) ??
        '';
    _emailController.text = _readString(personalMap['email']) ??
        _readString(profile['email']) ??
        '';
    _applyPhoneFromProfile(
      _readString(personalMap['phone']) ?? _readString(profile['phone']),
    );
    _dateOfBirthRaw = _readString(personalMap['date_of_birth']) ??
        _readString(profile['date_of_birth']) ??
        '';
    _dobController.text = _readString(personalMap['date_of_birth_formatted']) ??
        _readString(profile['date_of_birth_formatted']) ??
        _dateOfBirthRaw;

    _driverIdDisplay = _readString(accountMap['driver_id']) ??
        _readString(profile['driver_id']) ??
        '--';
    _memberSinceDisplay = _readString(accountMap['member_since_formatted']) ??
        _readString(profile['member_since_formatted']) ??
        '--';

    _avatarUrl = AuthService.extractAvatarUrl(profile);
  }

  void _applyPhoneFromProfile(String? phone) {
    _countryCode = ApiConfig.defaultCountryCode;
    if (phone == null || phone.isEmpty) {
      _phoneController.clear();
      return;
    }

    final normalized = phone.trim();
    if (normalized.startsWith('+234')) {
      _countryCode = '+234';
      _phoneController.text =
          normalized.replaceFirst('+234', '').replaceAll(RegExp(r'\D'), '');
      return;
    }
    if (normalized.startsWith('+974')) {
      _countryCode = '+974';
      _phoneController.text =
          normalized.replaceFirst('+974', '').replaceAll(RegExp(r'\D'), '');
      return;
    }

    _phoneController.text = normalized.replaceAll(RegExp(r'\s'), '');
  }

  String _dateOfBirthForApi() {
    final input = _dobController.text.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) return input;

    final parsed = DateTime.tryParse(input);
    if (parsed != null) {
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');
      return '${parsed.year}-$month-$day';
    }

    return _dateOfBirthRaw;
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

  String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _isEditing = true);
  }

  Future<void> _showImageSourceDialog() async {
    if (_isUploadingAvatar || _isSaving) return;

    final s = AppStringsScope.of(context);
    final dashboard = DashboardTheme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: dashboard.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.responsive.borderRadiusLg),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsive.gap(20),
              context.responsive.gap(12),
              context.responsive.gap(20),
              context.responsive.gap(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.updateProfilePhoto,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: context.responsive.sp(18).clamp(17.0, 20.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                  ),
                ),
                ResponsiveGap(12),
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined, color: AppColors.loginButton),
                  title: Text(
                    s.takePhoto,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      color: dashboard.primaryText,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: AppColors.loginButton),
                  title: Text(
                    s.chooseFromGallery,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      color: dashboard.primaryText,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      final file = File(pickedFile.path);
      setState(() => _selectedImage = file);
      await _uploadAvatar(file);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
        _selectedImage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.current().errPhotoPickerNotReady,
            style: TextStyle(fontFamily: AppFonts.satoshi),
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
        _selectedImage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.current().errPickImage('$e'),
            style: TextStyle(fontFamily: AppFonts.satoshi),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _uploadAvatar(File file) async {
    setState(() => _isUploadingAvatar = true);

    final bytes = await file.readAsBytes();
    final response = await AuthService.uploadAvatar(
      base64Image: base64Encode(bytes),
    );

    if (!mounted) return;

    if (response['success'] == true) {
      final uploadedUrl = AuthService.extractUploadedAvatarUrl(response);
      setState(() {
        _isUploadingAvatar = false;
        _selectedImage = null;
        if (uploadedUrl != null) {
          _avatarUrl = uploadedUrl;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.current().profilePhotoUpdated,
            style: TextStyle(fontFamily: AppFonts.satoshi),
          ),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    setState(() {
      _isUploadingAvatar = false;
      _selectedImage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AuthService.extractErrorMessage(
            response,
            fallback: AppStrings.current().errUploadPhoto,
          ),
          style: TextStyle(fontFamily: AppFonts.satoshi),
        ),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Future<void> _saveChanges() async {
    final s = AppStrings.current();
    setState(() => _isSaving = true);

    final response = await AuthService.editProfile(
      fullName: _fullNameController.text,
      email: _emailController.text,
      phone: _phoneController.text.replaceAll(RegExp(r'\D'), ''),
      dateOfBirth: _dateOfBirthForApi(),
      countryCode: _countryCode,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      setState(() {
        final profile = AuthService.extractUserProfile(response);
        if (profile != null) {
          _applyProfile(profile);
        }
        _isSaving = false;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _extractSuccessMessage(response) ?? s.profileUpdatedSuccessfully,
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
            fallback: s.errUpdateProfile,
          ),
          style: TextStyle(fontFamily: AppFonts.satoshi),
        ),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  void _onPrimaryAction() {
    if (_isSaving) return;
    if (_isEditing) {
      _saveChanges();
    } else {
      _startEditing();
    }
  }

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
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const _LazyPersonalInfoContent()
                    : _errorMessage != null
                        ? _ProfileErrorState(
                            message: _errorMessage!,
                            onRetry: _loadProfile,
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
                                  s.profile,
                                  style: TextStyle(
                                    fontFamily: AppFonts.satoshi,
                                    fontSize: r.sp(27).clamp(24.0, 30.0),
                                    fontWeight: FontWeight.w700,
                                    color: dashboard.primaryText,
                                    height: 1.15,
                                  ),
                                ),
                                ResponsiveGap(24),
                                Center(
                                  child: _PersonalInfoAvatar(
                                    r: r,
                                    avatarUrl: _avatarUrl,
                                    displayName: _fullNameController.text,
                                    localImage: _selectedImage,
                                    isUploading: _isUploadingAvatar,
                                    onEditTap: _showImageSourceDialog,
                                  ),
                                ),
                                ResponsiveGap(10),
                                Text(
                                  s.ridersCanSeeFaceDuringPickup,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: AppFonts.satoshi,
                                    fontSize: r.sp(16).clamp(15.0, 18.0),
                                    color: dashboard.secondaryText,
                                  ),
                                ),
                                ResponsiveGap(28),
                                _SectionHeading(title: s.personDetails, r: r),
                                ResponsiveGap(16),
                                _InfoField(
                                  label: s.fullName,
                                  value: _fullNameController.text,
                                  controller: _fullNameController,
                                  isEditing: _isEditing,
                                ),
                                ResponsiveGap(16),
                                _InfoField(
                                  label: s.email,
                                  value: _emailController.text,
                                  controller: _emailController,
                                  isEditing: _isEditing,
                                ),
                                ResponsiveGap(16),
                                _InfoField(
                                  label: s.phone,
                                  value: _phoneController.text,
                                  controller: _phoneController,
                                  isEditing: _isEditing,
                                ),
                                ResponsiveGap(16),
                                _InfoField(
                                  label: s.dob,
                                  value: _dobController.text,
                                  controller: _dobController,
                                  isEditing: _isEditing,
                                ),
                                ResponsiveGap(28),
                                _SectionHeading(
                                  title: s.accountDetails,
                                  r: r,
                                ),
                                ResponsiveGap(16),
                                _InfoField(
                                  label: s.driversId,
                                  value: _driverIdDisplay,
                                  readOnly: true,
                                ),
                                ResponsiveGap(16),
                                _InfoField(
                                  label: s.memberSinceLabel,
                                  value: _memberSinceDisplay,
                                  readOnly: true,
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
                    label: _isSaving
                        ? s.saving
                        : _isEditing
                            ? s.saveChanges
                            : s.edit,
                    color: AppColors.loginButton,
                    onPressed: _isSaving ? () {} : _onPrimaryAction,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: dashboard.secondaryText,
              size: r.iconMd * 1.6,
            ),
            ResponsiveGap(12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.satoshi,
                fontSize: r.bodySize,
                color: dashboard.secondaryText,
              ),
            ),
            ResponsiveGap(20),
            RideActionButton(
              label: s.retry,
              color: AppColors.loginButton,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _LazyPersonalInfoContent extends StatefulWidget {
  const _LazyPersonalInfoContent();

  @override
  State<_LazyPersonalInfoContent> createState() =>
      _LazyPersonalInfoContentState();
}

class _LazyPersonalInfoContentState extends State<_LazyPersonalInfoContent>
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
                width: r.w(88).clamp(72.0, 110.0),
                borderRadius: r.gap(8),
              ),
              ResponsiveGap(24),
              Center(
                child: _LazyBlock(
                  opacity: opacity,
                  color: dashboard.secondaryText,
                  height: r.w(96).clamp(84.0, 108.0),
                  width: r.w(96).clamp(84.0, 108.0),
                  borderRadius: 999,
                ),
              ),
              ResponsiveGap(10),
              Center(
                child: _LazyBlock(
                  opacity: opacity,
                  color: dashboard.secondaryText,
                  height: r.sp(16).clamp(14.0, 18.0),
                  width: r.w(220).clamp(180.0, 260.0),
                ),
              ),
              ResponsiveGap(28),
              _LazyBlock(
                opacity: opacity,
                color: dashboard.primaryText,
                height: r.sp(18).clamp(16.0, 20.0),
                width: r.w(120).clamp(100.0, 140.0),
                borderRadius: r.gap(6),
              ),
              ResponsiveGap(16),
              ...List.generate(4, (index) {
                return Padding(
                  padding: EdgeInsets.only(bottom: r.gap(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LazyBlock(
                        opacity: opacity,
                        color: dashboard.primaryText,
                        height: r.sp(16).clamp(14.0, 18.0),
                        width: r.w(72).clamp(60.0, 90.0),
                      ),
                      ResponsiveGap(8),
                      _LazyBlock(
                        opacity: opacity,
                        color: dashboard.inputFill,
                        height: r.h(48).clamp(44.0, 52.0),
                        width: double.infinity,
                        borderRadius: r.gap(10),
                      ),
                    ],
                  ),
                );
              }),
              ResponsiveGap(12),
              _LazyBlock(
                opacity: opacity,
                color: dashboard.primaryText,
                height: r.sp(18).clamp(16.0, 20.0),
                width: r.w(132).clamp(110.0, 150.0),
                borderRadius: r.gap(6),
              ),
              ResponsiveGap(16),
              ...List.generate(2, (index) {
                return Padding(
                  padding: EdgeInsets.only(bottom: r.gap(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LazyBlock(
                        opacity: opacity,
                        color: dashboard.primaryText,
                        height: r.sp(16).clamp(14.0, 18.0),
                        width: r.w(96).clamp(80.0, 110.0),
                      ),
                      ResponsiveGap(8),
                      _LazyBlock(
                        opacity: opacity,
                        color: dashboard.inputFill,
                        height: r.h(48).clamp(44.0, 52.0),
                        width: double.infinity,
                        borderRadius: r.gap(10),
                      ),
                    ],
                  ),
                );
              }),
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
    required this.width,
    this.borderRadius = 999,
  });

  final double opacity;
  final Color color;
  final double height;
  final double width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _PersonalInfoAvatar extends StatelessWidget {
  const _PersonalInfoAvatar({
    required this.r,
    required this.onEditTap,
    this.avatarUrl,
    this.displayName,
    this.localImage,
    this.isUploading = false,
  });

  final AppResponsive r;
  final VoidCallback onEditTap;
  final String? avatarUrl;
  final String? displayName;
  final File? localImage;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final size = r.w(96).clamp(84.0, 108.0);
    final borderWidth = r.w(2.5).clamp(2.0, 3.0);
    final editSize = r.w(28).clamp(24.0, 32.0);
    final innerSize = size - (borderWidth * 2);

    Widget avatarContent;
    if (localImage != null) {
      avatarContent = Image.file(
        localImage!,
        width: innerSize,
        height: innerSize,
        fit: BoxFit.cover,
      );
    } else {
      avatarContent = ProfileAvatarImage(
        size: innerSize,
        avatarUrl: avatarUrl,
        displayName: displayName,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.loginButton,
                  width: borderWidth,
                ),
              ),
              child: ClipOval(child: avatarContent),
            ),
          ),
          if (isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: innerSize * 0.35,
                  height: innerSize * 0.35,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
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
                onTap: isUploading ? null : onEditTap,
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
    this.controller,
    this.isEditing = false,
    this.readOnly = false,
  });

  final String label;
  final String value;
  final TextEditingController? controller;
  final bool isEditing;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final canEdit = isEditing && !readOnly && controller != null;

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
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: r.gap(14),
            vertical: canEdit ? r.gap(4) : r.h(14),
          ),
          decoration: BoxDecoration(
            color: dashboard.inputFill,
            borderRadius: BorderRadius.circular(r.gap(10)),
          ),
          child: canEdit
              ? TextField(
                  controller: controller,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(15).clamp(14.0, 17.0),
                    color: dashboard.primaryText,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                )
              : Text(
                  value.isEmpty ? '--' : value,
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(15).clamp(14.0, 17.0),
                    color: dashboard.secondaryText,
                  ),
                ),
        ),
      ],
    );
  }
}
