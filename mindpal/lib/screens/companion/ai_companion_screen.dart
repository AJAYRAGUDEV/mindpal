import 'package:flutter/material.dart';

import '../../l10n/language_scope.dart';
import '../../models/chat_message.dart';
import '../../models/game_result.dart';
import '../../models/reminder.dart';
import '../../services/ai/gemini_ai_service.dart';
import '../../services/ai_service.dart';
import '../../services/ai_suggestion_service.dart';
import '../../services/companion/companion_intent.dart';
import '../../services/companion/memory_education.dart';
import '../../services/conversation_context.dart';
import '../../services/memory_aid_service.dart';
import '../../services/memory_assistant_service.dart';
import '../../services/voice_service.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';

/// The AI Memory Companion — the single chat surface for the whole app.
///
/// It is not a general chatbot and must not become one. Every answer is
/// grounded in the user's own saved People, Places and Notes; when nothing
/// matches, it says so rather than filling the silence.
///
/// The pipeline, unchanged from the assistant it replaces:
///
///   question -> resolve pronouns -> local retrieval -> (only if found) Gemini
///            -> grounding check -> answer, labelled with where it came from
class AiCompanionScreen extends StatefulWidget {
  const AiCompanionScreen({
    super.key,
    required this.memoryAidService,
    required this.aiService,
    required this.reminders,
    required this.gameHistory,
    required this.onOpenGames,
    required this.onOpenReminders,
    required this.onOpenMemoryAid,
    this.speech = const UnavailableSpeechToText(),
    this.suggestions = const AiSuggestionService(),
    this.classifier = const CompanionIntentClassifier(),
    this.education = const MemoryEducation(),
  });

  final MemoryAidService memoryAidService;
  final AiService aiService;

  /// Read-only. Used to decide which suggestions make sense, never sent
  /// anywhere.
  final List<Reminder> reminders;
  final List<GameResult> gameHistory;

  final VoidCallback onOpenGames;
  final VoidCallback onOpenReminders;
  final VoidCallback onOpenMemoryAid;

  final SpeechToTextService speech;
  final AiSuggestionService suggestions;

  /// Decides whether a question is about the user's own memories, about
  /// memory in general, or about the user's own health.
  final CompanionIntentClassifier classifier;

  /// The curated, offline educational answers.
  final MemoryEducation education;

  @override
  State<AiCompanionScreen> createState() => _AiCompanionScreenState();
}

class _AiCompanionScreenState extends State<AiCompanionScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _conversation = ConversationContext();

  final List<ChatMessage> _messages = [];
  MemoryAidData _data = const MemoryAidData();
  List<AiSuggestion> _chips = const [];

  bool _isLoading = true;
  bool _isThinking = false;

  /// The last question, so the retry button has something to retry.
  String _lastQuestion = '';

  /// Recent GENERAL turns only, kept for follow-ups like "what is it famous
  /// for?". Personal-memory turns are deliberately never added here, so the
  /// vault never travels with a general question.
  final List<String> _generalHistory = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await widget.memoryAidService.loadAll();
    if (!mounted) return;

    setState(() {
      _data = data;
      _chips = widget.suggestions.suggestionsFor(
        data: data,
        reminders: widget.reminders,
        history: widget.gameHistory,
        now: DateTime.now(),
      );
      _messages.add(
        const ChatMessage(
          author: ChatAuthor.companion,
          // Warm, but an assistant — not a companion in the emotional sense.
          text: 'Hello. I can help you with the people, places and notes you '
              'have saved. What would you like to know?',
        ),
      );
      _isLoading = false;
    });
  }

  Future<void> _send(String rawQuestion) async {
    final question = rawQuestion.trim();
    if (question.isEmpty || _isThinking) return;

    FocusScope.of(context).unfocus();
    _inputController.clear();

    final language = LanguageScope.of(context).language;

    setState(() {
      _messages.add(ChatMessage.user(question));
      _isThinking = true;
      _lastQuestion = question;
    });
    _scrollToEnd();

    final intent = widget.classifier.classify(question);

    // SAFETY BRANCH. A question about the user's own health is answered from
    // fixed text and never sent anywhere. No model is involved, so there is
    // no code path by which a diagnosis can be produced.
    if (intent == CompanionIntent.medicalBoundary) {
      _addCompanionMessage(
        text: widget.education.safeAnswerFor(question),
        kind: AnswerKind.safety,
        followUps: const [ChatFollowUp.askAnother, ChatFollowUp.playGame],
      );
      return;
    }

    // App actions: answer briefly and offer the button, rather than describing
    // a feature the user could simply be taken to.
    if (intent == CompanionIntent.reminder) {
      _addCompanionMessage(
        text: 'Your reminders are on the Reminders screen.',
        kind: AnswerKind.plain,
        followUps: const [ChatFollowUp.viewReminders],
      );
      return;
    }
    if (intent == CompanionIntent.game) {
      _addCompanionMessage(
        text: 'Of course. Which activity would you like?',
        kind: AnswerKind.plain,
        followUps: const [ChatFollowUp.playGame],
      );
      return;
    }

    if (intent == CompanionIntent.memoryEducation) {
      _answerEducation(question);
      return;
    }

    if (kGeneralIntents.contains(intent)) {
      await _answerGeneral(question);
      return;
    }

    // PERSONAL MEMORY. "Where does he live?" becomes "Where does Rahul live?"
    // BEFORE retrieval. The chat history itself is never sent anywhere.
    final resolved = _conversation.resolve(question);

    final answer = await widget.aiService.answerMemoryQuestion(
      question: resolved,
      data: _data,
      language: language,
    );
    if (!mounted) return;

    final service = widget.aiService;
    final delivery = service is GeminiAiService
        ? service.lastDelivery
        : AiDelivery.deterministic;

    // THE FIX for "Tell me about Shillong" when Shillong is not saved.
    //
    // The vault is always tried first because it is free and instant. But a
    // miss used to end the conversation with "I don't have that information
    // yet", even for questions the app could answer perfectly well. Now a miss
    // on an open-ended question falls through to general knowledge.
    //
    // A miss on a WHO question does not fall through: "Who is Arjun?" must
    // stay "I don't have that saved", never a guess about some other Arjun.
    if (!answer.found && _mayFallThroughToGeneral(question, answer)) {
      final handled = await _answerGeneral(question);
      if (handled) return;
    }

    _conversation.remember(answer.found ? answer.subject : null);

    _addCompanionMessage(
      text: answer.text,
      kind: AnswerKind.personal,
      source: answer.source,
      delivery: _deliveryLabel(delivery),
      followUps: followUpsFor(answer),
    );
  }

  /// Whether an unmatched personal question may be re-asked as a general one.
  ///
  /// "Who is Rahul?" must NOT: naming a person the user did not save and
  /// describing some other Rahul would be worse than saying we do not know.
  /// "Tell me about Shillong" may: the user was asking about the world.
  bool _mayFallThroughToGeneral(String question, AssistantAnswer answer) {
    if (answer.intent == AssistantIntent.who) return false;
    final text = question.toLowerCase();
    return text.contains('tell me about') ||
        text.contains('what is') ||
        text.contains('where is');
  }

  /// Places, facts and light conversation. Carries NO personal data.
  ///
  /// Returns true when it produced an answer, so the personal path can decide
  /// whether it still needs to show its own.
  Future<bool> _answerGeneral(String question) async {
    final language = LanguageScope.of(context).language;

    final text = await widget.aiService.answerGeneralQuestion(
      question: question,
      language: language,
      history: List.of(_generalHistory),
    );
    if (!mounted) return false;

    if (text == null) {
      // No generative path. Say so plainly rather than implying the offline
      // answer came from a model.
      _addCompanionMessage(
        text: 'I am offline just now, so I cannot answer general questions.'
            '\n\nI can still help with the people, places and notes you have '
            'saved, and with your reminders.',
        kind: AnswerKind.general,
        followUps: const [ChatFollowUp.askAnother, ChatFollowUp.playGame],
      );
      return true;
    }

    // Only general turns are remembered, and only a few of them.
    _generalHistory
      ..add('Q: $question')
      ..add('A: $text');
    while (_generalHistory.length > 4) {
      _generalHistory.removeAt(0);
    }

    final service = widget.aiService;
    _addCompanionMessage(
      text: text,
      kind: AnswerKind.general,
      delivery: service is GeminiAiService
          ? _deliveryLabel(service.lastDelivery)
          : null,
      followUps: const [ChatFollowUp.askAnother, ChatFollowUp.playGame],
    );
    return true;
  }

  /// General information about memory — NOT about this user.
  ///
  /// The curated set is tried first: it is reviewed text, it is instant, and
  /// it works with no internet. A question it does not cover gets an honest
  /// "I do not have that yet" rather than a guess at health information.
  void _answerEducation(String question) {
    final curated = widget.education.offlineAnswerFor(question);

    if (curated != null) {
      _addCompanionMessage(
        text: curated.answer,
        kind: AnswerKind.education,
        delivery: 'Written for this app, available offline',
        followUps: const [ChatFollowUp.askAnother, ChatFollowUp.playGame],
      );
      return;
    }

    _addCompanionMessage(
      text:
          'I do not have general information on that yet.\n\n'
          'I can explain what memory loss and dementia are, why people forget, '
          'and how sleep and daily habits affect memory.',
      kind: AnswerKind.education,
      followUps: const [ChatFollowUp.askAnother],
    );
  }

  void _addCompanionMessage({
    required String text,
    required AnswerKind kind,
    AnswerSource source = AnswerSource.none,
    String? delivery,
    List<ChatFollowUp> followUps = const [],
  }) {
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          author: ChatAuthor.companion,
          text: text,
          kind: kind,
          source: source,
          delivery: delivery,
          followUps: followUps,
        ),
      );
      _isThinking = false;
    });
    _scrollToEnd();
  }

  String _deliveryLabel(AiDelivery delivery) => switch (delivery) {
    AiDelivery.deterministic => 'From your saved information, on this phone',
    AiDelivery.generated => 'Wording generated online from your saved record',
    AiDelivery.generatedInEnglishFallback =>
      'Generated online, but shown in English',
  };

  void _handleChip(AiSuggestion suggestion) {
    switch (suggestion.action) {
      case SuggestionAction.ask:
        _send(suggestion.prompt);
      case SuggestionAction.openGames:
        Navigator.of(context).pop();
        widget.onOpenGames();
      case SuggestionAction.openReminders:
        Navigator.of(context).pop();
        widget.onOpenReminders();
      case SuggestionAction.openMemoryAid:
        Navigator.of(context).pop();
        widget.onOpenMemoryAid();
    }
  }

  void _handleFollowUp(ChatFollowUp followUp) {
    switch (followUp) {
      case ChatFollowUp.playGame:
        Navigator.of(context).pop();
        widget.onOpenGames();
      case ChatFollowUp.viewReminders:
        Navigator.of(context).pop();
        widget.onOpenReminders();
      case ChatFollowUp.openMemoryAid:
        Navigator.of(context).pop();
        widget.onOpenMemoryAid();
      case ChatFollowUp.askAnother:
        FocusScope.of(context).requestFocus(FocusNode());
    }
  }

  void _clearConversation() {
    _conversation.clear();
    setState(() {
      _messages
        ..clear()
        ..add(
          const ChatMessage(
            author: ChatAuthor.companion,
            text: 'What would you like to know?',
          ),
        );
    });
  }

  void _scrollToEnd() {
    // After the frame, so the new message has been laid out and its extent
    // is known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.aiService.isGenerative;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Companion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Start again',
            onPressed: _clearConversation,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: _StatusStrip(isOnline: isOnline),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSizes.pagePadding),
                      itemCount: _messages.length + (_isThinking ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const _ThinkingBubble();
                        }
                        return _MessageBubble(
                          message: _messages[index],
                          onFollowUp: _handleFollowUp,
                          onRetry: () => _send(_lastQuestion),
                        );
                      },
                    ),
                  ),
                  if (_chips.isNotEmpty && _messages.length <= 2)
                    _SuggestionChips(
                      suggestions: _chips,
                      onTap: _handleChip,
                    ),
                  _Composer(
                    controller: _inputController,
                    speech: widget.speech,
                    isThinking: _isThinking,
                    onSend: () => _send(_inputController.text),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The subtle online/offline line. Deliberately small and non-technical.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: AppSizes.pagePadding, bottom: 8),
      color: AppColors.primary,
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.circle : Icons.circle_outlined,
            size: 12,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'Smart answers on' : 'Offline — saved memories only',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onFollowUp,
    required this.onRetry,
  });

  final ChatMessage message;
  final ValueChanged<ChatFollowUp> onFollowUp;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gap),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.85,
            ),
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              color: isUser ? AppColors.primarySoft : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(
                color: isUser ? AppColors.primary : AppColors.border,
                width: isUser ? 2 : 1.5,
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                fontSize: isUser ? 20 : 22,
                height: 1.4,
                fontWeight: isUser ? FontWeight.w500 : FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          if (!isUser && message.kind != AnswerKind.plain) ...[
            const SizedBox(height: 6),
            _KindBadge(kind: message.kind),
          ],

          if (!isUser && message.source != AnswerSource.none) ...[
            const SizedBox(height: 4),
            _SourceLine(source: message.source, delivery: message.delivery),
          ] else if (!isUser && message.delivery != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                message.delivery!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],

          if (message.isError) ...[
            const SizedBox(height: AppSizes.gapSmall),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 24),
              label: const Text('Try again'),
            ),
          ],

          if (message.followUps.isNotEmpty) ...[
            const SizedBox(height: AppSizes.gapSmall),
            Wrap(
              spacing: AppSizes.gapSmall,
              runSpacing: AppSizes.gapSmall,
              children: [
                for (final followUp in message.followUps)
                  _FollowUpButton(
                    followUp: followUp,
                    onTap: () => onFollowUp(followUp),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The visible line between "about you" and "about memory in general".
///
/// Requirement 12/13. Without this, a general sentence about dementia sitting
/// in the same conversation as "Rahul is your son" could be read as a
/// statement about the user. The badge makes the difference impossible to miss.
class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final AnswerKind kind;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (kind) {
      AnswerKind.personal => (
        Icons.favorite_rounded,
        'From your memories',
        AppColors.primaryDark,
      ),
      AnswerKind.education => (
        Icons.menu_book_rounded,
        'General information - not about you',
        AppColors.activity,
      ),
      AnswerKind.general => (
        Icons.public_rounded,
        'General knowledge',
        AppColors.memory,
      ),
      AnswerKind.safety => (
        Icons.health_and_safety_outlined,
        'Not a medical opinion',
        AppColors.reminder,
      ),
      AnswerKind.plain => (
        Icons.chat_bubble_outline,
        '',
        AppColors.textSecondary,
      ),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Says which part of the vault the answer came from, and how it was produced.
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.source, required this.delivery});

  final AnswerSource source;
  final String? delivery;

  @override
  Widget build(BuildContext context) {
    final label = switch (source) {
      AnswerSource.person => 'From your saved People',
      AnswerSource.place => 'From your saved Places',
      AnswerSource.note => 'From your saved Notes',
      AnswerSource.collection => 'Counted from everything you have saved',
      AnswerSource.none => '',
    };

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (delivery != null)
            Text(
              delivery!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _FollowUpButton extends StatelessWidget {
  const _FollowUpButton({required this.followUp, required this.onTap});

  final ChatFollowUp followUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label) = switch (followUp) {
      ChatFollowUp.playGame => (Icons.videogame_asset_rounded, 'Play a game'),
      ChatFollowUp.viewReminders => (Icons.alarm_rounded, 'View reminders'),
      ChatFollowUp.openMemoryAid => (Icons.folder_shared_rounded, 'Open Memory Aid'),
      ChatFollowUp.askAnother => (Icons.edit_rounded, 'Ask another question'),
    };

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      icon: Icon(icon, size: 22),
      label: Text(label),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.gap),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(width: AppSizes.gap),
                Text(
                  'Looking through your memories...',
                  style: TextStyle(fontSize: 19, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({required this.suggestions, required this.onTap});

  final List<AiSuggestion> suggestions;
  final ValueChanged<AiSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        0,
        AppSizes.pagePadding,
        AppSizes.gapSmall,
      ),
      child: Wrap(
        spacing: AppSizes.gapSmall,
        runSpacing: AppSizes.gapSmall,
        children: [
          for (final suggestion in suggestions)
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => onTap(suggestion),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: suggestion.color, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(suggestion.icon, size: 24, color: suggestion.color),
                      const SizedBox(width: 10),
                      Text(
                        suggestion.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.speech,
    required this.isThinking,
    required this.onSend,
  });

  final TextEditingController controller;
  final SpeechToTextService speech;
  final bool isThinking;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.gap),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(
        children: [
          // The microphone is shown but disabled, with the reason stated.
          // Hiding it would misrepresent the design; enabling a button that
          // does nothing would be worse.
          if (!speech.isAvailable)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.gapSmall),
              child: Row(
                children: [
                  const Icon(
                    Icons.mic_off_rounded,
                    size: 22,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      speech.unavailableReason,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 20),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Type your question',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.gapSmall),
              SizedBox(
                width: 64,
                height: 64,
                child: FilledButton(
                  onPressed: isThinking ? null : onSend,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.send_rounded, size: 30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
