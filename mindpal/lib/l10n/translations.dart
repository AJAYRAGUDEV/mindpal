import 'app_strings.dart';

/// The translation tables, keyed by language code.
///
/// IMPORTANT AND HONEST: the Assamese, Bengali and Nepali tables below are
/// DRAFT translations. They were produced during development and have NOT been
/// checked by a native speaker. That is exactly why those languages are marked
/// `CapabilityStatus.draft` and not `verified` in app_language.dart, and why
/// the app tells the user so on the language screen.
///
/// Getting these reviewed is a real task for the team, not a formality —
/// a wrong word in a medicine reminder is a safety problem, not a typo.
///
/// Bodo, Meitei, Mizo, Khasi, Garo and Kokborok have NO table here. They are
/// deliberately still listed in the language picker so the architecture and
/// the intent are visible, and the app falls back to English for them with a
/// clear on-screen notice. Adding one is purely a matter of adding a map here
/// and flipping that language's `ui` status — no screen changes at all.
const Map<String, Map<String, String>> kTranslations = {
  'en': kEnglishStrings,
  'as': kAssameseStrings,
  'bn': kBengaliStrings,
  'ne': kNepaliStrings,
};

/// Assamese — অসমীয়া. DRAFT, needs native review.
const Map<String, String> kAssameseStrings = {
  'nav_home': 'ঘৰ',
  'nav_games': 'মাইণ্ডপাল',
  'nav_reminders': 'সোঁৱৰণী',
  'nav_memory': 'স্মৃতি',
  'nav_profile': 'প্ৰ’ফাইল',

  'title_home': 'মাইণ্ডপাল',
  'title_games': 'মাইণ্ডপাল খেল',
  'title_reminders': 'সোঁৱৰণী',
  'title_memory': 'স্মৃতি সহায়',
  'title_profile': 'মোৰ প্ৰ’ফাইল',

  'greeting_morning': 'শুভ ৰাতিপুৱা',
  'greeting_afternoon': 'শুভ আবেলি',
  'greeting_evening': 'শুভ সন্ধিয়া',
  'friend': 'বন্ধু',

  'todays_overview': 'আজিৰ সাৰাংশ',
  'quick_actions': 'দ্ৰুত কাম',

  'cognitive_activity': 'মানসিক কাৰ্যকলাপ',
  'cognitive_activity_message':
      'আজি এতিয়ালৈকে কোনো কাম হোৱা নাই। এটা চুটি খেলে মনটো সজীৱ ৰাখে।',
  'todays_reminders': 'আজিৰ সোঁৱৰণী',
  'todays_reminders_message': 'আপুনি যোগ কৰা সোঁৱৰণীবোৰ ইয়াত দেখা যাব।',
  'memory_assistance': 'স্মৃতি সহায়',
  'memory_assistance_message':
      'আপুনি মনত ৰাখিব বিচৰা মানুহ, ঠাই আৰু টোকা ৰাখক।',

  'play_mindpal': 'মাইণ্ডপাল খেলক',
  'view_reminders': 'সোঁৱৰণী চাওক',
  'memory_aid': 'স্মৃতি সহায়',

  'save': 'সংৰক্ষণ কৰক',
  'cancel': 'বাতিল কৰক',
  'delete': 'মচি পেলাওক',
  'try_again': 'পুনৰ চেষ্টা কৰক',

  'memory_assistant': 'স্মৃতি সহায়ক',
  'play_a_game': 'এটা খেল খেলক',
  'my_memories': 'মোৰ স্মৃতি',
  'my_reminders': 'মোৰ সোঁৱৰণী',
  'todays_activity': 'আজিৰ কাৰ্যকলাপ',
  'upcoming': 'আগন্তুক',
  'no_activity_yet': 'আজি এতিয়ালৈকে একো হোৱা নাই',
  'no_reminders_today': 'আজিৰ বাবে কোনো সোঁৱৰণী নাই',
  'activities_completed': 'কাৰ্যকলাপ সম্পূৰ্ণ',
  'reminders_remaining': 'সোঁৱৰণী বাকী',
  'all_done_today': 'আজিৰ বাবে সকলো সম্পূৰ্ণ',

  'personalized_game': 'স্মৃতিৰ মুহূৰ্ত',
  'personalized_game_description': 'আপোনাৰ নিজৰ সংৰক্ষিত স্মৃতিৰ পৰা কৰা প্ৰশ্ন।',
  'play_personalized_game': 'স্মৃতিৰ মুহূৰ্ত খেলক',
  'lets_remember': 'আহক একেলগে মনত পেলাওঁ',
  'great_job': 'বহুত ভাল!',
  'nice_try': 'ভাল চেষ্টা। আগবাঢ়ি যাওঁ আহক।',
  'the_answer_was': 'উত্তৰটো আছিল',
  'next_question': 'পৰৱৰ্তী প্ৰশ্ন',
  'see_result': 'ফলাফল চাওক',
  'well_done': 'সাব্বাস!',
  'activity_result': 'কাৰ্যকলাপৰ ফলাফল',
  'you_completed_game': 'আপুনি খেলখন সম্পূৰ্ণ কৰিলে',
  'play_again': 'পুনৰ খেলক',
  'back_to_home': 'ঘৰলৈ উভতি যাওক',
  'created_from_memories': 'এই খেলখন আপোনাৰ সংৰক্ষিত স্মৃতিৰ পৰা তৈয়াৰ কৰা হৈছে।',
  'need_more_memories': 'আৰু কেইটামান স্মৃতিৰ প্ৰয়োজন',
  'need_more_memories_hint': 'ব্যক্তিগত খেল তৈয়াৰ কৰিবলৈ আৰু মানুহ বা ঠাই যোগ কৰক।',
  'add_memories': 'স্মৃতি যোগ কৰক',

  'odd_one_out': 'বেলেগটো বিচাৰক',
  'odd_one_out_description': 'যিটো নিমিলে সেইটো বিচাৰি উলিয়াওক।',
  'play_odd_one_out': 'বেলেগটো বিচাৰি খেলক',
  'which_is_different': 'কোনটো বেলেগ?',
  'round_label': 'ৰাউণ্ড',

  'choose_language': 'আপোনাৰ ভাষা বাছনি কৰক',
  'choose_language_subtitle': 'মাইণ্ডপালে গোটেই এপত এই ভাষা ব্যৱহাৰ কৰিব।',
  'app_language': 'এপৰ ভাষা',
  'translation_pending': 'অনুবাদ সোনকালে আহিব। এতিয়া ইংৰাজী দেখুওৱা হ’ব।',
  'translation_draft': 'অনুবাদ কৰা হৈছে — স্থানীয় বক্তাৰ পৰীক্ষাৰ বাবে বাকী।',
  'view_capabilities': 'কোন ভাষাত কি কাম কৰে?',
  'capability_title': 'ভাষাৰ সক্ষমতা',
  'selected': 'বাছনি কৰা হৈছে',
};

/// Bengali — বাংলা. DRAFT, needs native review.
const Map<String, String> kBengaliStrings = {
  'nav_home': 'হোম',
  'nav_games': 'মাইন্ডপাল',
  'nav_reminders': 'অনুস্মারক',
  'nav_memory': 'স্মৃতি',
  'nav_profile': 'প্রোফাইল',

  'title_home': 'মাইন্ডপাল',
  'title_games': 'মাইন্ডপাল খেলা',
  'title_reminders': 'অনুস্মারক',
  'title_memory': 'স্মৃতি সহায়তা',
  'title_profile': 'আমার প্রোফাইল',

  'greeting_morning': 'সুপ্রভাত',
  'greeting_afternoon': 'শুভ অপরাহ্ন',
  'greeting_evening': 'শুভ সন্ধ্যা',
  'friend': 'বন্ধু',

  'todays_overview': 'আজকের সারসংক্ষেপ',
  'quick_actions': 'দ্রুত কাজ',

  'cognitive_activity': 'মানসিক কার্যকলাপ',
  'cognitive_activity_message':
      'আজ এখনও কিছু করা হয়নি। একটি ছোট খেলা মনকে সজাগ রাখে।',
  'todays_reminders': 'আজকের অনুস্মারক',
  'todays_reminders_message': 'আপনার যোগ করা অনুস্মারক এখানে দেখা যাবে।',
  'memory_assistance': 'স্মৃতি সহায়তা',
  'memory_assistance_message':
      'আপনি মনে রাখতে চান এমন মানুষ, স্থান ও নোট রাখুন।',

  'play_mindpal': 'মাইন্ডপাল খেলুন',
  'view_reminders': 'অনুস্মারক দেখুন',
  'memory_aid': 'স্মৃতি সহায়তা',

  'save': 'সংরক্ষণ করুন',
  'cancel': 'বাতিল করুন',
  'delete': 'মুছে ফেলুন',
  'try_again': 'আবার চেষ্টা করুন',

  'memory_assistant': 'স্মৃতি সহায়ক',
  'play_a_game': 'একটি খেলা খেলুন',
  'my_memories': 'আমার স্মৃতি',
  'my_reminders': 'আমার অনুস্মারক',
  'todays_activity': 'আজকের কার্যকলাপ',
  'upcoming': 'আসন্ন',
  'no_activity_yet': 'আজ এখনও কিছু হয়নি',
  'no_reminders_today': 'আজকের জন্য কোনো অনুস্মারক নেই',
  'activities_completed': 'কার্যকলাপ সম্পন্ন',
  'reminders_remaining': 'অনুস্মারক বাকি',
  'all_done_today': 'আজকের সব শেষ',

  'personalized_game': 'স্মৃতির মুহূর্ত',
  'personalized_game_description': 'আপনার নিজের সংরক্ষিত স্মৃতি থেকে করা প্রশ্ন।',
  'play_personalized_game': 'স্মৃতির মুহূর্ত খেলুন',
  'lets_remember': 'চলুন একসাথে মনে করি',
  'great_job': 'দারুণ হয়েছে!',
  'nice_try': 'ভালো চেষ্টা। চলুন এগিয়ে যাই।',
  'the_answer_was': 'উত্তরটি ছিল',
  'next_question': 'পরবর্তী প্রশ্ন',
  'see_result': 'ফলাফল দেখুন',
  'well_done': 'খুব ভালো!',
  'activity_result': 'কার্যকলাপের ফলাফল',
  'you_completed_game': 'আপনি খেলাটি শেষ করেছেন',
  'play_again': 'আবার খেলুন',
  'back_to_home': 'হোমে ফিরে যান',
  'created_from_memories': 'এই খেলাটি আপনার সংরক্ষিত স্মৃতি থেকে তৈরি হয়েছে।',
  'need_more_memories': 'আরও কয়েকটি স্মৃতি প্রয়োজন',
  'need_more_memories_hint': 'ব্যক্তিগত খেলা তৈরি করতে আরও মানুষ বা স্থান যোগ করুন।',
  'add_memories': 'স্মৃতি যোগ করুন',

  'odd_one_out': 'আলাদাটি খুঁজুন',
  'odd_one_out_description': 'যেটি মেলে না সেটি খুঁজে বের করুন।',
  'play_odd_one_out': 'আলাদাটি খুঁজে খেলুন',
  'which_is_different': 'কোনটি আলাদা?',
  'round_label': 'রাউন্ড',

  'choose_language': 'আপনার ভাষা বেছে নিন',
  'choose_language_subtitle': 'মাইন্ডপাল পুরো অ্যাপে এই ভাষা ব্যবহার করবে।',
  'app_language': 'অ্যাপের ভাষা',
  'translation_pending': 'অনুবাদ শীঘ্রই আসছে। আপাতত ইংরেজি দেখানো হবে।',
  'translation_draft': 'অনুবাদ হয়েছে — স্থানীয় ভাষাভাষীর পর্যালোচনা বাকি।',
  'view_capabilities': 'কোন ভাষায় কী কাজ করে?',
  'capability_title': 'ভাষার সক্ষমতা',
  'selected': 'নির্বাচিত',
};

/// Nepali — नेपाली. DRAFT, needs native review.
const Map<String, String> kNepaliStrings = {
  'nav_home': 'गृह',
  'nav_games': 'माइन्डपाल',
  'nav_reminders': 'सम्झना',
  'nav_memory': 'स्मृति',
  'nav_profile': 'प्रोफाइल',

  'title_home': 'माइन्डपाल',
  'title_games': 'माइन्डपाल खेल',
  'title_reminders': 'सम्झना',
  'title_memory': 'स्मृति सहयोग',
  'title_profile': 'मेरो प्रोफाइल',

  'greeting_morning': 'शुभ प्रभात',
  'greeting_afternoon': 'शुभ अपराह्न',
  'greeting_evening': 'शुभ सन्ध्या',
  'friend': 'साथी',

  'todays_overview': 'आजको सारांश',
  'quick_actions': 'छिटो कामहरू',

  'cognitive_activity': 'मानसिक क्रियाकलाप',
  'cognitive_activity_message':
      'आज अहिलेसम्म केही गरिएको छैन। छोटो खेलले मनलाई सक्रिय राख्छ।',
  'todays_reminders': 'आजका सम्झनाहरू',
  'todays_reminders_message': 'तपाईंले थपेका सम्झनाहरू यहाँ देखिनेछन्।',
  'memory_assistance': 'स्मृति सहयोग',
  'memory_assistance_message':
      'तपाईंले सम्झन चाहेका मानिस, ठाउँ र टिपोटहरू राख्नुहोस्।',

  'play_mindpal': 'माइन्डपाल खेल्नुहोस्',
  'view_reminders': 'सम्झनाहरू हेर्नुहोस्',
  'memory_aid': 'स्मृति सहयोग',

  'save': 'सुरक्षित गर्नुहोस्',
  'cancel': 'रद्द गर्नुहोस्',
  'delete': 'मेटाउनुहोस्',
  'try_again': 'फेरि प्रयास गर्नुहोस्',

  'memory_assistant': 'स्मृति सहायक',
  'play_a_game': 'एउटा खेल खेल्नुहोस्',
  'my_memories': 'मेरा स्मृतिहरू',
  'my_reminders': 'मेरा सम्झनाहरू',
  'todays_activity': 'आजको क्रियाकलाप',
  'upcoming': 'आउँदै',
  'no_activity_yet': 'आज अहिलेसम्म केही भएको छैन',
  'no_reminders_today': 'आजका लागि कुनै सम्झना छैन',
  'activities_completed': 'क्रियाकलाप पूरा',
  'reminders_remaining': 'सम्झनाहरू बाँकी',
  'all_done_today': 'आजको सबै सकियो',

  'personalized_game': 'स्मृतिको क्षण',
  'personalized_game_description': 'तपाईंका आफ्नै सुरक्षित स्मृतिहरूबाट बनेका प्रश्नहरू।',
  'play_personalized_game': 'स्मृतिको क्षण खेल्नुहोस्',
  'lets_remember': 'सँगै सम्झौं',
  'great_job': 'धेरै राम्रो!',
  'nice_try': 'राम्रो प्रयास। अगाडि बढौं।',
  'the_answer_was': 'उत्तर थियो',
  'next_question': 'अर्को प्रश्न',
  'see_result': 'नतिजा हेर्नुहोस्',
  'well_done': 'शाबास!',
  'activity_result': 'क्रियाकलापको नतिजा',
  'you_completed_game': 'तपाईंले खेल पूरा गर्नुभयो',
  'play_again': 'फेरि खेल्नुहोस्',
  'back_to_home': 'गृहमा फर्कनुहोस्',
  'created_from_memories': 'यो खेल तपाईंका सुरक्षित स्मृतिहरूबाट बनाइएको हो।',
  'need_more_memories': 'केही थप स्मृतिहरू चाहिन्छ',
  'need_more_memories_hint': 'व्यक्तिगत खेल बनाउन थप मानिस वा ठाउँ थप्नुहोस्।',
  'add_memories': 'स्मृति थप्नुहोस्',

  'odd_one_out': 'फरक पत्ता लगाउनुहोस्',
  'odd_one_out_description': 'नमिल्ने चित्र पत्ता लगाउनुहोस्।',
  'play_odd_one_out': 'फरक पत्ता लगाएर खेल्नुहोस्',
  'which_is_different': 'कुन चाहिँ फरक छ?',
  'round_label': 'राउन्ड',

  'choose_language': 'आफ्नो भाषा छान्नुहोस्',
  'choose_language_subtitle': 'माइन्डपालले सम्पूर्ण एपमा यही भाषा प्रयोग गर्नेछ।',
  'app_language': 'एपको भाषा',
  'translation_pending': 'अनुवाद चाँडै आउँदैछ। अहिलेलाई अङ्ग्रेजी देखाइनेछ।',
  'translation_draft': 'अनुवाद भयो — स्थानीय वक्ताको समीक्षा बाँकी।',
  'view_capabilities': 'कुन भाषामा के काम गर्छ?',
  'capability_title': 'भाषा क्षमताहरू',
  'selected': 'छानिएको',
};
