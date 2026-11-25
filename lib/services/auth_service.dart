import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_profile.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<UserProfile?> fetchProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        // Update last login
        try {
          await _client.from('profiles').update({
            'last_login_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', user.id);
        } catch (_) {}

        return UserProfile.fromJson(res);
      }

      // If profile row doesn't exist yet, auto-create it with is_paid = true
      final fallbackProfile = UserProfile(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'] as String? ??
            (user.email ?? '').split('@').first,
        isPaid: true,
      );

      try {
        await _client.from('profiles').upsert(fallbackProfile.toJson());
      } catch (e) {
        debugPrint('Auto-create profile note: $e');
      }

      return fallbackProfile;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      // If table query fails (e.g. offline or table not created yet), return fallback so user isn't locked out of free beta
      return UserProfile(
        id: user.id,
        email: user.email ?? '',
        displayName: (user.email ?? '').split('@').first,
        isPaid: true,
      );
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );

    if (res.user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': res.user!.id,
          'email': email,
          'display_name': displayName,
          'is_paid': true,
          'app_version': '1.0.0',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'last_login_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Profile insert note: $e');
      }
    }

    return res;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<bool> signInWithGoogle() async {
    const int port = 54321;
    HttpServer? server;

    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } catch (e) {
      debugPrint('Port $port in use, attempting fallback loopback: $e');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }

    final redirectUrl = 'http://localhost:${server.port}/callback';

    try {
      final oAuthRes = await _client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: redirectUrl,
      );

      final launched = await launchUrl(
        Uri.parse(oAuthRes.url),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not launch external web browser.');
      }

      final completer = Completer<Uri>();

      final sub = server.listen((HttpRequest request) async {
        final uri = request.uri;

        // Check if query contains code, token, or error
        final hasCode = uri.queryParameters.containsKey('code');
        final hasToken = uri.queryParameters.containsKey('access_token');
        final hasError = uri.queryParameters.containsKey('error');

        // Response HTML
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>FrameFlow Studio - Sign In</title>
  <style>
    body {
      background: #0d0f14;
      color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
    }
    .card {
      background: #161922;
      border: 1px solid #2a2e3d;
      padding: 40px;
      border-radius: 12px;
      text-align: center;
      box-shadow: 0 10px 30px rgba(0,0,0,0.5);
      max-width: 400px;
    }
    h1 { color: #ff6b2b; margin: 0 0 12px; font-size: 22px; }
    p { color: #9da3ae; margin: 0; font-size: 14px; line-height: 1.5; }
  </style>
</head>
<body>
  <div class="card">
    <h1>✓ Authentication Complete</h1>
    <p>You have signed in to FrameFlow Studio.<br>You can safely close this browser window.</p>
  </div>
  <script>
    if (window.location.hash) {
      fetch('/token' + window.location.hash.replace('#', '?'));
    }
  </script>
</body>
</html>''');
        await request.response.close();

        if (hasCode || hasToken || hasError || uri.path == '/token') {
          if (!completer.isCompleted) {
            completer.complete(uri);
          }
        }
      });

      final callbackUri = await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw TimeoutException('Google Sign In timed out.'),
      );

      await sub.cancel();
      await server.close(force: true);

      // Exchange URL code for session
      await _client.auth.getSessionFromUrl(callbackUri);

      // Upsert profile for Google user
      final user = _client.auth.currentUser;
      if (user != null) {
        try {
          final displayName = user.userMetadata?['full_name'] as String? ??
              user.userMetadata?['name'] as String? ??
              (user.email ?? '').split('@').first;

          await _client.from('profiles').upsert({
            'id': user.id,
            'email': user.email ?? '',
            'display_name': displayName,
            'is_paid': true,
            'app_version': '1.0.0',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'last_login_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Google profile upsert note: $e');
        }
      }

      return true;
    } catch (e) {
      await server.close(force: true);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
