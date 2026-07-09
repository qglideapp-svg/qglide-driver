import 'package:flutter/material.dart';

import 'onboarding_page_model.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingController({List<OnboardingPageModel>? pages})
      : pages = pages ?? OnboardingPageModel.pages;

  final List<OnboardingPageModel> pages;
  final PageController pageController = PageController();

  int _currentPage = 0;

  int get currentPage => _currentPage;
  int get pageCount => pages.length;
  bool get isFirstPage => _currentPage == 0;
  bool get isLastPage => _currentPage == pageCount - 1;

  OnboardingPageModel get currentPageData => pages[_currentPage];

  void onPageChanged(int index) {
    if (_currentPage == index) return;
    _currentPage = index;
    notifyListeners();
  }

  Future<void> nextPage() {
    return pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> previousPage() {
    return pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
