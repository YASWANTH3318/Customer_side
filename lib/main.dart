import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/initialization_widget.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/home_page.dart';
import 'widgets/role_based_auth_guard.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
// Restaurant-side app removed for customer/blogger-only build
import 'pages/blogger/blogger_home_page.dart';
import 'dart:async';

Future<void> main() async {
  // Capture Firebase initialization errors
  await runZonedGuarded(
    () async {
      // Ensure Flutter is initialized
      WidgetsFlutterBinding.ensureInitialized();
      // Set preferred orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Initialize Firebase with error handling
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Initialize Firebase App Check with debug provider
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
        );

        // Disable verbose debug logs from Firebase
        FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      } catch (e) {
        debugPrint('Firebase initialization error: $e');
      }

      runApp(const MyApp());
    },
    (error, stackTrace) {
      debugPrint('Caught error in main: $error');
      debugPrint(stackTrace.toString());
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Greedy Bites',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          primary: Colors.orange,
          secondary: Colors.orangeAccent,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const LoginPage(),
      routes: {
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
        // Restaurant routes removed
        '/blogger-home': (context) => const BloggerHomePage(),
      },
    );
  }
}

// Placeholder widgets for routes
// You should create separate files for each of these pages
class RestaurantListPage extends StatelessWidget {
  const RestaurantListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurants')),
      body: const Center(child: Text('Restaurant List Page')),
    );
  }
}

class RestaurantDetailsPage extends StatelessWidget {
  const RestaurantDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Details')),
      body: const Center(child: Text('Restaurant Details Page')),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: const Center(child: Text('Favorites Page')),
    );
  }
}

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: const Center(child: Text('Search Page')),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings Page')),
    );
  }
}
