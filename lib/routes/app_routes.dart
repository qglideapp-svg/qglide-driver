import 'package:flutter/material.dart';

import '../features/auth/document_success/document_submission_success_view.dart';
import '../features/auth/document_upload/document_upload_view.dart';
import '../features/auth/forgot_password/forgot_password_view.dart';
import '../features/auth/login/login_view.dart';
import '../features/auth/signup/signup_view.dart';
import '../features/auth/verification/verification_args.dart';
import '../features/auth/verification/verification_view.dart';
import '../features/notifications/notifications_view.dart';
import '../features/home/refer_driver_progress_args.dart';
import '../features/home/refer_driver_progress_view.dart';
import '../features/home/home_view.dart';
import '../features/onboarding/onboarding_view.dart';
import '../features/profile/help_center_view.dart';
import '../features/profile/manage_vehicle_view.dart';
import '../features/profile/personal_information_view.dart';
import '../features/profile/add_support_ticket_view.dart';
import '../features/profile/submitted_tickets_view.dart';
import '../features/profile/support_ticket_detail_view.dart';
import '../features/profile/profile_view.dart';
import '../features/ride/call/in_app_call_args.dart';
import '../features/ride/call/in_app_call_view.dart';
import '../features/ride/chat/ride_chat_args.dart';
import '../features/ride/chat/ride_chat_view.dart';
import '../features/splash/splash_view.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const verification = '/verification';
  static const documentUpload = '/document-upload';
  static const documentSubmissionSuccess = '/document-submission-success';
  static const home = '/home';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const personalInformation = '/personal-information';
  static const manageVehicle = '/manage-vehicle';
  static const helpCenter = '/help-center';
  static const submittedTickets = '/submitted-tickets';
  static const addSupportTicket = '/add-support-ticket';
  static const supportTicketDetail = '/support-ticket-detail';
  static const rideChat = '/ride-chat';
  static const inAppCall = '/in-app-call';
  static const referDriverProgress = '/refer-driver-progress';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SplashView(),
        );
      case onboarding:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const OnboardingView(),
        );
      case login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoginView(),
        );
      case signup:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SignupView(),
        );
      case forgotPassword:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ForgotPasswordView(),
        );
      case verification:
        final args = VerificationArgs.fromRoute(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => VerificationView(args: args),
        );
      case documentUpload:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const DocumentUploadView(),
        );
      case documentSubmissionSuccess:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const DocumentSubmissionSuccessView(),
        );
      case home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomeView(),
        );
      case notifications:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const NotificationsView(),
        );
      case profile:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ProfileView(),
        );
      case personalInformation:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const PersonalInformationView(),
        );
      case manageVehicle:
        final manageVehicleArgs = settings.arguments as ManageVehicleArgs?;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ManageVehicleView(
            fromOnboarding: manageVehicleArgs?.fromOnboarding ?? false,
          ),
        );
      case helpCenter:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HelpCenterView(),
        );
      case submittedTickets:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SubmittedTicketsView(),
        );
      case addSupportTicket:
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => const AddSupportTicketView(),
        );
      case supportTicketDetail:
        final ticket = settings.arguments as SupportTicketDetailArgs?;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => SupportTicketDetailView(
            ticket: ticket ??
                const SupportTicketDetailArgs(
                  ticketId: 'TKT-20260506-98766',
                  subject: 'They Scammed Me',
                ),
          ),
        );
      case rideChat:
        final args = settings.arguments as RideChatArgs?;
        if (args == null || args.rideId.isEmpty) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const HomeView(),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => RideChatView(args: args),
        );
      case inAppCall:
        final args = settings.arguments as InAppCallArgs?;
        if (args == null || args.rideId.isEmpty) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const HomeView(),
          );
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => InAppCallView(args: args),
        );
      case referDriverProgress:
        final args = ReferDriverProgressArgs.fromRoute(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ReferDriverProgressView(
            initialReferralCode: args.initialReferralCode,
          ),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SplashView(),
        );
    }
  }
}
