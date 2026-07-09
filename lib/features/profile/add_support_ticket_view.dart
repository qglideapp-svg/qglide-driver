import 'dart:async';
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
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/app_strings_scope.dart';
import '../../shared/widgets/ride_panel_shared.dart';
import 'models/support_ticket.dart';
import 'support_ticket_detail_view.dart';

class AddSupportTicketView extends StatefulWidget {
  const AddSupportTicketView({super.key});

  @override
  State<AddSupportTicketView> createState() => _AddSupportTicketViewState();
}

class _AddSupportTicketViewState extends State<AddSupportTicketView> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _attachments = <_PendingAttachment>[];

  var _selectedCategory = DriverSupportTicketCategory.defaultValue;
  var _isSubmitting = false;
  var _isUploadingAttachment = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    if (_isSubmitting || _isUploadingAttachment) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;

      final file = File(pickedFile.path);
      final fileName = pickedFile.name.trim().isNotEmpty
          ? pickedFile.name.trim()
          : file.uri.pathSegments.last;
      final fileType = _mimeTypeForFileName(fileName);
      final fileSize = await file.length();

      setState(() {
        _attachments.add(
          _PendingAttachment(
            file: file,
            fileName: fileName,
            fileType: fileType,
            fileSize: fileSize,
          ),
        );
      });
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.current().errFilePickerNotReady,
            style: TextStyle(fontFamily: AppFonts.satoshi),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.current().errPickFile('$e'),
            style: TextStyle(fontFamily: AppFonts.satoshi),
          ),
        ),
      );
    }
  }

  Future<List<SupportTicketAttachmentPayload>> _uploadAttachments() async {
    final uploaded = <SupportTicketAttachmentPayload>[];

    for (final attachment in _attachments) {
      if (attachment.uploaded != null) {
        uploaded.add(attachment.uploaded!);
        continue;
      }

      setState(() => _isUploadingAttachment = true);

      final bytes = await attachment.file.readAsBytes();
      final response = await AuthService.uploadAvatar(
        base64Image: base64Encode(bytes),
      );

      if (response['success'] != true) {
        throw _AttachmentUploadException(
          AuthService.extractErrorMessage(
            response,
            fallback: 'Could not upload attachment.',
          ),
        );
      }

      final fileUrl = AuthService.extractUploadedAvatarUrl(response);
      if (fileUrl == null || fileUrl.isEmpty) {
        throw const _AttachmentUploadException(
          'Upload succeeded but no file URL was returned.',
        );
      }

      final payload = SupportTicketAttachmentPayload(
        fileUrl: fileUrl,
        fileName: attachment.fileName,
        fileType: attachment.fileType,
        fileSize: attachment.fileSize,
      );
      attachment.uploaded = payload;
      uploaded.add(payload);
    }

    if (mounted) {
      setState(() => _isUploadingAttachment = false);
    }

    return uploaded;
  }

  Future<void> _submitTicket() async {
    if (_isSubmitting) return;

    final subject = _subjectController.text.trim();
    final description = _messageController.text.trim();

    if (subject.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in the subject and description.',
            style: TextStyle(fontFamily: AppFonts.satoshi),
          ),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final attachments = _attachments.isEmpty
          ? null
          : await _uploadAttachments();

      final response = await AuthService.createSupportTicket(
        subject: subject,
        description: description,
        category: _selectedCategory,
        attachments: attachments,
      );

      if (!mounted) return;

      if (response['success'] != true) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthService.extractErrorMessage(
                response,
                fallback: 'Could not create support ticket.',
              ),
              style: TextStyle(fontFamily: AppFonts.satoshi),
            ),
            backgroundColor: Colors.black87,
          ),
        );
        return;
      }

      final ticket = AuthService.extractCreatedSupportTicket(response);
      if (ticket == null || ticket.id.isEmpty) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop(true);
        return;
      }

      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.supportTicketDetail,
        arguments: SupportTicketDetailArgs(
          ticketId: ticket.id,
          subject: ticket.subject,
          displayId: ticket.displayId,
        ),
      );
    } on _AttachmentUploadException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isUploadingAttachment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
            style: TextStyle(fontFamily: AppFonts.satoshi),
          ),
          backgroundColor: Colors.black87,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isUploadingAttachment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not submit ticket: $e',
            style: TextStyle(fontFamily: AppFonts.satoshi),
          ),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);
    final horizontalPadding = r.gap(r.isTablet ? 32 : 20);
    final isBusy = _isSubmitting || _isUploadingAttachment;

    return Scaffold(
      backgroundColor: dashboard.screenBackground,
      appBar: AppBar(
        backgroundColor: dashboard.screenBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: isBusy ? null : () => Navigator.of(context).maybePop(),
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
                  'Add Support Ticket',
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(27).clamp(24.0, 30.0),
                    fontWeight: FontWeight.w700,
                    color: dashboard.primaryText,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: r.gap(8)),
                Text(
                  'Describe your issue and our team will get back to you.',
                  style: TextStyle(
                    fontFamily: AppFonts.satoshi,
                    fontSize: r.sp(14).clamp(13.0, 16.0),
                    color: dashboard.secondaryText,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: r.gap(24)),
                _CategoryField(
                  value: _selectedCategory,
                  enabled: !isBusy,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedCategory = value);
                  },
                ),
                SizedBox(height: r.gap(16)),
                _TicketField(
                  label: 'Subject',
                  hintText: 'Enter ticket subject',
                  controller: _subjectController,
                  enabled: !isBusy,
                ),
                SizedBox(height: r.gap(16)),
                _TicketField(
                  label: 'Description',
                  hintText: 'Describe your issue',
                  controller: _messageController,
                  maxLines: 6,
                  enabled: !isBusy,
                ),
                SizedBox(height: r.gap(16)),
                _AttachmentsSection(
                  attachments: _attachments,
                  enabled: !isBusy,
                  onAdd: () => unawaited(_pickAttachment()),
                  onRemove: (index) {
                    setState(() => _attachments.removeAt(index));
                  },
                ),
                SizedBox(height: r.gap(28)),
                RideActionButton(
                  label: _isUploadingAttachment
                      ? 'Uploading attachment...'
                      : _isSubmitting
                          ? 'Submitting...'
                          : 'Submit Ticket',
                  color: AppColors.loginButton,
                  isLoading: isBusy,
                  onPressed: () => unawaited(_submitTicket()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingAttachment {
  _PendingAttachment({
    required this.file,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
  });

  final File file;
  final String fileName;
  final String fileType;
  final int fileSize;
  SupportTicketAttachmentPayload? uploaded;
}

class _AttachmentUploadException implements Exception {
  const _AttachmentUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _mimeTypeForFileName(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'pdf' => 'application/pdf',
    _ => 'application/octet-stream',
  };
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(16).clamp(15.0, 18.0),
            fontWeight: FontWeight.w600,
            color: dashboard.primaryText,
          ),
        ),
        SizedBox(height: r.gap(8)),
        DropdownButtonFormField<String>(
          key: ValueKey(value),
          initialValue: value,
          items: DriverSupportTicketCategory.options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option.key,
                  child: Text(
                    option.value,
                    style: TextStyle(
                      fontFamily: AppFonts.satoshi,
                      fontSize: r.sp(16).clamp(15.0, 18.0),
                      color: dashboard.primaryText,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: dashboard.inputFill,
            contentPadding: EdgeInsets.symmetric(
              horizontal: r.gap(14),
              vertical: r.gap(14),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.gap(10)),
              borderSide: BorderSide.none,
            ),
          ),
          dropdownColor: dashboard.surface,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: dashboard.mutedText),
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(16).clamp(15.0, 18.0),
            color: dashboard.primaryText,
          ),
        ),
      ],
    );
  }
}

class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
    required this.enabled,
  });

  final List<_PendingAttachment> attachments;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments (optional)',
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(16).clamp(15.0, 18.0),
            fontWeight: FontWeight.w600,
            color: dashboard.primaryText,
          ),
        ),
        SizedBox(height: r.gap(8)),
        OutlinedButton.icon(
          onPressed: enabled ? onAdd : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.loginButton,
            side: BorderSide(color: AppColors.loginButton.withValues(alpha: 0.35)),
            padding: EdgeInsets.symmetric(
              horizontal: r.gap(14),
              vertical: r.gap(12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.gap(10)),
            ),
          ),
          icon: const Icon(Icons.attach_file_rounded),
          label: Text(
            'Add attachment',
            style: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(15).clamp(14.0, 16.0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (attachments.isNotEmpty) ...[
          SizedBox(height: r.gap(10)),
          ...List.generate(attachments.length, (index) {
            final attachment = attachments[index];
            return Container(
              margin: EdgeInsets.only(bottom: r.gap(8)),
              padding: EdgeInsets.symmetric(
                horizontal: r.gap(12),
                vertical: r.gap(10),
              ),
              decoration: BoxDecoration(
                color: dashboard.inputFill,
                borderRadius: BorderRadius.circular(r.gap(10)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.insert_drive_file_outlined,
                    size: r.iconSm,
                    color: AppColors.loginButton,
                  ),
                  SizedBox(width: r.gap(10)),
                  Expanded(
                    child: Text(
                      attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.satoshi,
                        fontSize: r.sp(14).clamp(13.0, 15.0),
                        color: dashboard.primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: enabled ? () => onRemove(index) : null,
                    icon: Icon(
                      Icons.close_rounded,
                      size: r.iconSm,
                      color: dashboard.secondaryText,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _TicketField extends StatelessWidget {
  const _TicketField({
    required this.label,
    required this.hintText,
    required this.controller,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dashboard = DashboardTheme.of(context);

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
        SizedBox(height: r.gap(8)),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          textInputAction:
              maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: AppFonts.satoshi,
              fontSize: r.sp(16).clamp(15.0, 18.0),
              color: dashboard.mutedText,
            ),
            filled: true,
            fillColor: dashboard.inputFill,
            contentPadding: EdgeInsets.symmetric(
              horizontal: r.gap(14),
              vertical: r.gap(14),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.gap(10)),
              borderSide: BorderSide.none,
            ),
          ),
          style: TextStyle(
            fontFamily: AppFonts.satoshi,
            fontSize: r.sp(16).clamp(15.0, 18.0),
            color: dashboard.primaryText,
          ),
        ),
      ],
    );
  }
}
