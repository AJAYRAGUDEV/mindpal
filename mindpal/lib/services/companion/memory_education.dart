/// A section of the "Learn About Memory" material.
enum EducationCategory {
  basics('Memory Basics'),
  memoryLoss('Memory Loss'),
  dementia('Dementia'),
  everyday('Everyday Support');

  const EducationCategory(this.label);

  final String label;
}

class EducationTopic {
  const EducationTopic({
    required this.category,
    required this.question,
    required this.answer,
    this.keywords = const [],
  });

  final EducationCategory category;
  final String question;
  final String answer;

  /// Extra words that should match this topic in a free-typed question.
  final List<String> keywords;
}

/// General information about memory, written to be read aloud to an elderly
/// user.
///
/// WHY THIS EXISTS AS FIXED TEXT rather than always asking a model:
///   * it works with no internet, like the rest of the app;
///   * it is reviewable — a person can read these fourteen answers and check
///     every one, which is impossible for generated text;
///   * it costs nothing and is instant.
///
/// Gemini still handles questions outside this set when online. This is the
/// floor, not the ceiling.
///
/// NOTHING HERE DIAGNOSES ANYTHING. Every answer that touches a condition ends
/// by pointing at a qualified professional, and none of them tells the reader
/// what is or is not happening to them.
class MemoryEducation {
  const MemoryEducation();

  /// Appended to educational answers that touch health.
  static const String professionalNote =
      'Only a qualified healthcare professional can say what is causing '
      'memory difficulties for a particular person.';

  static const List<EducationTopic> topics = [
    // -------------------------------------------------------------- basics
    EducationTopic(
      category: EducationCategory.basics,
      question: 'What is memory?',
      answer:
          'Memory is how the brain takes in information, keeps it, and brings '
          'it back later.\n\n'
          'It works in stages: noticing something, storing it, and then '
          'recalling it when you need it.',
      keywords: ['what is memory', 'how memory works'],
    ),
    EducationTopic(
      category: EducationCategory.basics,
      question: 'What is short-term memory?',
      answer:
          'Short-term memory holds a small amount of information for a short '
          'time — like a phone number you have just been told.\n\n'
          'Long-term memory holds information for much longer, sometimes for '
          'a whole lifetime.',
      keywords: ['short term memory', 'long term memory'],
    ),
    EducationTopic(
      category: EducationCategory.basics,
      question: 'Why do we forget things?',
      answer:
          'Forgetting is normal and happens to everyone.\n\n'
          'It is more likely when you are distracted, tired, stressed, unwell, '
          'or doing several things at once. Information you never fully paid '
          'attention to is harder to recall later.',
      keywords: ['why do we forget', 'why do people forget', 'forgetting'],
    ),

    // --------------------------------------------------------- memory loss
    EducationTopic(
      category: EducationCategory.memoryLoss,
      question: 'What is memory loss?',
      answer:
          'Memory loss means having difficulty remembering things a person '
          'could remember before.\n\n'
          'Occasional forgetting happens to many people. Memory difficulties '
          'that are persistent, or that get worse over time, are worth '
          'discussing with a doctor.\n\n$professionalNote',
      keywords: ['memory loss', 'what is memory loss'],
    ),
    EducationTopic(
      category: EducationCategory.memoryLoss,
      question: 'What can affect memory?',
      answer:
          'Many everyday things can affect memory, including poor sleep, '
          'stress, low mood, some illnesses, dehydration, and certain '
          'medicines.\n\n'
          'Some medical conditions also affect memory.\n\n$professionalNote',
      keywords: ['what affects memory', 'what can affect memory', 'causes'],
    ),
    EducationTopic(
      category: EducationCategory.memoryLoss,
      question: 'When should someone talk to a doctor?',
      answer:
          'It is worth speaking to a doctor when memory difficulties are '
          'getting worse, happening often, or making everyday tasks harder — '
          'for example getting lost somewhere familiar, or having trouble '
          'managing money or medicines.\n\n'
          'A sudden change in memory or confusion should be checked urgently.',
      keywords: ['see a doctor', 'talk to a doctor', 'when should someone'],
    ),

    // ------------------------------------------------------------ dementia
    EducationTopic(
      category: EducationCategory.dementia,
      question: 'What is dementia?',
      answer:
          'Dementia is a word for a group of symptoms that can include '
          'difficulty with memory, thinking, language and daily tasks.\n\n'
          'It is caused by changes in the brain, and there are several '
          'different types. It is not a normal part of getting older.\n\n'
          '$professionalNote',
      keywords: ['what is dementia', 'dementia'],
    ),
    EducationTopic(
      category: EducationCategory.dementia,
      question: "What is Alzheimer's disease?",
      answer:
          "Alzheimer's disease is the most common cause of dementia.\n\n"
          'It usually begins gradually and often affects recent memory first. '
          'Other types of dementia have different causes and patterns.\n\n'
          '$professionalNote',
      keywords: ['alzheimer', 'alzheimers'],
    ),
    EducationTopic(
      category: EducationCategory.dementia,
      question: 'Are dementia and normal ageing the same?',
      answer:
          'No. Many people notice they are a little slower to recall a name '
          'or a word as they get older, and that is common.\n\n'
          'Dementia is different: the changes are greater and they interfere '
          'with everyday life.\n\n$professionalNote',
      keywords: ['normal ageing', 'normal aging', 'difference between'],
    ),

    // ------------------------------------------------------------ everyday
    EducationTopic(
      category: EducationCategory.everyday,
      question: 'How can I stay mentally active?',
      answer:
          'Things that keep the mind engaged include reading, puzzles and '
          'memory activities, learning something new, conversation, and '
          'staying socially and physically active.\n\n'
          'These support general engagement and wellbeing. They are not a '
          'treatment for dementia or any other medical condition.',
      keywords: [
        'stay mentally active',
        'exercise my memory',
        'exercise my brain',
        'improve my memory',
        'memory exercises',
      ],
    ),
    EducationTopic(
      category: EducationCategory.everyday,
      question: 'Why is sleep important for memory?',
      answer:
          'Sleep is when the brain settles what it has learned during the day.\n\n'
          'Regular, good-quality sleep helps with attention and recall. Poor '
          'sleep makes forgetting more likely for anyone.',
      keywords: ['sleep', 'why is sleep', 'how does sleep'],
    ),
    EducationTopic(
      category: EducationCategory.everyday,
      question: 'How can reminders help?',
      answer:
          'Written notes, alarms and reminders take the effort of remembering '
          'off the person and put it somewhere reliable.\n\n'
          'Using them is a sensible everyday habit, not a sign that anything '
          'is wrong.',
      keywords: ['how can reminders help', 'reminders help'],
    ),
  ];

  /// The best curated answer for a free-typed question, or null.
  ///
  /// Scoring is deliberately simple: a keyword match beats a partial title
  /// match. When nothing scores, this returns null and the caller decides
  /// whether to ask Gemini (online) or say it does not know (offline).
  EducationTopic? offlineAnswerFor(String question) {
    final text = _normalise(question);
    if (text.isEmpty) return null;

    EducationTopic? best;
    var bestScore = 0;

    for (final topic in topics) {
      var score = 0;
      for (final keyword in topic.keywords) {
        if (text.contains(_normalise(keyword))) score = 3;
      }
      if (score == 0 && text.contains(_normalise(topic.question))) score = 2;

      if (score > bestScore) {
        bestScore = score;
        best = topic;
      }
    }
    return best;
  }

  /// The answer for a question about the user's OWN health.
  ///
  /// This is a fixed template and never goes near a language model. That is
  /// the whole point: a prompt asking a model not to diagnose is a request,
  /// while returning written text is a guarantee. There is no code path where
  /// "Do I have dementia?" produces a generated answer.
  String safeAnswerFor(String question) {
    final text = _normalise(question);

    // "Why am I forgetting things?" — a worry about symptoms. Give the
    // general, non-diagnostic information plus where to go next.
    const symptomPhrases = [
      'why am i forgetting',
      'why do i forget',
      'why cant i remember',
      'why can i not remember',
      'is my memory',
      'my memory getting',
      'my memory worse',
    ];

    if (symptomPhrases.any(text.contains)) {
      return 'Forgetting things can have many everyday causes, such as being '
          'distracted, tired, stressed or unwell.\n\n'
          'I cannot tell you why it is happening for you. If it is happening '
          'often, or getting worse, it is worth talking it over with a '
          'doctor.';
    }

    // "Do I have dementia?" — a request for a diagnosis. Decline plainly,
    // without alarming the user and without dismissing the question.
    return 'I am not able to assess anyone\'s health, and I cannot tell you '
        'whether you have a condition.\n\n'
        'I can explain general information about memory, and I can help with '
        'the things you have saved here.\n\n'
        'If you are worried about changes in your memory, please talk to a '
        'doctor or nurse — they can look into it properly.';
  }

  List<EducationTopic> topicsIn(EducationCategory category) =>
      topics.where((topic) => topic.category == category).toList();

  String _normalise(String text) => text
      .toLowerCase()
      .replaceAll("'", '')
      .replaceAll(String.fromCharCode(0x2019), '')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
