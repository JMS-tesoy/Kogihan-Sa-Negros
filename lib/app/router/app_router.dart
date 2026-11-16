import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_shell.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/moderation_screen.dart';
import '../../features/agent/presentation/screens/agent_dashboard_screen.dart';
import '../../features/agent/presentation/screens/create_listing_screen.dart';
import '../../features/agent/presentation/screens/edit_listing_screen.dart';
import '../../features/agent/presentation/screens/manage_listings_screen.dart';
import '../../features/agent_teams/presentation/screens/agent_teams_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/home/presentation/screens/guest_home_screen.dart';
import '../../features/inquiries/presentation/screens/inquiries_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/messaging/presentation/screens/chat_screen.dart';
import '../../features/messaging/presentation/screens/inbox_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/role_selection_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/properties/data/datasources/shared_properties.dart';
import '../../features/properties/presentation/screens/property_details_screen.dart';
import '../../features/properties/presentation/screens/property_filter_screen.dart';
import '../../features/properties/presentation/screens/property_gallery_screen.dart';
import '../../features/properties/presentation/screens/property_list_screen.dart';
import '../../features/properties/presentation/screens/property_search_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/subscription/presentation/screens/plans_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import 'route_guards.dart';
import 'route_names.dart';

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => _screenFor(settings),
    );
  }

  static Widget _screenFor(RouteSettings settings) {
    switch (settings.name) {
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
        return _buyerHomeRoute();
      case RouteNames.properties:
        return const PropertyListScreen();
      case RouteNames.propertyDetails:
        final PropertyDetailsArgs args =
            settings.arguments as PropertyDetailsArgs;
        return PropertyDetailsScreen(
          property: args.property,
          isSaved: args.isSaved,
          onToggleSave: args.onToggleSave,
        );
      case RouteNames.propertyGallery:
        final Object? arguments = settings.arguments;
        if (arguments is! PropertyGalleryArgs) {
          throw ArgumentError.value(
            arguments,
            'settings.arguments',
            'Expected PropertyGalleryArgs for ${RouteNames.propertyGallery}.',
          );
        }
        return PropertyGalleryScreen(arguments: arguments);
      case RouteNames.propertyFilter:
        return const PropertyFilterScreen();
      case RouteNames.propertySearch:
        return const PropertySearchScreen();
      case RouteNames.map:
        return MapScreen(selectedProperty: settings.arguments as Property?);
      case RouteNames.search:
        return const SearchScreen();
      case RouteNames.favorites:
        return const FavoritesScreen();
      case RouteNames.inquiries:
        return const InquiriesScreen();
      case RouteNames.inbox:
        return const InboxScreen();
      case RouteNames.chat:
        final Object? arguments = settings.arguments;
        if (arguments is! ChatScreenArgs) {
          throw ArgumentError.value(
            arguments,
            'settings.arguments',
            'Expected ChatScreenArgs for ${RouteNames.chat}.',
          );
        }
        return ChatScreen(
          conversationId: arguments.conversationId,
          senderName: arguments.senderName,
          initialMessages: arguments.initialMessages,
        );
      case RouteNames.agentDashboard:
        return _agentRoute(const AgentDashboardScreen());
      case RouteNames.agentTeams:
        return _authenticatedRoute(const AgentTeamsScreen());
      case RouteNames.manageListings:
        return _agentRoute(const ManageListingsScreen());
      case RouteNames.createListing:
        return _agentRoute(const CreateListingScreen());
      case RouteNames.editListing:
        final Property? property = settings.arguments as Property?;
        return _agentRoute(EditListingScreen(initialProperty: property));
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
        return _adminRoute(const AdminDashboardScreen());
      case RouteNames.moderation:
        return _adminRoute(const ModerationScreen());
      default:
        return const SplashScreen();
    }
  }

  static Widget _buyerHomeRoute() {
    final User? user = Supabase.instance.client.auth.currentUser;
    return user == null ? const GuestHomeScreen() : const AppHomePage();
  }

  static Widget _authenticatedRoute(Widget screen) {
    final User? user = Supabase.instance.client.auth.currentUser;
    return user == null ? const LoginScreen() : screen;
  }

  static Widget _agentRoute(Widget screen) {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const LoginScreen();
    return RouteGuards.canAccessAgentRoutes(user)
        ? screen
        : const GuestHomeScreen();
  }

  static Widget _adminRoute(Widget screen) {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const LoginScreen();
    return RouteGuards.canAccessAdminRoutes(user)
        ? screen
        : const GuestHomeScreen();
  }
}

/// Pass this as `arguments` when pushing [RouteNames.propertyDetails].
class PropertyDetailsArgs {
  const PropertyDetailsArgs({
    required this.property,
    required this.isSaved,
    required this.onToggleSave,
  });

  final Property property;
  final bool isSaved;
  final VoidCallback onToggleSave;
}
