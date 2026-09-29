import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/adventure/storage/adventure_store.dart';
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
      adventureStore: AdventureStore(storage),
      languageService: LanguageService(storage),
      aiService: const DeterministicAiService(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls a tab's list until [finder] is on screen.
///
/// These are ListViews, and a ListView does not build children below the
/// viewport at all — so something that exists but is further down cannot be
/// found without scrolling to it. This is not a workaround for a bug; it is how
/// a long list behaves.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 240, maxScrolls: 30);
  await tester.pumpAndSettle();
}

/// Opens one of the four destinations by its bar icon.
Future<void> _openTab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the app opens on Festival Quest', (tester) async {
    await _pumpApp(tester, InMemoryStorage());

    // The adventure is the main journey now, and it is what the app opens on.
    expect(find.text('Festival Quest'), findsWidgets);
    expect(find.text('Start Adventure'), findsOneWidget);
    expect(find.text('Saved Adventures'), findsOneWidget);
    expect(find.text('Quick Games'), findsWidgets);
    expect(find.text('My Progress'), findsWidgets);
  });

  testWidgets('with nothing played there is nothing to continue', (
    tester,
  ) async {
    await _pumpApp(tester, InMemoryStorage());

    // "Continue" appears only once there is something to continue. An empty
    // one would be a button that leads nowhere.
    expect(find.text('Continue Adventure'), findsNothing);
  });

  testWidgets('the four destinations all open without crashing', (
    tester,
  ) async {
    await _pumpApp(tester, InMemoryStorage());

    for (final icon in [
      Icons.psychology_outlined, // Quick Games
      Icons.timeline_outlined, // My Progress
      Icons.widgets_outlined, // Extras
      Icons.explore_outlined, // back to Festival Quest
    ]) {
      await _openTab(tester, icon);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the quick games are still whole under Quick Games', (
    tester,
  ) async {
    await _pumpApp(tester, InMemoryStorage());
    await _openTab(tester, Icons.psychology_outlined);

    expect(find.text('Play, Remember, Connect'), findsOneWidget);
    expect(find.text('Cultural Memory Match'), findsWidgets);
    await _scrollTo(tester, find.text('Story Order'));
    expect(find.text('Story Order'), findsWidgets);
    await _scrollTo(tester, find.text('Other games'));
    expect(find.text('Sequence Recall'), findsOneWidget);
  });

  testWidgets('reminders, memories and the assistant live in Extras', (
    tester,
  ) async {
    await _pumpApp(tester, InMemoryStorage());
    await _openTab(tester, Icons.widgets_outlined);

    // Everything still works; it has simply stopped competing with the game
    // for the front of the app.
    expect(find.text('Extras'), findsWidgets);
    expect(find.text('My reminders'), findsOneWidget);
    expect(find.text('My memories'), findsOneWidget);
    expect(find.text('Memory Assistant'), findsOneWidget);
    expect(
      find.textContaining('You do not need any of it to play'),
      findsOneWidget,
    );
  });

  testWidgets('an Extra opens in place and comes back', (tester) async {
    await _pumpApp(tester, InMemoryStorage());
    await _openTab(tester, Icons.widgets_outlined);

    await tester.tap(find.text('My reminders'));
    await tester.pumpAndSettle();
    expect(find.text('No reminders yet'), findsOneWidget);

    // Back to the Extras menu, not out of the app.
    await tester.tap(find.byTooltip('Back to Extras'));
    await tester.pumpAndSettle();
    expect(find.text('My memories'), findsOneWidget);
  });

  testWidgets('playing is never gated on linking a caregiver', (tester) async {
    await _pumpApp(tester, InMemoryStorage());

    // Nothing on the way into an adventure mentions a caregiver, a code or a
    // sign-in. The caregiver tools are preserved, in Extras, and optional.
    expect(find.textContaining('caregiver'), findsNothing);
    expect(find.textContaining('code'), findsNothing);

    await tester.tap(find.text('Start Adventure'));
    await tester.pumpAndSettle();

    // The introduction says, before anything else, that the story is made up.
    expect(find.text('This story is made up'), findsOneWidget);
    await _scrollTo(tester, find.text('Begin the adventure'));
    expect(find.text('Begin the adventure'), findsOneWidget);
  });

  testWidgets('saving the profile updates the name shown in Extras', (
    tester,
  ) async {
    await _pumpApp(tester, InMemoryStorage());

    await _openTab(tester, Icons.widgets_outlined);
    await tester.tap(find.text('My Profile'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Lakshmi');
    await tester.pumpAndSettle();

    // The profile form is taller than the test window, so Save has to be
    // scrolled into view before it can be tapped. Without this the tap lands
    // on whatever happens to be painted at those coordinates.
    final saveButton = find.text('Save my details');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Lakshmi'), findsOneWidget);
  });

  testWidgets('changing the language retranslates the shell', (tester) async {
    await _pumpApp(tester, InMemoryStorage());

    await _openTab(tester, Icons.widgets_outlined);
    await tester.tap(find.text('My Profile'));
    await tester.pumpAndSettle();

    // Profile -> the language row -> the picker.
    await tester.tap(find.text('English').first);
    await tester.pumpAndSettle();

    // Assamese, chosen by its own name in its own script.
    await tester.tap(find.text('অসমীয়া'));
    await tester.pumpAndSettle();

    // One tap retranslates the screen. That is what LanguageScope being an
    // InheritedWidget buys us — no listeners wired by hand.
    expect(find.text('English'), findsNothing);
  });
}
