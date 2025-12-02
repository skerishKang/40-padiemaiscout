import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../screens/home_screen.dart';
import '../profile_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isSigningIn = false;

  @override
  Widget build(BuildContext context) {
    // 디버그 모드에서는 테스트 계정으로 자동 로그인
    if (kDebugMode) {
      return _buildDebugAuthFlow();
    }

    // 릴리스 모드에서는 기존 Google 로그인 로직 사용
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        
        if (snapshot.hasData) {
          return HomeScreen(title: 'GrantScout 홈');
        } else if (snapshot.hasError) {
          return _ErrorScreen(error: snapshot.error.toString());
        } else {
          return _buildSignInScreen();
        }
      },
    );
  }

  Widget _buildDebugAuthFlow() {
    const String kDebugTestEmail = 'testuser@example.com';
    const String kDebugTestPassword = 'testpassword123';

    if (FirebaseAuth.instance.currentUser == null) {
      return FutureBuilder<UserCredential>(
        future: FirebaseAuth.instance.signInWithEmailAndPassword(
          email: kDebugTestEmail,
          password: kDebugTestPassword,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingScreen();
          } else if (snapshot.hasError) {
            return _ErrorScreen(
              error: '테스트 계정 자동 로그인 실패: ${snapshot.error}\n\nFirebase 콘솔에서 testuser@example.com 계정 생성 및 이메일/비밀번호 로그인이 활성화되었는지 확인하세요.',
            );
          } else if (snapshot.hasData || FirebaseAuth.instance.currentUser != null) {
            return HomeScreen(title: 'GrantScout 홈 (디버그 자동 로그인)');
          } else {
            return const _ErrorScreen(error: '알 수 없는 로그인 상태');
          }
        },
      );
    } else {
      return HomeScreen(title: 'GrantScout 홈 (디버그 자동 로그인)');
    }
  }

  Widget _buildSignInScreen() {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _isSigningIn ? null : _handleGoogleSignIn,
          child: _isSigningIn
              ? const SizedBox(
                  height: 20.0,
                  width: 20.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Google 로그인'),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        debugPrint('Google 로그인 취소됨');
        if (mounted) {
          setState(() {
            _isSigningIn = false;
          });
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('Firebase 로그인 성공: ${userCredential.user?.displayName}');
    } catch (e) {
      debugPrint('Google 로그인 에러: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 중 오류 발생: $e')),
      );
      setState(() {
        _isSigningIn = false;
      });
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('로그인 중 오류 발생: $error'),
        ),
      ),
    );
  }
}