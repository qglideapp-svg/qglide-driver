class RideChatArgs {
  const RideChatArgs({
    required this.rideId,
    this.riderName,
    this.riderPhotoUrl,
    this.pickupAddress,
    this.riderRating,
  });

  final String rideId;
  final String? riderName;
  final String? riderPhotoUrl;
  final String? pickupAddress;
  final double? riderRating;
}
