import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/properties/data/datasources/shared_properties.dart';
import 'package:kogihan_sa_negros/features/search/presentation/screens/property_search_results_screen.dart';
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
    appPropertiesNotifier.value = <Property>[];
    await Supabase.instance.client.dispose();
  });

  testWidgets('search updates and displays matching property results', (
    tester,
  ) async {
    appPropertiesNotifier.value = <Property>[
      _property(id: '1', title: 'Lot in Bacolod', location: 'Bacolod'),
      _property(id: '2', title: 'Beachfront land', location: 'Sagay'),
    ];

    await tester.pumpWidget(
      const MaterialApp(home: PropertySearchResultsScreen(title: 'Search')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lot in Bacolod'), findsOneWidget);
    expect(find.text('Beachfront land'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bacolod');
    await tester.pump();

    expect(find.text('Lot in Bacolod'), findsOneWidget);
    expect(find.text('Beachfront land'), findsNothing);
  });

  testWidgets('short searches do not show inside-word matches', (tester) async {
    appPropertiesNotifier.value = <Property>[
      _property(id: '1', title: 'Urban lot', location: 'Bacolod'),
      _property(id: '2', title: 'Four bedroom lot', location: 'Sagay'),
    ];

    await tester.pumpWidget(
      const MaterialApp(home: PropertySearchResultsScreen(title: 'Search')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ur');
    await tester.pump();

    expect(find.text('Urban lot'), findsOneWidget);
    expect(find.text('Four bedroom lot'), findsNothing);
  });
}

Property _property({
  required String id,
  required String title,
  required String location,
}) {
  return Property(
    id: id,
    referenceCode: id,
    title: title,
    location: location,
    price: '₱1,200,000',
    priceValue: 1200000,
    size: '500 sqm',
    sizeValue: 500,
    tag: 'Available',
    titleStatus: 'Available',
    description: '',
    imageColor: Colors.green,
  );
}
