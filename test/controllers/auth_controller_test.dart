import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vanguard_fashion/controllers/auth_controller.dart';
import 'package:vanguard_fashion/core/utils/supabase_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}
class MockPostgrestTransformBuilder extends Mock implements PostgrestTransformBuilder<Map<String, dynamic>?> {}

void main() {
  late AuthController authController;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuthClient;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late MockPostgrestTransformBuilder mockTransformBuilder;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockAuthClient = MockGoTrueClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    mockTransformBuilder = MockPostgrestTransformBuilder();

    when(() => mockSupabaseClient.auth).thenReturn(mockAuthClient);
    when(() => mockSupabaseClient.from(any())).thenAnswer((_) => mockQueryBuilder);

    SupabaseService.setMockClient(mockSupabaseClient);

    authController = AuthController();
  });

  tearDown(() {
    SupabaseService.clearMockClient();
  });

  group('AuthController signIn Tests', () {
    test('Happy Path: Returns true and sets user on success', () async {
      final mockUser = User(
        id: 'user-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'test@example.com',
      );
      final mockResponse = AuthResponse(user: mockUser);

      when(() => mockAuthClient.signInWithPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => mockResponse);

      // Mocking profile load
      when(() => mockQueryBuilder.select()).thenAnswer((_) => mockFilterBuilder);
      when(() => mockFilterBuilder.eq('id', 'user-123')).thenAnswer((_) => mockTransformBuilder as dynamic);

      // By using dynamic casting, we can force mocktail to return a MockPostgrestTransformBuilder itself
      // since PostgrestTransformBuilder acts as a Future builder pattern and `thenAnswer` handles the async nature.
      when(() => mockTransformBuilder.maybeSingle()).thenAnswer((_) => mockTransformBuilder as dynamic);
      // Now we tell the transform builder that when it is awaited (i.e. 'then' is called), it returns the row
      when(() => mockTransformBuilder.then<dynamic>(any(), onError: any(named: 'onError'))).thenAnswer((i) {
        final onValue = i.positionalArguments[0] as FutureOr<dynamic> Function(dynamic);
        return Future.value(onValue({
          'id': 'user-123',
          'email': 'test@example.com',
          'full_name': 'Test User',
          'role': 'customer'
        }));
      });

      final result = await authController.signIn('test@example.com', 'password123');

      expect(result, isTrue);
      expect(authController.error.value, isEmpty);
      expect(authController.user.value, isNotNull);
      expect(authController.user.value?.id, 'user-123');
      expect(authController.user.value?.email, 'test@example.com');
    });

    test('Invalid Credentials: Returns false and sets error when user is null', () async {
      final mockResponse = AuthResponse(user: null);

      when(() => mockAuthClient.signInWithPassword(
        email: 'test@example.com',
        password: 'wrongpassword',
      )).thenAnswer((_) async => mockResponse);

      final result = await authController.signIn('test@example.com', 'wrongpassword');

      expect(result, isFalse);
      expect(authController.error.value, 'Invalid credentials');
      expect(authController.user.value, isNull);
    });

    test('AuthException: Returns false and sets specific error message', () async {
      when(() => mockAuthClient.signInWithPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenThrow(const AuthException('Invalid login credentials', statusCode: '400'));

      final result = await authController.signIn('test@example.com', 'password123');

      expect(result, isFalse);
      expect(authController.error.value, 'Invalid login credentials');
      expect(authController.user.value, isNull);
    });

    test('Generic Exception: Returns false and sets generic error message', () async {
      when(() => mockAuthClient.signInWithPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenThrow(Exception('Network error'));

      final result = await authController.signIn('test@example.com', 'password123');

      expect(result, isFalse);
      expect(authController.error.value, 'Sign-in failed: Exception: Network error');
      expect(authController.user.value, isNull);
    });
  });
}
