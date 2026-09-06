import '../services/memory_assistant_service.dart';

/// Who said it.
enum ChatAuthor { user, companion }

/// Where a companion answer came from, as shown to the user.
///
/// Requirement 12/13: an answer read out of the user's own vault and a piece
/// of general health information must never look the same. Mixing them is how
/// a user comes to believe the app said something personal about them.
enum AnswerKind {
  /// Read from the user's saved People / Places / Notes.
  personal,

  /// General information about memory. Not about this user.
  education,

  /// Places, facts, light conversation. Nothing to do with the vault.
  general,

  /// A question about the user's own health. Answered from fixed text.
  safety,

  /// The greeting and other plain chat.
  plain,
}

/// A follow-up the companion offers under its own answer.
///
/// Only ever built from what the app can actually do next — never a guess at
/// what might be interesting.
enum ChatFollowUp { playGame, viewReminders, openMemoryAid, askAnother }

/// One line in the conversation.
///
/// Held only in memory, for the current screen. Chat is NOT saved: it is a way
/// of asking questions, not a record of the user's life. Saving it would
/// quietly turn casual questions into stored personal data, and would blur the
/// line the whole design depends on — the Vault is the source of truth, the
/// conversation is not.
class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    this.kind = AnswerKind.plain,
    this.source = AnswerSource.none,
    this.delivery,
    this.followUps = const [],
    this.isError = false,
  });

  const ChatMessage.user(this.text)
    : author = ChatAuthor.user,
      kind = AnswerKind.plain,
      source = AnswerSource.none,
      delivery = null,
      followUps = const [],
      isError = false;

  final ChatAuthor author;
  final String text;

  final AnswerKind kind;

  /// Which part of the vault the answer came from. Shown under companion
  /// messages so the user can see it was read, not invented.
  final AnswerSource source;

  /// How the answer was produced — generated online or answered offline.
  /// Null on user messages and on the greeting.
  final String? delivery;

  final List<ChatFollowUp> followUps;

  /// True for the "something went wrong" message, which gets a retry button.
  final bool isError;

  bool get isFromUser => author == ChatAuthor.user;
}

/// Picks the buttons to show under an answer.
///
/// Driven by what the answer actually is, not by keyword-matching the user's
/// question — so a question about Rahul never offers "View reminders" just
/// because the word "today" appeared in it.
List<ChatFollowUp> followUpsFor(AssistantAnswer answer) {
  if (!answer.found) {
    // Nothing matched: the useful next step is adding the thing that was
    // missing, not asking the same question again.
    return const [ChatFollowUp.openMemoryAid, ChatFollowUp.askAnother];
  }

  return switch (answer.source) {
    AnswerSource.person ||
    AnswerSource.place ||
    AnswerSource.note ||
    AnswerSource.collection => const [
      ChatFollowUp.askAnother,
      ChatFollowUp.playGame,
    ],
    AnswerSource.none => const [ChatFollowUp.askAnother],
  };
}
