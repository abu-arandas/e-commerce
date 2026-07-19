import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/utils/app_constants.dart';
import '../core/utils/supabase_service.dart';
import '../models/user_model.dart';

/// Authentication + session/role state (PRD §2). Backed by Supabase Auth when
/// configured; in demo mode it supports a "Preview as…" path so the role-gated
/// admin panels remain reachable.
class AuthController extends GetxController {
  final Rxn<AppUser> user = Rxn<AppUser>();
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  bool get isLoggedIn => user.value != null;
  bool get isStaff => user.value?.role.isStaff ?? false;
  AppRole get role => user.value?.role ?? AppRole.customer;

  @override
  void onInit() {
    super.onInit();
    if (SupabaseService.isReady) {
      _bindAuthState();
      final current = SupabaseService.auth.currentUser;
      if (current != null) _loadProfile(current.id, current.email);
    }
  }

  void _bindAuthState() {
    SupabaseService.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session?.user != null) {
        _loadProfile(session!.user.id, session.user.email);
      } else {
        user.value = null;
      }
    });
  }

  Future<void> _loadProfile(String id, String? email) async {
    try {
      final row = await SupabaseService.client
          .from(AppConstants.tblProfiles)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row != null) {
        user.value = AppUser.fromJson(Map<String, dynamic>.from(row));
      } else {
        user.value = AppUser(id: id, email: email ?? '');
      }
    } catch (_) {
      user.value = AppUser(id: id, email: email ?? '');
    }
  }

  Future<bool> signIn(String email, String password) async {
    isLoading.value = true;
    error.value = '';
    try {
      if (!SupabaseService.isReady) {
        // Demo: accept any credentials as a customer.
        user.value = AppUser(id: 'demo-customer', email: email, fullName: null);
        return true;
      }
      final res = await SupabaseService.auth
          .signInWithPassword(email: email, password: password);
      if (res.user != null) {
        await _loadProfile(res.user!.id, res.user!.email);
        return true;
      }
      error.value = 'Invalid credentials';
      return false;
    } on sb.AuthException catch (e) {
      error.value = e.message;
      return false;
    } catch (e) {
      error.value = 'Sign-in failed: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> signUp(String email, String password, {String? fullName}) async {
    isLoading.value = true;
    error.value = '';
    try {
      if (!SupabaseService.isReady) {
        user.value = AppUser(id: 'demo-customer', email: email, fullName: fullName);
        return true;
      }
      final res = await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      if (res.user != null) {
        await _loadProfile(res.user!.id, res.user!.email);
        return true;
      }
      error.value = 'Sign-up failed';
      return false;
    } on sb.AuthException catch (e) {
      error.value = e.message;
      return false;
    } catch (e) {
      error.value = 'Sign-up failed: $e';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    if (SupabaseService.isReady) {
      await SupabaseService.auth.signOut();
    }
    user.value = null;
  }

  /// Demo-only: preview a staff persona without a backend so the admin panels
  /// can be explored. Only takes effect when Supabase is not configured.
  void previewAs(AppRole role) {
    if (SupabaseService.isReady) return;
    user.value = AppUser(
      id: 'demo-${role.db}',
      email: '${role.db}@vanguard.test',
      fullName: role.label,
      role: role,
    );
  }
}
