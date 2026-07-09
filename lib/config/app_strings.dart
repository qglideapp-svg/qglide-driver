import 'package:flutter/material.dart';

import '../services/app_locale_service.dart';

/// App-wide localized strings. Use [AppStrings.current] in services/controllers,
/// or [AppStringsScope.of] in widgets.
class AppStrings {
  const AppStrings({required this.isArabic});

  factory AppStrings.current() =>
      AppStrings(isArabic: AppLocaleService.instance.isArabic);

  factory AppStrings.fromEnglishSelected(bool englishSelected) {
    return AppStrings(isArabic: !englishSelected);
  }

  final bool isArabic;

  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  String _t(String en, String ar) => isArabic ? ar : en;

  // ── Common ────────────────────────────────────────────────────────────────
  String get cancel => _t('Cancel', 'إلغاء');
  String get delete => _t('Delete', 'حذف');
  String get done => _t('Done', 'تم');
  String get retry => _t('Retry', 'إعادة المحاولة');
  String get edit => _t('Edit', 'تعديل');
  String get submit => _t('Submit', 'إرسال');
  String get saveChanges => _t('Save Changes', 'حفظ التغييرات');
  String get saving => _t('Saving...', 'جاري الحفظ...');
  String get submitting => _t('Submitting...', 'جاري الإرسال...');
  String get uploading => _t('Uploading...', 'جاري الرفع...');
  String get deleting => _t('Deleting...', 'جاري الحذف...');
  String get settings => _t('Settings', 'الإعدادات');
  String get details => _t('Details', 'التفاصيل');
  String get next => _t('Next', 'التالي');
  String get skip => _t('Skip', 'تخطي');
  String get getStarted => _t('Get Started', 'ابدأ الآن');
  String get previous => _t('Previous', 'السابق');
  String get rider => _t('Rider', 'الراكب');
  String get driver => _t('Driver', 'السائق');
  String get driverFallback => _t('Driver', 'السائق');
  String get approved => _t('Approved', 'معتمد');
  String get unavailable => _t('Unavailable', 'غير متاح');
  String get google => _t('Google', 'Google');
  String get apple => _t('Apple', 'Apple');
  String get or => _t('or', 'أو');
  String get orDivider => _t('OR', 'أو');
  String get qglide => 'QGlide';

  // ── Profile ───────────────────────────────────────────────────────────────
  String get personalInformation =>
      _t('Personal Information', 'المعلومات الشخصية');
  String get manageVehicle => _t('Manage Vehicle', 'إدارة المركبة');
  String get language => _t('Language', 'اللغة');
  String get english => _t('English', 'الإنجليزية');
  String get arabic => _t('Arabic', 'العربية');
  String get support => _t('Support', 'الدعم');
  String get helpCenter => _t('Help Center', 'مركز المساعدة');
  String get currentLocation => _t('Current Location', 'الموقع الحالي');
  String get locationUnavailable => _t('Unavailable', 'غير متاح');
  String get logOut => _t('Log Out', 'تسجيل الخروج');
  String get deleteAccount => _t('Delete Account', 'حذف الحساب');
  String get deleteAccountConfirmTitle =>
      _t('Delete account?', 'حذف الحساب؟');
  String get deleteAccountConfirmMessage => _t(
        'Are you sure you want to delete your account? This action cannot be undone.',
        'هل أنت متأكد أنك تريد حذف حسابك؟ لا يمكن التراجع عن هذا الإجراء.',
      );
  String memberSince(String date) =>
      _t('Member Since $date', 'عضو منذ $date');

  // ── Auth: Login ─────────────────────────────────────────────────────────────
  String get loginTitle => _t('Welcome back, driver.', 'مرحباً بعودتك، سائق.');
  String get loginSubtitle => _t(
        'Sign in to your account to go online and start earning.',
        'سجّل الدخول إلى حسابك للاتصال بالإنترنت وبدء الكسب.',
      );
  String get emailAddress => _t('Email Address', 'البريد الإلكتروني');
  String get enterPassword => _t('Enter Password', 'أدخل كلمة المرور');
  String get forgottenPassword => _t('Forgotten password', 'نسيت كلمة المرور');
  String get login => _t('Login', 'تسجيل الدخول');
  String get signingIn => _t('Signing in...', 'جاري تسجيل الدخول...');
  String get dontHaveAccount => _t("Don't have an account? ", 'ليس لديك حساب؟ ');
  String get signUp => _t('Sign up', 'إنشاء حساب');
  String get continueWithApple =>
      _t('Continue with Apple', 'المتابعة مع Apple');
  String get continueWithGoogle =>
      _t('Continue with Google', 'المتابعة مع Google');
  String get signInFailed =>
      _t('Sign in failed. Please try again.', 'فشل تسجيل الدخول. يرجى المحاولة مرة أخرى.');
  String get errEmailPasswordRequired => _t(
        'Email and password are required.',
        'البريد الإلكتروني وكلمة المرور مطلوبان.',
      );

  // ── Auth: Signup ────────────────────────────────────────────────────────────
  String get createDriverAccount =>
      _t('Create Driver Account', 'إنشاء حساب سائق');
  String get signupSubtitle =>
      _t("Let's get you on the road.", 'لنبدأ رحلتك على الطريق.');
  String get fullName => _t('Full Name', 'الاسم الكامل');
  String get phoneNumber => _t('Phone Number', 'رقم الهاتف');
  String get confirmPassword => _t('Confirm Password', 'تأكيد كلمة المرور');
  String get referralCodeOptional =>
      _t('Referral Code (Optional)', 'رمز الإحالة (اختياري)');
  String get creatingAccount => _t('Creating account...', 'جاري إنشاء الحساب...');
  String get createAccount => _t('Create Account', 'إنشاء حساب');
  String get signupConfirmPhoneTitle =>
      _t('Confirm your phone number', 'تأكيد رقم هاتفك');
  String get signupConfirmPhoneMessage => _t(
        'Please make sure this number is correct and belongs to you before continuing.',
        'يرجى التأكد من أن هذا الرقم صحيح ويخصك قبل المتابعة.',
      );
  String get proceed => _t('Proceed', 'متابعة');
  String get agreeToTermsPrefix =>
      _t('By creating an account, you agree to our ', 'بإنشاء حساب، فإنك توافق على ');
  String get terms => _t('Terms', 'الشروط');
  String get privacyPolicy => _t('Privacy Policy.', 'سياسة الخصوصية.');
  String get privacyPolicyTitle => _t('Privacy Policy', 'سياسة الخصوصية');
  String get agreeToTermsAnd => _t(' and ', ' و');
  String get termsAndConditions =>
      _t('Terms and Conditions', 'الشروط والأحكام');
  String get alreadyHaveAccount =>
      _t('Already have an account? ', 'لديك حساب بالفعل؟ ');
  String get signedInCompleteDetails => _t(
        'Signed in. Complete your details below, then tap Create Account.',
        'تم تسجيل الدخول. أكمل بياناتك أدناه، ثم اضغط إنشاء حساب.',
      );
  String get fillRequiredFields =>
      _t('Please fill in all required fields.', 'يرجى ملء جميع الحقول المطلوبة.');
  String get passwordsDoNotMatch =>
      _t('Passwords do not match.', 'كلمتا المرور غير متطابقتين.');
  String get passwordRequirements => _t(
        'Password must be at least 8 characters and include a number and a symbol.',
        'يجب أن تكون كلمة المرور 8 أحرف على الأقل وتتضمن رقماً ورمزاً.',
      );

  // ── Auth: Forgot password ───────────────────────────────────────────────────
  String get forgotPasswordTitle =>
      _t('Forgot Password', 'نسيت كلمة المرور');
  String get forgotPasswordTitleQuestion =>
      _t('Forgot Password?', 'نسيت كلمة المرور؟');
  String get forgotPasswordSubtitle => _t(
        'Enter your email address and we will send you a reset link.',
        'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين.',
      );
  String get forgotPasswordSubtitleRelaxed => _t(
        'No worries. Enter your email and we\'ll send you a link to reset your password.',
        'لا تقلق. أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور.',
      );
  String get sendResetLink => _t('Send Reset Link', 'إرسال رابط إعادة التعيين');
  String get sendingResetLink =>
      _t('Sending reset link...', 'جاري إرسال رابط إعادة التعيين...');
  String get rememberedPassword =>
      _t('Remembered your password? ', 'تذكرت كلمة المرور؟ ');
  String get backToLogin => _t('Back to Login', 'العودة لتسجيل الدخول');

  // ── Auth: Verification ──────────────────────────────────────────────────────
  String get verifyPhone => _t('Verify Phone', 'تحقق من الهاتف');
  String get enterVerificationCodeTitle =>
      _t('Enter Verification Code', 'أدخل رمز التحقق');
  String get enterVerificationCode => _t(
        'Enter the verification code sent to your phone.',
        'أدخل رمز التحقق المرسل إلى هاتفك.',
      );
  String get verificationCodeSent =>
      _t('Verification code sent.', 'تم إرسال رمز التحقق.');
  String get enterFullOtpCode => _t(
        'Please enter the full 6-digit verification code.',
        'يرجى إدخال رمز التحقق المكوّن من 6 أرقام بالكامل.',
      );
  String get resendCodeForNewSms => _t(
        ' Tap Resend Code to get a new SMS.',
        ' اضغط إعادة إرسال الرمز للحصول على رسالة نصية جديدة.',
      );
  String get needHelp => _t('Need help? ', 'تحتاج مساعدة؟ ');
  String get contactUs => _t('Contact us', 'تواصل معنا');
  String get smsManualEntryTimedOut => _t(
        'This device cannot read the SMS automatically. Type the code below, then tap Confirm.',
        'لا يمكن لهذا الجهاز قراءة الرسالة تلقائياً. اكتب الرمز أدناه، ثم اضغط تأكيد.',
      );
  String get smsManualEntry => _t(
        'Type the code from your SMS below, then tap Confirm.',
        'اكتب الرمز من رسالتك النصية أدناه، ثم اضغط تأكيد.',
      );
  String get sendingCode => _t('Sending code...', 'جاري إرسال الرمز...');
  String get verifyingAutomatically =>
      _t('Verifying automatically...', 'جاري التحقق تلقائياً...');
  String get confirm => _t('Confirm', 'تأكيد');
  String get instructionVerifyingAuto => _t(
        'Verifying your number automatically. Code sent to ',
        'جاري التحقق من رقمك تلقائياً. تم إرسال الرمز إلى ',
      );
  String get instructionSendingCode => _t(
        'Sending a 6-digit code to ',
        'جاري إرسال رمز مكوّن من 6 أرقام إلى ',
      );
  String get instructionManualTimedOut => _t(
        'Enter the code from your SMS manually. It was sent to ',
        'أدخل الرمز من رسالتك النصية يدوياً. تم إرساله إلى ',
      );
  String get instructionEnterCode => _t(
        'Enter the 6-digit code sent to ',
        'أدخل الرمز المكوّن من 6 أرقام المرسل إلى ',
      );
  String get resendCode => _t('Resend Code', 'إعادة إرسال الرمز');
  String get verify => _t('Verify', 'تحقق');
  String get verifying => _t('Verifying...', 'جاري التحقق...');

  // ── Auth: Document upload ───────────────────────────────────────────────────
  String get documentUploadTitle =>
      _t('Upload Documents', 'رفع المستندات');
  String get documentUploadTitleSingular =>
      _t('Upload Your Document', 'ارفع مستندك');
  String get documentUploadSubtitle => _t(
        'Upload the required documents to complete your verification.',
        'ارفع المستمندات المطلوبة لإكمال التحقق.',
      );
  String get documentUploadSubtitleDriver => _t(
        'Please provide the required documents to verify your driver profile and start taking trips.',
        'يرجى تقديم المستندات المطلوبة للتحقق من ملفك كسائق وبدء قبول الرحلات.',
      );
  String get uploadRequired => _t('Upload required', 'الرفع مطلوب');
  String get documentUploaded => _t('Uploaded', 'تم الرفع');
  String get replaceDocument => _t('Replace Document', 'استبدال المستند');
  String get uploadDocument => _t('Upload Document', 'رفع المستند');
  String get profilePicture => _t('Profile picture', 'صورة الملف الشخصي');
  String get uploadPhoto => _t('Upload Photo', 'رفع الصورة');
  String get waitForUploads => _t(
        'Please wait for uploads to finish.',
        'يرجى الانتظار حتى تنتهي عمليات الرفع.',
      );
  String get uploadAllStepDocs => _t(
        'Please upload all documents on this step before continuing.',
        'يرجى رفع جميع المستندات في هذه الخطوة قبل المتابعة.',
      );
  String get uploadAllBeforeSubmit => _t(
        'Please upload all required documents before submitting.',
        'يرجى رفع جميع المستندات المطلوبة قبل الإرسال.',
      );
  String get documentUploadInfoFooter => _t(
        'Ensure all documents are clearly visible, well-lit, and capture all four corners of the document. Accepted formats: JPEG, PNG, WebP, or PDF (max 10MB).',
        'تأكد من أن جميع المستندات واضحة ومضاءة جيداً وتظهر فيها الزوايا الأربع. الصيغ المقبولة: JPEG أو PNG أو WebP أو PDF (بحد أقصى 10 ميجابايت).',
      );
  String get continueButton => _t('Continue', 'متابعة');
  String get documentSubmissionSuccess => _t(
        'Documents submitted successfully!',
        'تم إرسال المستندات بنجاح!',
      );
  String get documentSubmissionSuccessTitle => _t(
        'Documents Submitted Successfully!',
        'تم إرسال المستندات بنجاح!',
      );
  String get documentSubmissionThankYou => _t(
        'Thank you for uploading your vehicle documents. Our team is reviewing your submission.',
        'شكراً لرفع مستندات مركبتك. فريقنا يراجع طلبك.',
      );
  String get underReview => _t('Under Review', 'قيد المراجعة');
  String get estimatedReviewTime => _t(
        'Estimated review time: 24\u201348 hours',
        'الوقت التقديري للمراجعة: 24\u201348 ساعة',
      );
  String get reviewStepOurTeam =>
      _t('Our team reviews your photos.', 'يراجع فريقنا صورك.');
  String get reviewStepNotification => _t(
        'You\u2019ll get a notification when approved.',
        'ستتلقى إشعاراً عند الموافقة.',
      );
  String get reviewStepStartRides => _t(
        'Start accepting rides after approval.',
        'ابدأ قبول الرحلات بعد الموافقة.',
      );
  List<String> get documentReviewSteps => [
        reviewStepOurTeam,
        reviewStepNotification,
        reviewStepStartRides,
      ];
  String documentLabel(String type) {
    switch (type) {
      case 'qatar_id':
        return _t('Qatar ID', 'بطاقة الهوية القطرية');
      case 'profile_picture':
        return profilePicture;
      case 'company_registration':
        return _t('Company registration', 'تسجيل الشركة');
      case 'driving_license':
        return _t('Driving license', 'رخصة القيادة');
      case 'vehicle_interior':
        return _t('Vehicle interior', 'داخل المركبة');
      case 'vehicle_exterior':
        return _t('Vehicle exterior', 'خارج المركبة');
      case 'vehicle_registration_estimara':
        return _t('Vehicle registration (Estimara)', 'تسجيل المركبة (استمارة)');
      default:
        return type;
    }
  }

  // ── Onboarding ──────────────────────────────────────────────────────────────
  String onboardingHeadline(int index) {
    switch (index) {
      case 0:
        return _t('Drive on your own terms.', 'قد بشروطك الخاصة.');
      case 1:
      case 3:
        return _t('One quick setup, then you\'re live.', 'إعداد سريع، ثم أنت جاهز.');
      case 2:
        return _t('A ride request, just for you.', 'طلب رحلة، مخصص لك.');
      default:
        return '';
    }
  }

  String onboardingSubtitle(int index) {
    switch (index) {
      case 0:
        return _t(
          'Drive whenever it suits you. Accept rides, deliveries, and rentals to grow your income',
          'قد وقتما يناسبك. اقبل الرحلات والتوصيلات والإيجارات لتنمية دخلك',
        );
      case 1:
        return _t(
          'Register in minutes, get verified, and start earning today.',
          'سجّل في دقائق، أكمل التحقق، وابدأ الكسب اليوم.',
        );
      case 2:
        return _t(
          'When a rider nearby needs a trip, you\'ll get an instant alert with everything you need to decide.',
          'عندما يحتاج راكب قريب إلى رحلة، ستتلقى تنبيهًا فوريًا بكل ما تحتاجه للقرار.',
        );
      case 3:
        return _t(
          'Register in minutes, get verified, and start earning today.',
          'سجّل في دقائق، ووثّق حسابك، وابدأ الكسب اليوم.',
        );
      default:
        return '';
    }
  }

  // ── Home / Dashboard ────────────────────────────────────────────────────────
  String get youAreOnline => _t('You are online', 'أنت متصل');
  String get youAreOffline => _t('You are offline', 'أنت غير متصل');
  String get goOnline => _t('Go Online', 'الاتصال');
  String get goOffline => _t('Go Offline', 'قطع الاتصال');
  String get topUp => _t('Top Up', 'شحن');
  String get withdraw => _t('Withdraw', 'سحب');
  String get earnings => _t('Earnings', 'الأرباح');
  String get walletBalance => _t('Wallet Balance', 'رصيد المحفظة');
  String get withdrawal => _t('Withdrawal', 'السحب');
  String get rawBalance => _t('Raw Balance', 'الرصيد الخام');
  String get verifiedBalance => _t('Verified Balance', 'الرصيد الموثّق');
  String get pendingWithdrawals =>
      _t('Pending withdrawals', 'عمليات السحب المعلقة');
  String get negativeBalance => _t('Negative Balance', 'الرصيد السالب');
  String get completedTrips => _t('Completed Trips', 'الرحلات المكتملة');
  String get enterAmount => _t('Enter Amount', 'أدخل المبلغ');
  String get noActiveRideToCall =>
      _t('No active ride to call.', 'لا توجد رحلة نشطة للاتصال.');
  String get noActiveRideToChat =>
      _t('No active ride to chat with.', 'لا توجد رحلة نشطة للمحادثة.');
  String get walletToppedUp =>
      _t('Wallet topped up successfully.', 'تم شحن المحفظة بنجاح.');
  String get topUpCancelled =>
      _t('Top-up was cancelled.', 'تم إلغاء الشحن.');
  String get confirmingPayment =>
      _t('Confirming your payment…', 'جارٍ تأكيد الدفع…');
  String get returningToWallet =>
      _t('Returning to your wallet…', 'العودة إلى محفظتك…');
  String get couldNotStartTopUp => _t(
        'Could not start top-up. Please try again.',
        'تعذر بدء الشحن. يرجى المحاولة مرة أخرى.',
      );
  String get locationRequiredForOnline => _t(
        'Location is required to go online and receive ride requests.',
        'الموقع مطلوب للاتصال واستقبال طلبات الرحلات.',
      );
  String get pickupNearby => _t('Pickup nearby', 'الاستلام قريب');

  // ── Ride panels ─────────────────────────────────────────────────────────────
  String get pickUpDestination => _t('Pick Up Destination', 'وجهة الاستلام');
  String get openWithWaze => _t('Open with waze', 'فتح في Waze');
  String get cancelRide => _t('Cancel Ride', 'إلغاء الرحلة');
  String get pickUpCompleted => _t('Pick up Completed', 'اكتمل الاستلام');
  String get startRide => _t('Start Ride', 'بدء الرحلة');
  String get tripToDestination => _t('Trip to Destination', 'الرحلة إلى الوجهة');
  String get completeTrip => _t('Complete Trip', 'إكمال الرحلة');
  String get ignoreBooking => _t('Ignore Booking', 'تجاهل الحجز');
  String get acceptBooking => _t('Accept Booking', 'قبول الحجز');
  String get addedStop => _t('Added stop', 'محطة إضافية');
  String get finalDestination => _t('Final destination', 'الوجهة النهائية');
  String get currentDestination => _t('Current destination', 'الوجهة الحالية');
  String get newStop => _t('New stop', 'محطة جديدة');
  String get updatedFare => _t('Updated fare', 'الأجرة المحدّثة');
  String get estimatedFare => _t('Estimated fare', 'الأجرة التقديرية');
  String get rideCompleted => _t('Ride Completed', 'اكتملت الرحلة');
  String get cancelTrip => _t('Cancel Trip', 'إلغاء الرحلة');
  String get cancelTripConfirm => _t(
        'Are you sure you want to cancel this trip?',
        'هل أنت متأكد أنك تريد إلغاء هذه الرحلة؟',
      );
  String get selectCancelReason =>
      _t('Select a reason for cancellation', 'اختر سبب الإلغاء');
  String cancelTripReason(int index) {
    const en = [
      'Unable to reach pickup',
      'Rider no-show',
      'Wrong pickup location',
      'Vehicle issue',
      'Emergency',
      'Other',
    ];
    const ar = [
      'تعذر الوصول إلى موقع الاستلام',
      'الراكب لم يحضر',
      'موقع الاستلام خاطئ',
      'مشكلة في المركبة',
      'حالة طوارئ',
      'أخرى',
    ];
    if (index < 0 || index >= en.length) return '';
    return isArabic ? ar[index] : en[index];
  }

  List<String> get cancelTripReasons =>
      List.generate(6, (index) => cancelTripReason(index));

  String get select => _t('Select', 'اختر');
  String get reasonForCancellingTrip =>
      _t('Reason for Cancelling trip', 'سبب إلغاء الرحلة');
  String get destination => _t('Destination', 'الوجهة');
  String get dropOffLocation => _t('Drop off location', 'موقع التسليم');
  String get pickUpLocation => _t('Pick Up Location', 'موقع الاستلام');
  String get riderAddsStopHint => _t(
        'If your rider adds a stop, you will see it right here',
        'إذا أضاف الراكب محطة، ستظهر هنا',
      );
  String get riderAddedAStop => _t('Rider added a stop', 'أضاف الراكب محطة');
  String riderAddedStops(int count) =>
      _t('Rider added $count stops', 'أضاف الراكب $count محطات');
  String get riderRequestedStop =>
      _t('Rider requested a stop', 'طلب الراكب إضافة محطة');
  String addedStopNumber(int number) =>
      _t('Added stop $number', 'المحطة $number');
  String get continueToAddedStopHint => _t(
        'Continue to the added stop, then proceed to the final destination.',
        'تابع إلى المحطة المضافة، ثم انتقل إلى الوجهة النهائية.',
      );
  String get reviewStopChangeHint => _t(
        'Review the stop change and accept it when you are ready.',
        'راجع تغيير المحطة واقبله عندما تكون جاهزاً.',
      );
  String get rideCompletedMessage => _t(
        'The trip has been completed successfully. Payment has been processed.',
        'اكتملت الرحلة بنجاح. تمت معالجة الدفع.',
      );
  String get customAmount => _t('Custom Amount', 'مبلغ مخصص');
  String get bankDetails => _t('Bank Details', 'تفاصيل البنك');
  String get accountHolderName =>
      _t('Account Holder Name', 'اسم صاحب الحساب');
  String get enterName => _t('Enter Name', 'أدخل الاسم');
  String get enterBank => _t('Enter Bank', 'أدخل البنك');
  String get enterIban => _t('Enter IBAN', 'أدخل IBAN');
  String get enterAccountNumberHint =>
      _t('Enter account number', 'أدخل رقم الحساب');
  String get bankName => _t('Bank Name', 'اسم البنك');
  String get accountNumber => _t('Account Number', 'رقم الحساب');
  String get tripFallback => _t('Trip', 'رحلة');
  String get allAmount => _t('All', 'الكل');
  String get availableBalance =>
      _t('Available Balance', 'الرصيد المتاح');
  String get currentBalance => _t('Current Balance', 'الرصيد الحالي');
  String lastUpdatedHoursAgo(int hours) =>
      _t('Last Updated: ${hours}hrs ago', 'آخر تحديث: منذ $hours ساعة');
  String get noCompletedTripsYet =>
      _t('No completed trips yet.', 'لا توجد رحلات مكتملة بعد.');
  String pageOf(int current, int total) =>
      _t('Page $current of $total', 'صفحة $current من $total');
  String get totalEarnings => _t('Total Earnings', 'إجمالي الأرباح');
  String get timeOnline => _t('Time Online', 'وقت الاتصال');
  String get totalRides => _t('Total Rides', 'إجمالي الرحلات');
  String get arrivedAtAddedStop =>
      _t('Arrived at Added Stop', 'وصلت إلى المحطة المضافة');
  String get arrivedAtAddedStopMessage => _t(
        'You have reached the rider\'s added stop. Waze will open to the final destination.',
        'لقد وصلت إلى محطة الراكب المضافة. سيتم فتح Waze إلى الوجهة النهائية.',
      );
  String get gotIt => _t('Got it', 'حسناً');
  String get riderAddedStopTitle =>
      _t('Rider Added a Stop', 'أضاف الراكب محطة');
  String get riderAddedStopMessage => _t(
        'The rider added a stop to this trip. Review the details below before continuing to pickup.',
        'أضاف الراكب محطة لهذه الرحلة. راجع التفاصيل أدناه قبل المتابعة إلى الاستلام.',
      );
  String get driversNeedPush =>
      _t('Drivers need that push too', 'السائقون يحتاجون الدعم أيضاً');
  String get adHeadlineRoomForYou =>
      _t("We've Made Room For You", 'خصّصنا لك مكاناً');
  String get eidDiscountAd =>
      _t('20% Discount on Eid Rides', 'خصم 20% على رحلات العيد');
  String get learnMore => _t('Learn More', 'اعرف المزيد');
  String get signupPerformanceBonusTitle => _t(
        'Sign-Up Performance Cash Bonus',
        'مكافأة نقدية لأداء التسجيل',
      );
  String signupPerformanceBonusSubtitle(int rides, int days) => _t(
        'Complete $rides successful rides within your first $days days',
        'أكمل $rides رحلة ناجحة خلال أول $days أيام',
      );
  String get signupPerformanceBonusRidesLabel =>
      _t('Rides completed', 'الرحلات المكتملة');
  String signupPerformanceBonusRideCount(int completed, int target) => _t(
        '$completed / $target',
        '$completed / $target',
      );
  String signupPerformanceBonusDaysRemaining(int days) {
    if (days <= 0) {
      return _t('Last day to qualify', 'آخر يوم للتأهل');
    }
    if (days == 1) {
      return _t('1 day left', 'يوم واحد متبقٍ');
    }
    return _t('$days days left', '$days أيام متبقية');
  }

  String get signupPerformanceBonusCompletedTitle =>
      _t('Bonus unlocked!', 'تم فتح المكافأة!');
  String signupPerformanceBonusCompletedMessage(String amount) => _t(
        '$amount will be added to your wallet automatically',
        'سيتم إضافة $amount إلى محفظتك تلقائياً',
      );
  String get signupPerformanceBonusPaidTitle =>
      _t('Bonus credited!', 'تم إضافة المكافأة!');
  String signupPerformanceBonusPaidMessage(String amount) => _t(
        '$amount has been added to your wallet',
        'تم إضافة $amount إلى محفظتك',
      );
  String get signupPerformanceBonusExpiredMessage => _t(
        'Your signup bonus window has ended',
        'انتهت فترة مكافأة التسجيل',
      );
  String get signupPerformanceBonusIneligibleMessage => _t(
        'Complete rides during your first 7 days after signup to qualify',
        'أكمل الرحلات خلال أول 7 أيام بعد التسجيل للتأهل',
      );
  String get referDriverTitle =>
      _t('Refer a Driver', 'أحِل سائقاً');
  String get referAFriend =>
      _t('Refer a Friend', 'أحِل صديقاً');
  String get referDriverSubtitle => _t(
        'Refer another driver with your code. When they complete 100 rides in their first month, QAR 100 is added to your balance.',
        'أحِل سائقاً آخر برمزك. عند إكماله 100 رحلة في الشهر الأول، يُضاف 100 ر.ق إلى رصيدك.',
      );
  String get referDriverCopyCode => _t('Copy code', 'نسخ الرمز');
  String get referDriverViewProgress =>
      _t('View Referral Progress', 'عرض تقدم الإحالة');
  String get referDriverProgressTitle =>
      _t('Referral Progress', 'تقدم الإحالة');
  String get referDriverProgressSubtitle => _t(
        'Refer a driver with your code. When they complete 100 rides in their first month, QAR 100 is added to your balance.',
        'أحِل سائقاً برمزك. عند إكماله 100 رحلة في الشهر الأول، يُضاف 100 ر.ق إلى رصيدك.',
      );
  String get referDriverYourCode => _t('Your code', 'رمزك');
  String get referDriverYourProgress => _t('Your progress', 'تقدمك');
  String get referDriverBalanceCredit =>
      _t('Added to your balance', 'يُضاف إلى رصيدك');
  String get referDriverQualifiedReferrals =>
      _t('Qualified drivers', 'السائقون المؤهلون');
  String get referDriverQualifiedReferralsHint => _t(
        'Referred drivers who completed 100 rides in their first month',
        'السائقون المُحالون الذين أكملوا 100 رحلة في الشهر الأول',
      );
  String get referDriverBalanceReceived =>
      _t('Balance received', 'الرصيد المُستلم');
  String get referDriverBalanceReceivedHint => _t(
        'QAR 100 added to your balance per qualified referred driver',
        'يُضاف 100 ر.ق إلى رصيدك عن كل سائق مُحال مؤهل',
      );
  String get referDriverNoBalanceCreditYet => _t(
        'No referral rewards added to your balance yet',
        'لم تُضف مكافآت إحالة إلى رصيدك بعد',
      );
  String get referDriverHowItWorks => _t('How it works', 'كيف يعمل');
  String get referDriverHowItWorksStep1 => _t(
        'You refer another driver with your code',
        'تُحيل سائقاً آخر برمزك',
      );
  String get referDriverHowItWorksStep2 => _t(
        'They sign up as a driver on QGlide using your code',
        'يسجّل كسائق في كيو جلايد باستخدام رمزك',
      );
  String get referDriverHowItWorksStep3 => _t(
        'QAR 100 is added to your balance when they complete 100 rides in their first month',
        'يُضاف 100 ر.ق إلى رصيدك عندما يُكمل 100 رحلة في الشهر الأول',
      );
  String get referDriverBalanceRewardSummary => _t(
        'You receive QAR 100 in your balance for each referred driver who completes 100 rides in their first month.',
        'تحصل على 100 ر.ق في رصيدك عن كل سائق تُحيله يُكمل 100 رحلة في الشهر الأول.',
      );
  String get referDriverProgramRequirement => _t(
        'Each referred driver must complete 100 rides within their first month for you to receive the balance credit',
        'يجب على كل سائق تُحيله إكمال 100 رحلة في الشهر الأول لتحصل على إضافة الرصيد',
      );
  String get referDriverNoReferralsYet => _t(
        'No referred drivers have qualified yet. QAR 100 is added to your balance when a driver you refer completes 100 rides in their first month.',
        'لم يؤهل أي سائق مُحال بعد. يُضاف 100 ر.ق إلى رصيدك عندما يُكمل السائق الذي أحلته 100 رحلة في الشهر الأول.',
      );

  String get referDriverProgressLoadError => _t(
        'Failed to load referral progress. Please try again.',
        'فشل تحميل تقدم الإحالة. يرجى المحاولة مرة أخرى.',
      );
  String get referDriverShare => _t('Share', 'مشاركة');
  String get referDriverCodeCopied =>
      _t('Referral code copied', 'تم نسخ رمز الإحالة');
  String referDriverShareMessage(String code) => _t(
        'Join me as a driver on QGlide! Use my referral code $code when you sign up. I earn QAR 100 in my balance when you complete 100 rides in your first month.',
        'انضم إليّ كسائق على كيو جلايد! استخدم رمز الإحالة $code عند التسجيل. أحصل على 100 ر.ق في رصيدي عند إكمالك 100 رحلة في شهرك الأول.',
      );
  String get errReferDriverUnavailable => _t(
        'Your referral code is not available yet. Please try again shortly.',
        'رمز الإحالة غير متاح بعد. يرجى المحاولة مرة أخرى قريباً.',
      );
  String topUpCheckoutTitle(String amount) =>
      _t('Top Up $amount', 'شحن $amount');
  String get rideDetails => _t('Ride Details', 'تفاصيل الرحلة');
  String get tripDetailsSection =>
      _t('Trip Details', 'تفاصيل الرحلة');
  String get qgliderDetails =>
      _t('Qglider Details', 'تفاصيل الراكب');
  String get statusLabel => _t('Status', 'الحالة');
  String get tripId => _t('Trip ID', 'معرّف الرحلة');
  String get dateLabel => _t('Date', 'التاريخ');
  String get totalAmount => _t('Total Amount', 'المبلغ الإجمالي');
  String get pickupLabel => _t('Pickup:', 'الاستلام:');
  String get dropOff => _t('Drop off', 'التسليم');
  String get distance => _t('Distance', 'المسافة');
  String get duration => _t('Duration', 'المدة');
  String get nameLabel => _t('Name', 'الاسم');
  String get emailLabel => _t('email', 'البريد الإلكتروني');
  String get ratings => _t('Ratings', 'التقييمات');
  String get currencyLabel => _t('QAR', 'ر.ق');
  String get hiddenBalanceFull =>
      isArabic ? '$currencyLabel ••••••' : 'QAR ••••••';
  String get hiddenBalanceShort =>
      isArabic ? '$currencyLabel ••••' : 'QAR ••••';

  String formatQar(double amount, {int decimals = 2}) {
    final isNegative = amount < 0;
    final absolute = amount.abs();
    final whole = absolute.truncate();
    final fraction = ((absolute - whole) * 100).round();

    final wholeText = _localizeDigits(_formatNumberWithCommas(whole));
    final prefix = '${isNegative ? '-' : ''}$currencyLabel ';

    if (decimals == 0) {
      return '$prefix$wholeText';
    }

    final fractionText =
        _localizeDigits(fraction.toString().padLeft(2, '0'));
    final decimalSeparator = isArabic ? '٫' : '.';
    return '$prefix$wholeText$decimalSeparator$fractionText';
  }

  String _localizeDigits(String input) {
    if (!isArabic) return input;

    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return input.replaceAllMapped(
      RegExp(r'[0-9]'),
      (match) => eastern[int.parse(match.group(0)!)],
    );
  }

  String _formatNumberWithCommas(int value) {
    final text = value.toString();
    if (text.length <= 3) return text;

    final separator = isArabic ? '٬' : ',';
    final buffer = StringBuffer();
    final remainder = text.length % 3;
    if (remainder > 0) {
      buffer.write(text.substring(0, remainder));
      if (text.length > remainder) buffer.write(separator);
    }

    for (var i = remainder; i < text.length; i += 3) {
      buffer.write(text.substring(i, i + 3));
      if (i + 3 < text.length) buffer.write(separator);
    }

    return buffer.toString();
  }

  String formatTodayDate() {
    const enMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const arMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final now = DateTime.now();
    final month = isArabic ? arMonths[now.month - 1] : enMonths[now.month - 1];
    return '$month ${now.day} ${now.year}';
  }

  String formatCompletedTripDateTime(DateTime? dateTime) {
    if (dateTime == null) return '--';

    const enMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const arMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];

    final month =
        isArabic ? arMonths[dateTime.month - 1] : enMonths[dateTime.month - 1];
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final hour = dateTime.hour;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;

    if (isArabic) {
      final period = hour >= 12 ? 'م' : 'ص';
      return '$month ${dateTime.day}, $hour12:$minute $period';
    }

    final period = hour >= 12 ? 'PM' : 'AM';
    return '$month ${dateTime.day}, $hour12:$minute$period';
  }

  String formatDistanceKm(double distanceKm) {
    if (distanceKm <= 0) return '--';

    final rounded = (distanceKm * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toStringAsFixed(1);
    return isArabic ? '$text كم' : '${text}km';
  }

  String formatOnlineDuration(int totalSeconds) {
    final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;

    if (isArabic) {
      if (hours > 0 && minutes > 0) {
        return '$hours ${_t('hr', 'س')} $minutes ${_t('mins', 'د')}';
      }
      if (hours > 0) return '$hours ${_t('hr', 'س')}';
      if (minutes > 0) return '$minutes ${_t('mins', 'د')}';
      return '0 ${_t('mins', 'د')}';
    }

    if (hours > 0 && minutes > 0) return '${hours}hr ${minutes}mins';
    if (hours > 0) return '${hours}hr';
    if (minutes > 0) return '${minutes}mins';
    return '0mins';
  }

  String localizeKnownAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return trimmed;

    final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    switch (normalized) {
      case 'current location':
        return currentLocation;
      case 'unknown location':
      case 'unknown':
        return locationUnavailable;
      case 'unnamed road':
        return _t('Unnamed Road', 'طريق بدون اسم');
      case 'destination':
        return destination;
      default:
        return trimmed;
    }
  }

  // ── Vehicle ─────────────────────────────────────────────────────────────────
  String get vehicleInformation =>
      _t('Vehicle Information', 'معلومات المركبة');
  String get make => _t('Make', 'الشركة المصنعة');
  String get model => _t('Model', 'الموديل');
  String get year => _t('Year', 'السنة');
  String get colour => _t('Colour', 'اللون');
  String get licensePlate => _t('License Plate', 'لوحة الترخيص');
  String get invalidYear => _t(
        'Please enter a valid year between 1900 and 2100.',
        'يرجى إدخال سنة صالحة بين 1900 و 2100.',
      );
  String get vehicleUpdated => _t(
        'Vehicle details updated successfully.',
        'تم تحديث بيانات المركبة بنجاح.',
      );

  // ── Notifications ───────────────────────────────────────────────────────────
  String get notifications => _t('Notifications', 'الإشعارات');
  String get markAllRead => _t('Mark all as read', 'تحديد الكل كمقروء');
  String get noNotifications =>
      _t('No notifications yet', 'لا توجد إشعارات بعد');
  String get notificationFallback => _t('Notification', 'إشعار');

  String notificationTypeLabel(String? type) {
    switch (type?.trim().toLowerCase()) {
      case 'ride_update':
        return _t('Ride update', 'تحديث الرحلة');
      case 'promotion':
        return _t('Promotion', 'عرض');
      case 'system':
        return _t('System', 'النظام');
      case 'reward':
        return _t('Reward', 'مكافأة');
      case 'news':
        return _t('News', 'أخبار');
      case 'event':
        return _t('Event', 'فعالية');
      case 'transaction_completed':
        return _t('Transaction completed', 'اكتملت المعاملة');
      case 'ride_completed':
        return _t('Ride completed', 'اكتملت الرحلة');
      case 'new_ride_request':
        return _t('New ride request', 'طلب رحلة جديد');
      default:
        return notificationFallback;
    }
  }

  String localizedNotificationTitle({
    required String rawTitle,
    String? notificationType,
  }) {
    final title = rawTitle.trim();
    final type = notificationType?.trim();

    if (type != null && type.isNotEmpty) {
      if (title.isEmpty ||
          title.toLowerCase() == type.toLowerCase() ||
          title == 'Notification') {
        return notificationTypeLabel(type);
      }
    }

    if (title.isEmpty) {
      return notificationTypeLabel(type);
    }

    return localizeKnownNotificationText(title, isTitle: true);
  }

  String localizedNotificationMessage({
    required String rawMessage,
    String? notificationType,
    Map<String, dynamic>? transaction,
    Map<String, dynamic>? ride,
  }) {
    if (ride != null && ride.isNotEmpty) {
      return _formatRideCompletedNotification(ride);
    }
    if (transaction != null && transaction.isNotEmpty) {
      return _formatTransactionCompletedNotification(transaction);
    }

    return localizeKnownNotificationText(
      rawMessage,
      notificationType: notificationType,
    );
  }

  String localizeKnownNotificationText(
    String text, {
    String? notificationType,
    bool isTitle = false,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;

    final rideFromMessage = _tryParseRideCompletedMessage(trimmed);
    if (rideFromMessage != null) {
      return rideFromMessage;
    }

    final transactionFromMessage = _tryParseTransactionCompletedMessage(trimmed);
    if (transactionFromMessage != null) {
      return transactionFromMessage;
    }

    final earningMessage = _tryParseRideEarningMessage(trimmed);
    if (earningMessage != null) {
      return earningMessage;
    }

    final dropoffChange = _tryParseDropoffChangeMessage(trimmed);
    if (dropoffChange != null) {
      return dropoffChange;
    }

    final newRideRequest = _tryParseNewRideRequestMessage(trimmed, isTitle: isTitle);
    if (newRideRequest != null) {
      return newRideRequest;
    }

    if (notificationType != null && !isTitle) {
      final typeLabel = notificationTypeLabel(notificationType);
      if (trimmed == notificationType || trimmed == typeLabel) {
        return typeLabel;
      }
    }

    return _localizeCurrencyMentions(trimmed);
  }

  String newRideRequestTitle({String? riderName}) {
    final rider = riderName?.trim();
    if (rider != null && rider.isNotEmpty) {
      return _t(
        'New ride request from $rider',
        'طلب رحلة جديد من $rider',
      );
    }
    return _t('New ride request', 'طلب رحلة جديد');
  }

  String newRideRequestWithStopsTitle() =>
      _t('New ride request with stop(s)', 'طلب رحلة جديد مع محطة/محطات');

  String newRideRequestBody({
    required String pickupAddress,
    required String dropoffAddress,
  }) {
    final pickup = localizeKnownAddress(pickupAddress);
    final dropoff = localizeKnownAddress(dropoffAddress);
    return _t(
      'Pickup at $pickup → $dropoff',
      'الاستلام من $pickup ← $dropoff',
    );
  }

  String formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '--';
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) {
      return _t('Just now', 'الآن');
    }
    if (diff.inMinutes < 60) {
      final m = _localizeDigits('${diff.inMinutes}');
      return _t('$m minutes ago', 'منذ $m دقيقة');
    }
    if (diff.inHours < 24) {
      final h = _localizeDigits('${diff.inHours}');
      return _t('$h hours ago', 'منذ $h ساعة');
    }
    if (diff.inDays < 7) {
      final d = _localizeDigits('${diff.inDays}');
      return _t('$d days ago', 'منذ $d يوم');
    }

    return _localizeDigits(formatCompletedTripDateTime(dateTime));
  }

  String _formatRideCompletedNotification(Map<String, dynamic> ride) {
    final fareValue = _readNotificationDouble(
      ride['fare'] ?? ride['actual_fare'] ?? ride['estimated_fare'],
    );
    final fare = formatQar(fareValue, decimals: 2);
    final pickup =
        localizeKnownAddress(ride['pickup_address']?.toString() ?? '');
    final dropoff =
        localizeKnownAddress(ride['dropoff_address']?.toString() ?? '');

    if (pickup.isNotEmpty && dropoff.isNotEmpty) {
      return _t(
        'Ride completed: $pickup -> $dropoff ($fare)',
        'اكتملت الرحلة: $pickup ← $dropoff ($fare)',
      );
    }

    return _t(
      'Ride completed: your recent trip ($fare)',
      'اكتملت الرحلة: رحلتك الأخيرة ($fare)',
    );
  }

  String _formatTransactionCompletedNotification(
    Map<String, dynamic> transaction,
  ) {
    final amount = formatQar(
      _readNotificationDouble(transaction['amount']),
      decimals: 2,
    );
    final description = transaction['description']?.toString().trim() ?? '';
    final type = transaction['type']?.toString().trim() ?? '';

    final earningMessage = _tryParseRideEarningDescription(description);
    if (earningMessage != null) {
      return earningMessage;
    }

    if (description.isNotEmpty) {
      return _t(
        'Transaction completed: $description ($amount)',
        'اكتملت المعاملة: $description ($amount)',
      );
    }

    final typeLabel = _transactionTypeLabel(type);
    return _t(
      'Transaction completed: $typeLabel ($amount)',
      'اكتملت المعاملة: $typeLabel ($amount)',
    );
  }

  String? _tryParseRideCompletedMessage(String text) {
    final match = RegExp(
      r'^Ride completed: (.+) \((?:QAR|ر\.ق)\s+([\d٬٫,\.]+)\)$',
    ).firstMatch(text);
    if (match == null) return null;

    final route = match.group(1)!.trim();
    final amount = _parseLocalizedNumber(match.group(2)!);
    if (route == 'your recent trip') {
      return _formatRideCompletedNotification({'fare': amount});
    }

    final parts = route.split(' -> ');
    if (parts.length == 2) {
      return _formatRideCompletedNotification({
        'pickup_address': parts[0].trim(),
        'dropoff_address': parts[1].trim(),
        'fare': amount,
      });
    }

    return _formatRideCompletedNotification({
      'fare': amount,
      'dropoff_address': route,
    });
  }

  String? _tryParseTransactionCompletedMessage(String text) {
    final match = RegExp(
      r'^Transaction completed: (.+) \((?:QAR|ر\.ق)\s+([\d٬٫,\.]+)\)$',
    ).firstMatch(text);
    if (match == null) return null;

    return _formatTransactionCompletedNotification({
      'description': match.group(1)!.trim(),
      'amount': _parseLocalizedNumber(match.group(2)!),
      'type': '',
    });
  }

  String? _tryParseRideEarningMessage(String text) {
    final match = RegExp(
      r'^Ride earning credited \(gross ([\d.]+), commission ([\d.]+)\)$',
    ).firstMatch(text);
    if (match == null) return null;

    return _formatRideEarningMessage(
      gross: double.tryParse(match.group(1)!) ?? 0,
      commission: double.tryParse(match.group(2)!) ?? 0,
    );
  }

  String? _tryParseRideEarningDescription(String description) {
    final match = RegExp(
      r'^Ride earning credited \(gross ([\d.]+), commission ([\d.]+)\)$',
    ).firstMatch(description);
    if (match == null) return null;

    return _formatRideEarningMessage(
      gross: double.tryParse(match.group(1)!) ?? 0,
      commission: double.tryParse(match.group(2)!) ?? 0,
    );
  }

  String _formatRideEarningMessage({
    required double gross,
    required double commission,
  }) {
    final grossText = formatQar(gross, decimals: 2);
    final commissionText = formatQar(commission, decimals: 2);
    return _t(
      'Ride earning credited (gross $grossText, commission $commissionText)',
      'تم إضافة أرباح الرحلة (إجمالي $grossText، عمولة $commissionText)',
    );
  }

  String? _tryParseDropoffChangeMessage(String text) {
    final match = RegExp(
      r'^The rider just added a stop\. New dropoff: (.+?)(?:\.|\$)(.*)$',
    ).firstMatch(text);
    if (match == null) return null;

    final dropoff = localizeKnownAddress(match.group(1)!.trim());
    final suffix = match.group(2)?.trim() ?? '';
    final fareMatch =
        RegExp(r'Updated fare: (?:QAR|ر\.ق)\s+([\d٬٫,\.]+)').firstMatch(suffix);
    if (fareMatch != null) {
      final fare = formatQar(
        _parseLocalizedNumber(fareMatch.group(1)!),
        decimals: 2,
      );
      return _t(
        'The rider just added a stop. New dropoff: $dropoff. Updated fare: $fare',
        'أضاف الراكب محطة. الوجهة الجديدة: $dropoff. الأجرة المحدّثة: $fare',
      );
    }

    return _t(
      'The rider just added a stop. New dropoff: $dropoff.',
      'أضاف الراكب محطة. الوجهة الجديدة: $dropoff.',
    );
  }

  String? _tryParseNewRideRequestMessage(String text, {required bool isTitle}) {
    if (isTitle) {
      if (text == 'New ride request with stop(s)') {
        return newRideRequestWithStopsTitle();
      }
      final fromRider = RegExp(r'^New ride request from (.+)$').firstMatch(text);
      if (fromRider != null) {
        return newRideRequestTitle(riderName: fromRider.group(1));
      }
      if (text == 'New ride request') {
        return newRideRequestTitle();
      }
      return null;
    }

    final pickupMatch =
        RegExp(r'^Pickup at (.+) → (.+)$').firstMatch(text);
    if (pickupMatch != null) {
      return newRideRequestBody(
        pickupAddress: pickupMatch.group(1)!,
        dropoffAddress: pickupMatch.group(2)!,
      );
    }

    return null;
  }

  String _transactionTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'driver_earning':
        return _t('Driver earning', 'أرباح السائق');
      case 'top_up':
        return topUp;
      case 'fare':
        return _t('Fare', 'الأجرة');
      case 'withdrawal':
        return withdrawal;
      default:
        if (type.isEmpty) return _t('Transaction', 'معاملة');
        return type.replaceAll('_', ' ');
    }
  }

  String _localizeCurrencyMentions(String text) {
    var result = text.replaceAllMapped(
      RegExp(r'QAR\s+([\d,]+\.?\d*)'),
      (match) {
        final raw = match.group(1)!;
        final value = double.tryParse(raw.replaceAll(',', '')) ?? 0;
        final decimals = raw.contains('.') ? 2 : 0;
        return formatQar(value, decimals: decimals);
      },
    );

    if (isArabic) {
      result = _localizeDigits(result);
    }

    return result;
  }

  double _readNotificationDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
  }

  double _parseLocalizedNumber(String value) {
    const eastern = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    final normalized = value
        .replaceAll('٬', '')
        .replaceAll(',', '')
        .replaceAll('٫', '.')
        .split('')
        .map((char) => eastern[char] ?? char)
        .join();

    return double.tryParse(normalized) ?? 0;
  }

  // ── Profile details ─────────────────────────────────────────────────────────
  String get profile => _t('Profile', 'الملف الشخصي');
  String get ridersCanSeeFaceDuringPickup => _t(
        'Riders can see your face during pickup',
        'يمكن للركاب رؤية وجهك أثناء الاستلام',
      );
  String get personDetails => _t('Person Details', 'البيانات الشخصية');
  String get accountDetails => _t('Account Details', 'بيانات الحساب');
  String get email => _t('Email', 'البريد الإلكتروني');
  String get phone => _t('Phone', 'الهاتف');
  String get dob => _t('DOB', 'تاريخ الميلاد');
  String get driversId => _t('Drivers ID', 'معرّف السائق');
  String get memberSinceLabel => _t('Member Since', 'عضو منذ');
  String get updateProfilePhoto =>
      _t('Update profile photo', 'تحديث صورة الملف الشخصي');
  String get takePhoto => _t('Take photo', 'التقاط صورة');
  String get chooseFromGallery =>
      _t('Choose from gallery', 'اختيار من المعرض');
  String get errPhotoPickerNotReady => _t(
        'Photo picker is not ready. Stop the app completely (press q in the terminal), then run flutter run again. Hot reload cannot load new native plugins.',
        'منتقي الصور غير جاهز. أغلق التطبيق تماماً (اضغط q في الطرفية)، ثم شغّل flutter run مجدداً. إعادة التحميل السريع لا تحمّل الإضافات الأصلية الجديدة.',
      );
  String errPickImage(String error) =>
      _t('Failed to pick image: $error', 'فشل اختيار الصورة: $error');
  String get profilePhotoUpdated =>
      _t('Profile photo updated.', 'تم تحديث صورة الملف الشخصي.');
  String get profileUpdatedSuccessfully =>
      _t('Profile updated successfully.', 'تم تحديث الملف الشخصي بنجاح.');

  // ── Help center ─────────────────────────────────────────────────────────────
  String get frequentlyAskedQuestions =>
      _t('Frequently Asked Questions', 'الأسئلة الشائعة');
  String get stillNeedHelp => _t('Still Need Help?', 'ما زلت بحاجة إلى مساعدة؟');
  String get callSupport => _t('Call Support', 'اتصل بالدعم');
  String get callSupportSubtitle =>
      _t('Speak Directly with Our team', 'تحدث مباشرة مع فريقنا');
  String dialSupportPhone(String phoneNumber) {
    final display = isArabic ? _localizeDigits(phoneNumber) : phoneNumber;
    return _t('Dial $display', 'اتصل $display');
  }

  String get callSupportModalMessage => _t(
        'Call us now and we\'ll help resolve your issue.',
        'اتصل بنا الآن وسنساعدك في حل مشكلتك.',
      );
  String get dialNow => _t('Dial now', 'اتصل الآن');
  String get submitTicketAction =>
      _t('Submit a ticket', 'إرسال تذكرة');
  String get submitTicketSubtitle =>
      _t('We would get back via email', 'سنعود إليك عبر البريد الإلكتروني');

  String faqQuestion(int index) {
    switch (index) {
      case 0:
        return _t('How are my earnings calculated?', 'كيف تُحسب أرباحي؟');
      case 1:
        return _t('When can I withdraw my earnings?', 'متى يمكنني سحب أرباحي؟');
      case 2:
        return _t('What if a rider cancels a trip?', 'ماذا لو ألغى الراكب الرحلة؟');
      case 3:
        return _t('How do I update my vehicle documents?', 'كيف أحدّث مستندات مركبتي؟');
      case 4:
        return _t(
          'How do I go online and start receiving ride requests?',
          'كيف أتصل بالإنترنت وأبدأ استقبال طلبات الرحلات؟',
        );
      case 5:
        return _t(
          'What should I do if I have an issue during a ride?',
          'ماذا أفعل إذا واجهت مشكلة أثناء الرحلة؟',
        );
      case 6:
        return _t(
          'How do I complete a ride and receive payment?',
          'كيف أكمل الرحلة وأستلم الدفع؟',
        );
      case 7:
        return _t(
          'How do I update my personal information?',
          'كيف أحدّث معلوماتي الشخصية؟',
        );
      default:
        return '';
    }
  }

  String faqAnswer(int index) {
    switch (index) {
      case 0:
        return _t(
          'Your earnings are calculated based on several factors:\n\n'
          '• Base fare: A fixed amount for each ride\n'
          '• Distance: Charged per kilometer traveled\n'
          '• Time: Charged for time spent during the ride\n'
          '• Ride type: Different rates apply for Q-Standard, Q-Comfort, Q-XL, and Q-Eco\n'
          '• Surge pricing: Higher rates during peak demand periods\n'
          '• Bonuses: Special promotions and incentives\n\n'
          'You can view your earnings breakdown in the Earnings section of the app.',
          'تُحسب أرباحك بناءً على عدة عوامل:\n\n'
          '• الأجرة الأساسية: مبلغ ثابت لكل رحلة\n'
          '• المسافة: تُحسب لكل كيلومتر\n'
          '• الوقت: يُحسب لمدة الرحلة\n'
          '• نوع الرحلة: أسعار مختلفة لـ Q-Standard و Q-Comfort و Q-XL و Q-Eco\n'
          '• التسعير الديناميكي: أسعار أعلى في أوقات الذروة\n'
          '• المكافآت: عروض وحوافز خاصة\n\n'
          'يمكنك عرض تفاصيل أرباحك في قسم الأرباح بالتطبيق.',
        );
      case 1:
        return _t(
          'You can withdraw your earnings at any time through the Balance section:\n\n'
          '• Go to Profile > Balance\n'
          '• Tap "Withdraw" button\n'
          '• Enter the amount you want to withdraw\n'
          '• Confirm your withdrawal request\n\n'
          'Withdrawals are typically processed within 1-3 business days. Make sure your withdrawal amount doesn\'t exceed your available balance. You can also top up your account balance if needed.',
          'يمكنك سحب أرباحك في أي وقت عبر قسم الرصيد:\n\n'
          '• اذهب إلى الملف الشخصي > الرصيد\n'
          '• اضغط زر "سحب"\n'
          '• أدخل المبلغ المراد سحبه\n'
          '• أكّد طلب السحب\n\n'
          'تُعالَج عمليات السحب عادةً خلال 1–3 أيام عمل. تأكد أن مبلغ السحب لا يتجاوز رصيدك المتاح. يمكنك أيضاً شحن رصيد حسابك عند الحاجة.',
        );
      case 2:
        return _t(
          'Cancellation policies depend on when the rider cancels:\n\n'
          '• Before you accept: No fee, ride is simply cancelled\n'
          '• After you accept but before arrival: You may receive a small cancellation fee\n'
          '• After you arrive at pickup: You\'ll receive a cancellation fee to compensate for your time and travel\n'
          '• If you cancel: Cancellation fees may apply depending on the reason\n\n'
          'All cancellation fees are automatically added to your earnings balance.',
          'تعتمد سياسة الإلغاء على توقيت إلغاء الراكب:\n\n'
          '• قبل قبولك: لا رسوم، تُلغى الرحلة فقط\n'
          '• بعد القبول وقبل الوصول: قد تحصل على رسوم إلغاء بسيطة\n'
          '• بعد وصولك لموقع الاستلام: تحصل على رسوم إلغاء لتعويض وقتك وتنقلك\n'
          '• إذا ألغيت أنت: قد تُطبَّق رسوم حسب السبب\n\n'
          'تُضاف جميع رسوم الإلغاء تلقائياً إلى رصيد أرباحك.',
        );
      case 3:
        return _t(
          'To update your vehicle documents:\n\n'
          '1. Go to Profile > Manage Vehicle\n'
          '2. Select the vehicle you want to update\n'
          '3. Tap on the document or information you need to change\n'
          '4. Upload new photos or update information\n'
          '5. Submit for verification\n\n'
          'Your documents will be reviewed by our team. You\'ll receive a notification once the verification is complete. Make sure all documents are clear, valid, and up-to-date.',
          'لتحديث مستندات مركبتك:\n\n'
          '1. اذهب إلى الملف الشخصي > إدارة المركبة\n'
          '2. اختر المركبة المراد تحديثها\n'
          '3. اضغط على المستند أو المعلومة المراد تغييرها\n'
          '4. ارفع صوراً جديدة أو حدّث المعلومات\n'
          '5. أرسل للتحقق\n\n'
          'ستراجع فريقنا مستنداتك. ستتلقى إشعاراً عند اكتمال التحقق. تأكد أن جميع المستندات واضحة وسارية ومحدّثة.',
        );
      case 4:
        return _t(
          'To go online and start receiving rides:\n\n'
          '1. Open the app and ensure you\'re logged in\n'
          '2. Tap the "Go Online" button on the home screen\n'
          '3. Make sure your location services are enabled\n'
          '4. Wait for ride requests to come in\n\n'
          'When you\'re online, riders in your area can see you on the map and request rides. You\'ll receive notifications for new ride requests. Tap "Accept" to pick up the rider or "Reject" to decline.',
          'للاتصال وبدء استقبال الرحلات:\n\n'
          '1. افتح التطبيق وتأكد من تسجيل الدخول\n'
          '2. اضغط زر "الاتصال" في الشاشة الرئيسية\n'
          '3. تأكد من تفعيل خدمات الموقع\n'
          '4. انتظر طلبات الرحلات\n\n'
          'عند الاتصال، يراك الركاب في منطقتك على الخريطة ويطلبون الرحلات. ستتلقى إشعارات بطلبات جديدة. اضغط "قبول" لاستلام الراكب أو "رفض" للاعتذار.',
        );
      case 5:
        return _t(
          'If you encounter any issues during a ride:\n\n'
          '• Safety concerns: Contact emergency services immediately (999)\n'
          '• Technical issues: Use the in-app support chat for immediate assistance\n'
          '• Payment problems: Contact support through the app or submit a ticket\n'
          '• Navigation issues: Use the in-app map, or tap Open in Waze for turn-by-turn in Waze\n'
          '• Rider issues: Complete the ride safely and report the issue through support\n\n'
          'For urgent matters, you can submit a support ticket for assistance.',
          'إذا واجهت أي مشكلة أثناء الرحلة:\n\n'
          '• مخاوف أمنية: اتصل بخدمات الطوارئ فوراً (999)\n'
          '• مشاكل تقنية: استخدم محادثة الدعم داخل التطبيق\n'
          '• مشاكل الدفع: تواصل مع الدعم عبر التطبيق أو أرسل تذكرة\n'
          '• مشاكل الملاحة: استخدم الخريطة داخل التطبيق، أو افتح Waze للتوجيه\n'
          '• مشاكل مع الراكب: أكمل الرحلة بأمان وأبلغ عبر الدعم\n\n'
          'للحالات العاجلة، يمكنك إرسال تذكرة دعم للمساعدة.',
        );
      case 6:
        return _t(
          'To complete a ride:\n\n'
          '1. Once you arrive at the destination, tap "Complete Trip"\n'
          '2. The app will calculate the final fare based on actual distance and time\n'
          '3. The rider will be prompted to rate and pay\n'
          '4. Payment is automatically processed and added to your earnings\n'
          '5. You\'ll see the amount added to your balance immediately\n\n'
          'All payments are secure and handled through the app. You can track all completed rides and earnings in your Earnings section.',
          'لإكمال الرحلة:\n\n'
          '1. عند الوصول للوجهة، اضغط "إكمال الرحلة"\n'
          '2. يحسب التطبيق الأجرة النهائية حسب المسافة والوقت الفعلي\n'
          '3. يُطلب من الراكب التقييم والدفع\n'
          '4. تُعالَج الدفعة تلقائياً وتُضاف لأرباحك\n'
          '5. سترى المبلغ مضافاً لرصيدك فوراً\n\n'
          'جميع المدفوعات آمنة وتتم عبر التطبيق. يمكنك تتبع الرحلات المكتملة والأرباح في قسم الأرباح.',
        );
      case 7:
        return _t(
          'To update your personal information:\n\n'
          '1. Go to Profile > Personal Information\n'
          '2. Tap on the field you want to update (name, phone, email, etc.)\n'
          '3. Make your changes\n'
          '4. Save the updates\n\n'
          'Some information like email may require verification. Make sure all information is accurate as it\'s used for account security and communication.',
          'لتحديث معلوماتك الشخصية:\n\n'
          '1. اذهب إلى الملف الشخصي > المعلومات الشخصية\n'
          '2. اضغط على الحقل المراد تحديثه (الاسم، الهاتف، البريد، إلخ)\n'
          '3. أجرِ التغييرات\n'
          '4. احفظ التحديثات\n\n'
          'قد يتطلب بعض المعلومات مثل البريد التحقق. تأكد من دقة جميع المعلومات لأنها تُستخدم للأمان والتواصل.',
        );
      default:
        return '';
    }
  }

  static const faqCount = 8;

  // ── Support tickets ─────────────────────────────────────────────────────────
  String get submittedTickets => _t('Submitted Tickets', 'التذاكر المُرسلة');
  String get addSupportTicket => _t('Add Support Ticket', 'إضافة تذكرة دعم');
  String get supportTicketDetail =>
      _t('Support Ticket', 'تذكرة الدعم');
  String get addSupportTicketSubtitle => _t(
        'Describe your issue and our team will get back to you.',
        'صف مشكلتك وسيعود إليك فريقنا.',
      );
  String get category => _t('Category', 'الفئة');
  String get subject => _t('Subject', 'الموضوع');
  String get enterTicketSubject =>
      _t('Enter ticket subject', 'أدخل موضوع التذكرة');
  String get description => _t('Description', 'الوصف');
  String get describeYourIssue =>
      _t('Describe your issue', 'صف مشكلتك');
  String get attachmentsOptional =>
      _t('Attachments (optional)', 'المرفقات (اختياري)');
  String get addAttachment => _t('Add attachment', 'إضافة مرفق');
  String get uploadingAttachment =>
      _t('Uploading attachment...', 'جاري رفع المرفق...');
  String get submitTicketButton =>
      _t('Submit Ticket', 'إرسال التذكرة');
  String get fillSubjectAndDescription => _t(
        'Please fill in the subject and description.',
        'يرجى ملء الموضوع والوصف.',
      );
  String get errFilePickerNotReady => _t(
        'File picker is not ready. Restart the app and try again.',
        'منتقي الملفات غير جاهز. أعد تشغيل التطبيق وحاول مجدداً.',
      );
  String errPickFile(String error) =>
      _t('Could not pick file: $error', 'تعذر اختيار الملف: $error');
  String get errUploadNoUrl => _t(
        'Upload succeeded but no file URL was returned.',
        'نجح الرفع لكن لم يُرجَع رابط الملف.',
      );
  String errSubmitTicket(String error) =>
      _t('Could not submit ticket: $error', 'تعذر إرسال التذكرة: $error');
  String get tryAgain => _t('Try again', 'حاول مجدداً');
  String get errReadTickets => _t(
        'Could not read support tickets.',
        'تعذر قراءة تذاكر الدعم.',
      );
  String get noSupportTicketsYet =>
      _t('No support tickets yet.', 'لا توجد تذاكر دعم بعد.');
  String get filterAll => _t('All', 'الكل');
  String get filterOpen => _t('Open', 'مفتوحة');
  String get filterPending => _t('Pending', 'قيد الانتظار');
  String get filterResolved => _t('Resolved', 'محلولة');
  String get ticketStatusUnknown => _t('Unknown', 'غير معروف');
  String get errReadConversation => _t(
        'Could not read conversation.',
        'تعذر قراءة المحادثة.',
      );
  String get noMessagesYetStartConversation => _t(
        'No messages yet. Send a reply to start the conversation.',
        'لا توجد رسائل بعد. أرسل رداً لبدء المحادثة.',
      );
  String get enterText => _t('Enter Text', 'أدخل النص');
  String get repliesAreClosed =>
      _t('Replies are closed', 'الردود مغلقة');

  String supportCategoryLabel(String key) {
    switch (key) {
      case 'earnings':
        return _t('Earnings', 'الأرباح');
      case 'withdrawal':
        return _t('Withdrawal', 'السحب');
      case 'payments':
        return _t('Payments', 'المدفوعات');
      case 'documents':
        return _t('Documents', 'المستندات');
      case 'vehicle':
        return _t('Vehicle', 'المركبة');
      case 'technical':
        return _t('Technical', 'تقني');
      case 'ratings':
        return _t('Ratings', 'التقييمات');
      case 'ride_issues':
        return _t('Ride issues', 'مشاكل الرحلة');
      case 'others':
        return _t('Others', 'أخرى');
      default:
        return key;
    }
  }

  String? ticketFilterLabel(String? status) {
    switch (status) {
      case null:
        return filterAll;
      case 'open':
        return filterOpen;
      case 'pending':
        return filterPending;
      case 'resolved':
        return filterResolved;
      default:
        return status;
    }
  }

  String ticketStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return filterOpen;
      case 'pending':
        return filterPending;
      case 'resolved':
        return filterResolved;
      default:
        return ticketStatusUnknown;
    }
  }

  String get supportTicketSubjectFallback =>
      _t('Support ticket', 'تذكرة دعم');

  String formatSupportTicketDateTime(DateTime? dateTime) {
    if (dateTime == null) return '--';

    const enMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const arMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];

    final month =
        isArabic ? arMonths[dateTime.month - 1] : enMonths[dateTime.month - 1];
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final hour = dateTime.hour;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final year = _localizeDigits('${dateTime.year}');
    final day = _localizeDigits('${dateTime.day}');

    if (isArabic) {
      final period = hour >= 12 ? 'م' : 'ص';
      final time = _localizeDigits('$hour12:$minute $period');
      return '$month $day، $year • $time';
    }

    final period = hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $year • $hour12:$minute $period';
  }

  String formatTicketDisplayId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return '--';

    final normalized = trimmed.toUpperCase().startsWith('TKT')
        ? trimmed.toUpperCase()
        : 'TKT-$trimmed';

    return isArabic ? _localizeDigits(normalized) : normalized;
  }

  // ── Ride chat / call ────────────────────────────────────────────────────────
  String get noMessagesSayHello => _t(
        'No messages yet. Say hello to your rider.',
        'لا توجد رسائل بعد. قل مرحباً لراكبك.',
      );
  String get typeAMessage => _t('Type a message', 'اكتب رسالة');
  String get messagingUnavailable =>
      _t('Messaging unavailable', 'المراسلة غير متاحة');
  String get incomingCall => _t('Incoming call', 'مكالمة واردة');
  String get incomingCallEllipsis =>
      _t('Incoming call...', 'مكالمة واردة...');
  String get connecting => _t('Connecting...', 'جاري الاتصال...');
  String get inAppCallNotSupportedOnWeb => _t(
        'In-app voice call is not supported on web. Use iOS or Android.',
        'المكالمة الصوتية داخل التطبيق غير مدعومة على الويب. استخدم iOS أو Android.',
      );
  String get microphonePermissionRequired => _t(
        'Microphone permission is required for the call.',
        'إذن الميكروفون مطلوب للمكالمة.',
      );
  String couldNotJoinCall(int code) => _t(
        'Could not join call (code $code).',
        'تعذر الانضمام للمكالمة (رمز $code).',
      );
  String get callFailedTryAgain =>
      _t('Call failed. Please try again.', 'فشلت المكالمة. يرجى المحاولة مرة أخرى.');
  String calling(String name) =>
      _t('Calling $name', 'جاري الاتصال بـ $name');
  String onCallWith(String name) =>
      _t('On call with $name', 'في مكالمة مع $name');
  String get openSettings => _t('Open Settings', 'فتح الإعدادات');
  String get decline => _t('Decline', 'رفض');
  String get accept => _t('Accept', 'قبول');
  String get speaker => _t('Speaker', 'مكبر الصوت');
  String get mute => _t('Mute', 'كتم');
  String get endCall => _t('End', 'إنهاء');

  // ── API / error fallbacks ───────────────────────────────────────────────────
  String get errLogoutLocal => _t(
        'Logged out locally, but server logout failed.',
        'تم تسجيل الخروج محلياً، لكن فشل تسجيل الخروج من الخادم.',
      );
  String get errAccountDeleted => _t(
        'Account deleted successfully.',
        'تم حذف الحساب بنجاح.',
      );
  String get errDeleteAccount => _t(
        'Failed to delete account. Please try again.',
        'فشل حذف الحساب. يرجى المحاولة مرة أخرى.',
      );
  String get errLoadVehicle => _t(
        'Failed to load vehicle details. Please try again.',
        'فشل تحميل بيانات المركبة. يرجى المحاولة مرة أخرى.',
      );
  String get errUpdateVehicle => _t(
        'Failed to update vehicle details. Please try again.',
        'فشل تحديث بيانات المركبة. يرجى المحاولة مرة أخرى.',
      );
  String get errSignUp => _t(
        'Sign up failed. Please try again.',
        'فشل التسجيل. يرجى المحاولة مرة أخرى.',
      );
  String get errCreateAccount => _t(
        'Could not create your account. Please try again.',
        'تعذر إنشاء حسابك. يرجى المحاولة مرة أخرى.',
      );
  String get errGoogleSignIn =>
      _t('Google sign-in failed.', 'فشل تسجيل الدخول عبر Google.');
  String get errAppleSignIn =>
      _t('Apple sign-in failed.', 'فشل تسجيل الدخول عبر Apple.');
  String get errOnlineStatus => _t(
        'Could not update online status. Please try again.',
        'تعذر تحديث حالة الاتصال. يرجى المحاولة مرة أخرى.',
      );
  String get errWithdrawal => _t(
        'Could not submit withdrawal request. Please try again.',
        'تعذر إرسال طلب السحب. يرجى المحاولة مرة أخرى.',
      );
  String get errCancelRide => _t(
        'Could not cancel ride. Please try again.',
        'تعذر إلغاء الرحلة. يرجى المحاولة مرة أخرى.',
      );
  String get errAcceptRide => _t(
        'Could not accept ride. Please try again.',
        'تعذر قبول الرحلة. يرجى المحاولة مرة أخرى.',
      );
  String get errConfirmPickup => _t(
        'Could not confirm pickup. Please try again.',
        'تعذر تأكيد الاستلام. يرجى المحاولة مرة أخرى.',
      );
  String get errStartRide => _t(
        'Could not start ride. Please try again.',
        'تعذر بدء الرحلة. يرجى المحاولة مرة أخرى.',
      );
  String get errCompleteTrip => _t(
        'Could not complete trip. Please try again.',
        'تعذر إكمال الرحلة. يرجى المحاولة مرة أخرى.',
      );
  String get errLoadChat => _t(
        'Could not load chat messages.',
        'تعذر تحميل رسائل المحادثة.',
      );
  String get errSendMessage => _t(
        'Could not send message.',
        'تعذر إرسال الرسالة.',
      );
  String get errStartCall =>
      _t('Could not start call.', 'تعذر بدء المكالمة.');
  String get errSendCode => _t(
        'Could not send verification code.',
        'تعذر إرسال رمز التحقق.',
      );
  String get errSendCodeRetry => _t(
        'Could not send verification code. Please try again.',
        'تعذر إرسال رمز التحقق. يرجى المحاولة مرة أخرى.',
      );
  String get errEnterEmail => _t(
        'Please enter your email address.',
        'يرجى إدخال بريدك الإلكتروني.',
      );
  String get errValidEmail => _t(
        'Please enter a valid email address.',
        'يرجى إدخال بريد إلكتروني صالح.',
      );
  String get errCodeAlreadySending => _t(
        'Verification code is already being sent.',
        'جاري إرسال رمز التحقق بالفعل.',
      );
  String get errInvalidPhoneSignup => _t(
        'Invalid phone number. Go back and check your signup details.',
        'رقم هاتف غير صالح. ارجع وتحقق من بيانات التسجيل.',
      );
  String get errVerificationInProgress => _t(
        'Verification already in progress.',
        'التحقق قيد التنفيذ بالفعل.',
      );
  String get errWaitAutoVerify => _t(
        'Please wait, verifying your number automatically.',
        'يرجى الانتظار، جاري التحقق من رقمك تلقائياً.',
      );
  String get errWaitingForNewCode => _t(
        'Waiting for a new verification code. Tap Resend Code if this takes too long.',
        'في انتظار رمز تحقق جديد. اضغط إعادة إرسال الرمز إذا استغرق ذلك وقتاً طويلاً.',
      );
  String get errWaitBeforeResend => _t(
        'Please wait before requesting a new code.',
        'يرجى الانتظار قبل طلب رمز جديد.',
      );
  String get errFileEmpty =>
      _t('Selected file is empty.', 'الملف المحدد فارغ.');
  String get errFileSize =>
      _t('File must be less than 10MB.', 'يجب أن يكون حجم الملف أقل من 10 ميجابايت.');
  String get errPhotoPicker => _t(
        'Photo picker is not ready. Stop the app and run flutter run again.',
        'أداة اختيار الصور غير جاهزة. أوقف التطبيق وشغّله مرة أخرى باستخدام flutter run.',
      );
  String errUploadDocumentFailed(Object error) => _t(
        'Failed to upload document: $error',
        'فشل رفع المستند: $error',
      );
  String get errVerification => _t(
        'Verification failed. Please try again.',
        'فشل التحقق. يرجى المحاولة مرة أخرى.',
      );
  String get errAutoVerification => _t(
        'Automatic verification failed. Please try again.',
        'فشل التحقق التلقائي. يرجى المحاولة مرة أخرى.',
      );
  String get errInvalidCode =>
      _t('Invalid verification code.', 'رمز التحقق غير صالح.');
  String get errLoadNotifications => _t(
        'Could not load notifications.',
        'تعذر تحميل الإشعارات.',
      );
  String get errMarkNotificationsRead => _t(
        'Could not mark notifications as read.',
        'تعذر تحديد الإشعارات كمقروءة.',
      );
  String get errLoadProfile => _t(
        'Failed to load profile. Please try again.',
        'فشل تحميل الملف الشخصي. يرجى المحاولة مرة أخرى.',
      );
  String get errUploadPhoto => _t(
        'Failed to upload profile photo.',
        'فشل رفع صورة الملف الشخصي.',
      );
  String get errUpdateProfile => _t(
        'Failed to update profile. Please try again.',
        'فشل تحديث الملف الشخصي. يرجى المحاولة مرة أخرى.',
      );
  String errUploadDocument(String docType) => _t(
        'Failed to upload ${documentLabel(docType)}.',
        'فشل رفع ${documentLabel(docType)}.',
      );
  String errDeleteDocument(String docType) => _t(
        'Failed to delete ${documentLabel(docType)}.',
        'فشل حذف ${documentLabel(docType)}.',
      );
  String get errUploadAttachment => _t(
        'Could not upload attachment.',
        'تعذر رفع المرفق.',
      );
  String get errCreateTicket => _t(
        'Could not create support ticket.',
        'تعذر إنشاء تذكرة الدعم.',
      );
  String get errLoadTickets => _t(
        'Could not load support tickets.',
        'تعذر تحميل تذاكر الدعم.',
      );
  String get errLoadConversation => _t(
        'Could not load conversation.',
        'تعذر تحميل المحادثة.',
      );
  String get errSendReply => _t(
        'Could not send reply.',
        'تعذر إرسال الرد.',
      );
  String get errPasswordResetSent => _t(
        'Password reset email sent. Check your inbox.',
        'تم إرسال بريد إعادة تعيين كلمة المرور. تحقق من صندوق الوارد.',
      );
  String get errPasswordResetFailed => _t(
        'Failed to send reset link. Please try again.',
        'فشل إرسال رابط إعادة التعيين. يرجى المحاولة مرة أخرى.',
      );
  String get errVerifyPayment => _t(
        'Could not verify payment status.',
        'تعذر التحقق من حالة الدفع.',
      );
  String get errLoadRideDetails => _t(
        'Could not load ride details.',
        'تعذر تحميل تفاصيل الرحلة.',
      );
  String get errValidAmount => _t('Enter a valid amount.', 'أدخل مبلغاً صالحاً.');
  String get errTopUpProfileRequired => _t(
        'Add your email and phone in Personal Information before topping up.',
        'أضف بريدك الإلكتروني ورقم هاتفك في المعلومات الشخصية قبل الشحن.',
      );
  String get errValidWithdrawalAmount =>
      _t('Enter a valid withdrawal amount.', 'أدخل مبلغ سحب صالح.');
  String errAmountExceedsBalance(String balance) => _t(
        'Amount exceeds your available balance of QAR $balance.',
        'المبلغ يتجاوز رصيدك المتاح QAR $balance.',
      );
  String get errAccountHolderName =>
      _t('Enter the account holder name.', 'أدخل اسم صاحب الحساب.');
  String get errBankName => _t('Enter the bank name.', 'أدخل اسم البنك.');
  String get errIban => _t('Enter your IBAN.', 'أدخل رقم IBAN.');
  String get errAccountNumber =>
      _t('Enter your account number.', 'أدخل رقم حسابك.');
  String get errLoadBalance => _t(
        'Could not load your available balance. Please try again.',
        'تعذر تحميل رصيدك المتاح. يرجى المحاولة مرة أخرى.',
      );
  String get withdrawalSubmitted => _t(
        'Withdrawal request submitted successfully. Waiting for admin approval.',
        'تم إرسال طلب السحب بنجاح. في انتظار موافقة المسؤول.',
      );
  String get errNoRideToAccept =>
      _t('No ride to accept.', 'لا توجد رحلة للقبول.');
  String get errNoActiveRidePickup => _t(
        'No active ride to complete pickup.',
        'لا توجد رحلة نشطة لإكمال الاستلام.',
      );
  String get errNoActiveRideStart =>
      _t('No active ride to start.', 'لا توجد رحلة نشطة للبدء.');
  String get errNoActiveRideFound =>
      _t('No active ride found.', 'لم يتم العثور على رحلة نشطة.');
  String get errNoActiveTripComplete => _t(
        'No active trip to complete.',
        'لا توجد رحلة نشطة للإكمال.',
      );
}
