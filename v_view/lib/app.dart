import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'state/auth/auth_provider.dart';
import 'ui/auth/login_screen.dart';
import 'ui/history/history_list_screen.dart';

const Color kPrimaryColor = Color(0xFF4F46E5);
const Color kSecondaryColor = Color(0xFFE5E5E5);
const Color kTextColor = Color(0xFF3C3C3C);
const Color kErrorColor = Color(0xFFFF4B4B);
const Color kSuccessColor = Color(0xFF58CC02);

class VViewApp extends ConsumerWidget {
  const VViewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'v-view',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          primary: kPrimaryColor,
          error: kErrorColor,
        ),
        textTheme: GoogleFonts.nunitoTextTheme().apply(
          bodyColor: kTextColor,
          displayColor: kTextColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: kSecondaryColor,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            elevation: 0,
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: kSuccessColor,
          linearTrackColor: kSecondaryColor,
        ),
      ),
      home: authState.when(
        data: (user) => user != null
            ? const HistoryListScreen()
            : const LoginScreen(),
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const LoginScreen(),
      ),
    );
  }
}
