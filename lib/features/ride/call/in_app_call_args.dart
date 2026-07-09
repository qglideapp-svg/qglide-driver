import 'models/zego_call_session.dart';

class InAppCallArgs {
  const InAppCallArgs({
    required this.rideId,
    required this.counterpartName,
    this.riderPhotoUrl,
    this.riderRating,
    this.incomingPayload,
  });

  final String rideId;
  final String counterpartName;
  final String? riderPhotoUrl;
  final double? riderRating;
  final IncomingCallPayload? incomingPayload;
}
