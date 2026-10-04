import 'package:flutter/foundation.dart';

import '../../../domain/models/security_models.dart';
import '../data/face_verification_repository.dart';

enum VerificationStep { idle, captured, analyzed, confirmed }

class FaceVerificationController extends ChangeNotifier {
  FaceVerificationController(this._repository);

  final FaceVerificationRepository _repository;

  VerificationStep _step = VerificationStep.idle;
  VerificationStep get step => _step;

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _capturedImage;
  String? get capturedImage => _capturedImage;

  FaceMatchResultModel? _matchResult;
  FaceMatchResultModel? get matchResult => _matchResult;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void setCapturedImage(String imageBase64) {
    _capturedImage = imageBase64;
    _matchResult = null;
    _statusMessage = null;
    _errorMessage = null;
    _step = VerificationStep.captured;
    notifyListeners();
  }

  void clearPhoto() {
    _capturedImage = null;
    _matchResult = null;
    _statusMessage = null;
    _errorMessage = null;
    _step = VerificationStep.idle;
    notifyListeners();
  }

  Future<void> runFaceMatch({int? targetResidentId, double threshold = 0.70}) async {
    if (_capturedImage == null) return;

    _isAnalyzing = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final result = await _repository.matchFace(
        capturedImage: _capturedImage!,
        targetResidentId: targetResidentId,
        threshold: threshold,
      );
      _matchResult = result;
      _step = VerificationStep.analyzed;
    } on FaceVerificationException catch (e) {
      _errorMessage = e.message;
    } on Object catch (e) {
      _errorMessage = 'Error inesperado: $e';
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<bool> confirmVerification({
    required bool humanConfirmed,
    String eventType = 'ENTRY',
    String notes = '',
  }) async {
    if (_capturedImage == null || _matchResult == null) return false;

    _isSubmitting = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await _repository.confirmVerification(
        capturedImage: _capturedImage!,
        matchedResidentId: _matchResult!.matchedResident?.id,
        biometricReferenceId: _matchResult!.biometricReferenceId,
        similarityScore: _matchResult!.similarityScore,
        threshold: _matchResult!.threshold,
        result: _matchResult!.result,
        humanConfirmed: humanConfirmed,
        createAccessEvent: humanConfirmed && _matchResult!.result != 'NO_MATCH',
        eventType: eventType,
        notes: notes,
      );

      _statusMessage = humanConfirmed
          ? '✅ Identidad de ${_matchResult!.matchedResident?.fullName ?? 'Residente'} CONFIRMADA.'
          : '❌ Resultado de verificación RECHAZADO.';
      _step = VerificationStep.confirmed;
      return true;
    } on FaceVerificationException catch (e) {
      _errorMessage = e.message;
      return false;
    } on Object catch (e) {
      _errorMessage = 'Error inesperado: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
