import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dreamhunter/services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}
class MockAuth extends Mock implements FirebaseAuth {}
class MockClient extends Mock implements http.Client {}
class MockUser extends Mock implements User {}

void main() {
  late ChatService chatService;
  late MockFirestore mockFirestore;
  late MockAuth mockAuth;
  late MockClient mockClient;

  setUp(() {
    mockFirestore = MockFirestore();
    mockAuth = MockAuth();
    mockClient = MockClient();
    chatService = ChatService(
      firestore: mockFirestore,
      auth: mockAuth,
      client: mockClient,
    );
    
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
  });

  group('ChatService', () {
    test('getGuestId generates and stores a new ID if none exists', () async {
      final id1 = await chatService.getGuestId();
      final id2 = await chatService.getGuestId();
      
      expect(id1, isNotEmpty);
      expect(id1, equals(id2)); // Should be cached
      
      // Verify it's in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('guest_id'), equals(id1));
    });

    test('getActiveId returns user uid when logged in', () async {
      final mockUser = MockUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('test-uid');
      
      final id = await chatService.getActiveId();
      expect(id, equals('test-uid'));
    });

    test('getActiveId returns guestId when not logged in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);
      
      final id = await chatService.getActiveId();
      expect(id, isNotEmpty);
      expect(id.length, greaterThan(10)); // UUID length
    });
  });
}
