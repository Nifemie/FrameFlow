import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';

class AuthStateModel {
  final bool isLoading;
  final User? user;
  final UserProfile? profile;
  final String? errorMessage;

  const AuthStateModel({
    this.isLoading = true,
    this.user,
    this.profile,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;
  bool get isPaid => profile?.isPaid ?? true;

  AuthStateModel copyWith({
    bool? isLoading,
    User? user,
    UserProfile? profile,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthStateModel(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      profile: clearUser ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthStateModel>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthNotifier(service);
});

class AuthNotifier extends StateNotifier<AuthStateModel> {
  static const String _kLastActiveKey = 'frameflow_last_active_time';
  static const int _kMaxInactiveDays = 30;

  final AuthService _service;

  AuthNotifier(this._service) : super(const AuthStateModel(isLoading: true)) {
    _init();
  }

  Future<void> _recordActiveTouch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastActiveKey, DateTime.now().toUtc().toIso8601String());
    } catch (_) {}
  }

  Future<void> _clearActiveTouch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLastActiveKey);
    } catch (_) {}
  }

  Future<void> _init() async {
    final current = _service.currentUser;
    if (current != null) {
      // Check for 30 consecutive days of inactivity
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastActiveStr = prefs.getString(_kLastActiveKey);
        if (lastActiveStr != null) {
          final lastActive = DateTime.tryParse(lastActiveStr);
          if (lastActive != null) {
            final daysInactive = DateTime.now().toUtc().difference(lastActive).inDays;
            if (daysInactive >= _kMaxInactiveDays) {
              await _service.signOut();
              await _clearActiveTouch();
              state = state.copyWith(
                isLoading: false,
                clearUser: true,
                errorMessage: 'Your session expired after 30 days of inactivity. Please sign in again.',
              );
              return;
            }
          }
        }
      } catch (_) {}

      // Keep active session alive & update last active timestamp
      await _recordActiveTouch();
      final profile = await _service.fetchProfile();
      state = state.copyWith(isLoading: false, user: current, profile: profile);
    } else {
      state = state.copyWith(isLoading: false, clearUser: true);
    }

    _service.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        if (session?.user != null) {
          await _recordActiveTouch();
          final profile = await _service.fetchProfile();
          state = state.copyWith(isLoading: false, user: session!.user, profile: profile, clearError: true);
        }
      } else if (event == AuthChangeEvent.signedOut) {
        await _clearActiveTouch();
        state = state.copyWith(isLoading: false, clearUser: true, clearError: true);
      }
    });
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _service.signIn(email: email.trim(), password: password);
      if (res.user != null) {
        await _recordActiveTouch();
        final profile = await _service.fetchProfile();
        state = state.copyWith(isLoading: false, user: res.user, profile: profile);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: 'Sign in failed.');
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _service.signUp(
        email: email.trim(),
        password: password,
        displayName: displayName.trim(),
      );
      if (res.user != null) {
        await _recordActiveTouch();
        final profile = await _service.fetchProfile();
        state = state.copyWith(isLoading: false, user: res.user, profile: profile);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: 'Sign up failed.');
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final success = await _service.signInWithGoogle();
      if (success) {
        await _recordActiveTouch();
        final profile = await _service.fetchProfile();
        state = state.copyWith(
          isLoading: false,
          user: _service.currentUser,
          profile: profile,
        );
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: 'Google sign in canceled or failed.');
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _clearActiveTouch();
      await _service.signOut();
    } finally {
      state = state.copyWith(isLoading: false, clearUser: true);
    }
  }

  Future<void> refreshProfile() async {
    final profile = await _service.fetchProfile();
    state = state.copyWith(profile: profile);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
