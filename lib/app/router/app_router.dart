import 'package:flutter/material.dart';

import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/moderation_screen.dart';
import '../../features/agent/presentation/screens/agent_dashboard_screen.dart';
import '../../features/agent/presentation/screens/create_listing_screen.dart';
import '../../features/agent/presentation/screens/edit_listing_screen.dart';
import '../../features/agent/presentation/screens/manage_listings_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/inquiries/presentation/screens/inquiries_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/messaging/presentation/screens/chat_screen.dart';
import '../../features/messaging/presentation/screens/inbox_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/role_selection_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/properties/presentation/screens/property_details_screen.dart';
import '../../features/properties/presentation/screens/property_filter_screen.dart';
import '../../features/properties/presentation/screens/property_gallery_screen.dart';
import '../../features/properties/presentation/screens/property_list_screen.dart';
import '../../features/properties/presentation/screens/property_search_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/subscription/presentation/screens/plans_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import 'route_names.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => _screenFor(settings.name),
    );
  }

  static Widget _screenFor(String? routeName) {
    switch (routeName) {
      case RouteNames.splash:
        return const SplashScreen();
      case RouteNames.onboarding:
        return const OnboardingScreen();
      case RouteNames.roleSelection:
        return const RoleSelectionScreen();
      case RouteNames.login:
        return const LoginScreen();
      case RouteNames.register:
        return const RegisterScreen();
      case RouteNames.forgotPassword:
        return const ForgotPasswordScreen();
      case RouteNames.home:
        return const HomeScreen();
      case RouteNames.properties:
        return const PropertyListScreen();
      case RouteNames.propertyDetails:
        return const PropertyDetailsScreen();
      case RouteNames.propertyGallery:
        return const PropertyGalleryScreen();
      case RouteNames.propertyFilter:
        return const PropertyFilterScreen();
      case RouteNames.propertySearch:
        return const PropertySearchScreen();
      case RouteNames.map:
        return const MapScreen();
      case RouteNames.search:
        return const SearchScreen();
      case RouteNames.favorites:
        return const FavoritesScreen();
      case RouteNames.inquiries:
        return const InquiriesScreen();
      case RouteNames.inbox:
        return const InboxScreen();
      case RouteNames.chat:
        return const ChatScreen();
      case RouteNames.agentDashboard:
        return const AgentDashboardScreen();
      case RouteNames.manageListings:
        return const ManageListingsScreen();
      case RouteNames.createListing:
        return const CreateListingScreen();
      case RouteNames.editListing:
        return const EditListingScreen();
      case RouteNames.profile:
        return const ProfileScreen();
      case RouteNames.editProfile:
        return const EditProfileScreen();
      case RouteNames.subscription:
        return const SubscriptionScreen();
      case RouteNames.plans:
        return const PlansScreen();
      case RouteNames.notifications:
        return const NotificationsScreen();
      case RouteNames.adminDashboard:
        return const AdminDashboardScreen();
      case RouteNames.moderation:
        return const ModerationScreen();
      default:
        return const SplashScreen();
    }
  }
}
