class OnboardingPageModel {
  const OnboardingPageModel({required this.imageAsset});

  final String imageAsset;

  static const pages = [
    OnboardingPageModel(imageAsset: 'assets/first_screen.png'),
    OnboardingPageModel(imageAsset: 'assets/second_screen.png'),
    OnboardingPageModel(imageAsset: 'assets/third_screen.png'),
    OnboardingPageModel(imageAsset: 'assets/fouth_screen.png'),
  ];
}
