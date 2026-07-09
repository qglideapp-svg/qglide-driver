import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/app_strings.dart';
import '../../../services/auth_service.dart';
import 'driver_document_type.dart';

class DocumentUploadController extends ChangeNotifier {
  final _imagePicker = ImagePicker();
  final _uploaded = <String, bool>{};
  final _uploading = <String, bool>{};
  final _deleting = <String, bool>{};

  bool isUploaded(String documentType) => _uploaded[documentType] == true;
  bool isUploading(String documentType) => _uploading[documentType] == true;
  bool isDeleting(String documentType) => _deleting[documentType] == true;
  bool get isAnyUploading => _uploading.values.any((v) => v);
  bool get isAnyDeleting => _deleting.values.any((v) => v);
  bool get isAnyBusy => isAnyUploading || isAnyDeleting;

  bool isStepComplete(int step) =>
      DriverDocumentType.typesForStep(step).every(isUploaded);

  bool get allDocumentsUploaded =>
      DriverDocumentType.all.every(isUploaded);

  int get firstIncompleteStep {
    for (var step = 1; step <= DriverDocumentType.contentStepCount; step++) {
      if (!isStepComplete(step)) return step;
    }
    return DriverDocumentType.contentStepCount;
  }

  /// Loads uploaded document types from onboarding-status and user profile.
  Future<void> syncUploadedDocuments() async {
    final uploadedTypes = await AuthService.resolveUploadedDocumentTypes();

    _uploaded
      ..clear()
      ..addEntries(
        uploadedTypes
            .where(DriverDocumentType.all.contains)
            .map((type) => MapEntry(type, true)),
      );
    notifyListeners();
  }

  Future<String?> pickAndUploadDocument(String documentType) async {
    if (_uploading[documentType] == true || _deleting[documentType] == true) {
      return null;
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return null;

      _uploading[documentType] = true;
      notifyListeners();

      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return AppStrings.current().errFileEmpty;
      }
      if (bytes.length > 10 * 1024 * 1024) {
        return AppStrings.current().errFileSize;
      }

      final mimeType = AuthService.mimeTypeFromPath(picked.path);
      final response = await AuthService.uploadDocument(
        documentType: documentType,
        fileBase64: base64Encode(bytes),
        mimeType: mimeType,
        fileSize: bytes.length,
      );

      if (response['success'] == true ||
          AuthService.isDocumentAlreadyUploadedResponse(response)) {
        await syncUploadedDocuments();
        if (!isUploaded(documentType)) {
          _uploaded[documentType] = true;
          notifyListeners();
        }
        return null;
      }

      return AuthService.extractErrorMessage(
        response,
        fallback: AppStrings.current().errUploadDocument(documentType),
      );
    } on MissingPluginException {
      return AppStrings.current().errPhotoPicker;
    } catch (e) {
      return AppStrings.current().errUploadDocumentFailed(e);
    } finally {
      _uploading[documentType] = false;
      notifyListeners();
    }
  }

  Future<String?> deleteUploadedDocument(String documentType) async {
    if (_uploading[documentType] == true || _deleting[documentType] == true) {
      return null;
    }
    if (!isUploaded(documentType)) return null;

    try {
      _deleting[documentType] = true;
      notifyListeners();

      final response = await AuthService.deleteDocument(
        documentType: documentType,
      );

      if (response['success'] == true) {
        await syncUploadedDocuments();
        if (isUploaded(documentType)) {
          _uploaded.remove(documentType);
          notifyListeners();
        }
        return null;
      }

      return AuthService.extractErrorMessage(
        response,
        fallback: AppStrings.current().errDeleteDocument(documentType),
      );
    } catch (e) {
      return AppStrings.current().errDeleteDocument(documentType);
    } finally {
      _deleting[documentType] = false;
      notifyListeners();
    }
  }
}
