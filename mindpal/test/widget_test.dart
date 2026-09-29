import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/app.dart';
import 'package:mindpal/services/ai_service.dart';
import 'package:mindpal/services/game_history_service.dart';
import 'package:mindpal/services/game_settings_service.dart';
import 'package:mindpal/services/language_service.dart';
import 'package:mindpal/services/memory_aid_service.dart';
import 'package:mindpal/services/memory_vault_service.dart';
import 'package:mindpal/services/notification_service.dart';
import 'package:mindpal/services/profile_service.dart';
import 'package:mindpal/services/reminder_service.dart';
import 'package:mindpal/storage/local_storage.dart';
import 'package:mindpal/storage/media/media_store.dart';

/// Smoke tests for the whole app.
///
/// They prove it starts and that its layers connect. Everything runs on
/// InMemoryStorage, NoopNotificationService and DeterministicAiService, so no
/// test ever touches a real disk, schedules a real alarm, or makes a network
/// call. That is the payoff for every abstraction in this project.
Future<void> _pumpApp(WidgetTester tester, InMemoryStorage storage) async {
  await storage.init();

  // A tall phone. The default test surface is 800x600, which is wide enough to
  // trigger the desktop frame and short enough that a ListView never builds
  // its lower children — so widgets that exist would not be found.
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MindPalApp(
      profileService: ProfileService(storage),
      reminderService: ReminderService(storage, NoopNotificationService()),
      memoryAidService: MemoryAidService(storage),
      memoryVaultService: MemoryVaultService(storage, media: InMemoryMediaStore()),
      gameHistoryService: GameHistoryService(storage),
      gameSettingsService: GameSettingsService(storage),
      languageService: LanguageService(storage),
      aiService: const DeterministicAiService(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls Home until [finder] is on screen.
///
/// Home is a ListView, and a ListView does not build children below the
/// viewport at all — so something that exists but is further down cannot be
/// found without scrolling to it. This is not a workaround for a bug; it is how
/// a long list behaves.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 240, maxScrolls: 30);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home leads with games', (tester) async {
    await _pumpApp(tester, InMemoryStorage());

    // Play a game is the first action and is visible without scrolling: that
    // is the whole point of the game-led ordering.
    expect(find.text('Play a game'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);

    // The games are named on Home with what they are and how hard they are set.
    expect(find.text('Story Order'), findsOneWidget);
    expect(find.text('Family Photo Match'), findsOneWidget);
    expect(find.textContaining('Difficulty: Easy'), findsWidgets);

    // Which pack the pictures come from, and a way to change it. It sits just
    // below the four game rows, so on a phone-sized screen it needs scrolling
    // to.
    final packLine = find.textContaining('Assam: Bihu and everyday things');
    await _scrollTo(tester, packLine);
    expect(packLine, findsWidgets);
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('the other features are still reachable from home', (
    tester,
  ) async {
    await _pumpApp(tester, InMemoryStorage());

    // Below the games, in the smaller section — present, just no longer
    // competing with Play a game for attention.
    await _scrollTo(tester, find.text('Also here'));
    expect(find.text('My memories'), findsOneWidget);
    expect(find.text('My reminders'), findsOneWidget);
    expect(find.text('People who help me'), findsOneWidget);
    expect(find.text('Memory Assistant'), findsOneWidget);
  });

  testWidgets('with nothing saved, home says so rather than showing zeros', (
    tester,
  ) async {
    await _pumpApp(tester, InMemoryStorage());

    await _scrollTo(tester, find.text('No activity yet today'));
    expect(find.text('No activity yet today'), findsOneWidget);

    await _scrollTo(tester, find.text('No reminders for today'));
    expect(find.text('No reminders for today'), findsOneWidget);
  });

  testWidgets('nothing played yet means no Continue playing card', (
    tester,
  ) async {
    await _pumpApp(tester, InMemoryStorage());

    // It appears only once there is something to continue. An empty
    // "Continue playing" would be a button that leads nowhere.
    expect(find.text('Continue playing'), findsNothing);
  });

  testWidgets('saving the profile updates the greeting on Home', (
    tester,
  ) async {
    await _pumpApp(tester, InMemoryStorage());

    // Before a name is entered the greeting uses a friendly placeholder.
    expect(find.text('Friend'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Lakshmi');
    await tester.pumpAndSettle();

    // The profile form is now taller than the test window, so Save has to be
    // scrolled into view before it can be tapped. Without this the tap lands
    // on whatever happens to be painted at those coordinates.
    final saveButton = find.text('Save my details');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Lakshmi'), findsOneWidget);
    expect(find.text('Friend'), findsNothing);
  });

  testWidgets('every tab opens without crashing', (tester) async {
    await _pumpApp(tester, InMemoryStorage());

    for (final icon in [
      Icons.psychology_outlined, // MindPal games
      Icons.alarm_outlined, // Reminders
      Icons.photo_album_outlined, // Memory
      Icons.person_outline, // Profile
      Icons.home_outlined, // back to Home
    ]) {
      await tester.tap(find.byIcon(icon).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('changing the language retranslates the shell', (tester) async {
    await _pumpApp(tester, InMemoryStorage());

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    // Profile -> the language row -> the picker.
    await tester.tap(find.text('English').first);
    await tester.pumpAndSettle();

    // Assamese, chosen by its own name in its own script.
    await tester.tap(find.text('অসমীয়া'));
    await tester.pumpAndSettle();

    // One tap retranslates the navigation bar. That is what LanguageScope
    // being an InheritedWidget buys us — no listeners wired by hand.
    expect(find.text('ঘৰ'), findsOneWidget); // "Home"
    expect(find.text('Home'), findsNothing);
  });
}
