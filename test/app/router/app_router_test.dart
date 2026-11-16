import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/app/router/app_router.dart';
import 'package:kogihan_sa_negros/app/router/route_names.dart';
import 'package:kogihan_sa_negros/features/auth/presentation/screens/login_screen.dart';
import 'package:kogihan_sa_negros/features/home/presentation/screens/guest_home_screen.dart';
import 'package:kogihan_sa_negros/features/messaging/presentation/screens/chat_screen.dart';
import 'package:kogihan_sa_negros/features/properties/domain/entities/property_image_entity.dart';
import 'package:kogihan_sa_negros/features/properties/presentation/screens/property_gallery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      anonKey: 'test-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.client.dispose();
  });

  testWidgets('signed-out home route opens the guest home', (tester) async {
    final Widget screen = await _resolveRoute(
      tester,
      const RouteSettings(name: RouteNames.home),
    );

    expect(screen, isA<GuestHomeScreen>());
  });

  testWidgets('chat route forwards conversation details', (tester) async {
    const ChatScreenArgs args = ChatScreenArgs(
      conversationId: 'conversation-1',
      senderName: 'Buyer',
    );
    final Widget screen = await _resolveRoute(
      tester,
      const RouteSettings(name: RouteNames.chat, arguments: args),
    );

    expect(screen, isA<ChatScreen>());
    final ChatScreen chatScreen = screen as ChatScreen;
    expect(chatScreen.conversationId, 'conversation-1');
    expect(chatScreen.senderName, 'Buyer');
  });

  testWidgets('chat route rejects missing conversation details', (
    tester,
  ) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          final Route<dynamic> route = AppRouter.onGenerateRoute(
            const RouteSettings(name: RouteNames.chat),
          );
          expect(
            () => (route as MaterialPageRoute<dynamic>).builder(context),
            throwsArgumentError,
          );
          return const SizedBox.shrink();
        },
      ),
    );
  });

  testWidgets('property gallery route forwards image data', (tester) async {
    const PropertyGalleryArgs args = PropertyGalleryArgs(
      images: <PropertyImageEntity>[
        PropertyImageEntity(id: 'property-1-0', url: 'https://example.com/1'),
      ],
      initialIndex: 0,
    );
    final Widget screen = await _resolveRoute(
      tester,
      const RouteSettings(name: RouteNames.propertyGallery, arguments: args),
    );

    expect(screen, isA<PropertyGalleryScreen>());
    expect((screen as PropertyGalleryScreen).arguments.images, hasLength(1));
  });

  testWidgets('property gallery route rejects missing image data', (
    tester,
  ) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          final Route<dynamic> route = AppRouter.onGenerateRoute(
            const RouteSettings(name: RouteNames.propertyGallery),
          );
          expect(
            () => (route as MaterialPageRoute<dynamic>).builder(context),
            throwsArgumentError,
          );
          return const SizedBox.shrink();
        },
      ),
    );
  });

  testWidgets('signed-out Agent Teams route opens login', (tester) async {
    final Widget screen = await _resolveRoute(
      tester,
      const RouteSettings(name: RouteNames.agentTeams),
    );

    expect(screen, isA<LoginScreen>());
  });
}

Future<Widget> _resolveRoute(
  WidgetTester tester,
  RouteSettings settings,
) async {
  late Widget screen;
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        final Route<dynamic> route = AppRouter.onGenerateRoute(settings);
        screen = (route as MaterialPageRoute<dynamic>).builder(context);
        return const SizedBox.shrink();
      },
    ),
  );
  return screen;
}
