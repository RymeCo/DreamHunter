import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dreamhunter/widgets/chat_dialog.dart';
import 'package:dreamhunter/services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MockChatService extends Mock implements ChatService {}
class MockQuerySnapshot extends Mock implements QuerySnapshot {}

void main() {
  late MockChatService mockChatService;

  setUp(() {
    mockChatService = MockChatService();
    // Return an empty stream by default
    when(() => mockChatService.getChatStream(any())).thenAnswer((_) => Stream.value(MockQuerySnapshot()));
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: ChatDialog(chatService: mockChatService),
      ),
    );
  }

  group('ChatDialog Widget Tests', () {
    testWidgets('renders Global Chat title', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      expect(find.text('Global Chat'), findsOneWidget);
    });

    testWidgets('renders Type a message... hint text', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      expect(find.text('Type a message...'), findsOneWidget);
    });

    testWidgets('renders send icon button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      expect(find.byIcon(Icons.send), findsOneWidget);
    });
  });
}
