import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/gallery_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/admin_dashboard_screen.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/view_image_screen.dart';
import 'screens/share_screen.dart';
import 'screens/inbox_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.init();
  runApp(const SecureGalleryApp());
}

class SecureGalleryApp extends StatelessWidget {
  const SecureGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GalleryProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: MaterialApp(
        title: 'Secure Gallery',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const _SplashGate(),
        routes: {
          '/login':    (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/gallery':  (_) => const GalleryScreen(),
          '/upload':   (_) => const UploadScreen(),
          '/view':     (_) => const ViewImageScreen(),
          '/share':    (_) => const ShareScreen(),
          '/inbox':    (_) => const InboxScreen(),
          '/admin':    (_) => const AdminDashboardScreen(),
        },
      ),
    );
  }
}

/// Checks for a stored JWT and navigates to gallery or login.
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    final auth = context.read<AuthProvider>();
    await auth.checkAuthState();
    if (!mounted) return;
    Navigator.pushReplacementNamed(
        context,
        !auth.isLoggedIn ? '/login' : (auth.isAdmin ? '/admin' : '/gallery'));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 80, color: Colors.deepPurple),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }
}
