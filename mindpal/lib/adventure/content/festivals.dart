/// The festivals an adventure can be set at.
///
/// Two, and both were written with care rather than generated. Adding a third
/// is one `FestivalSkin` in this file and one line in [kFestivals] — no code,
/// no new screens, and the validator and solver run over it automatically.
///
/// **Both are marked unreviewed.** The facts in each note are widely published,
/// but nobody from Tamil Nadu has read the Pongal one and nobody from Assam has
/// read the Bihu one. The app says so before play begins.
library;

import 'package:flutter/material.dart';

import '../model/adventure.dart';
import '../generation/adventure_variation.dart';
import 'festival_skin.dart';
import 'pongal_adventure.dart';

/// Pongal, as the bundled adventure already tells it.
///
/// An empty skin: the skeleton IS the Pongal adventure, so there is nothing to
/// lay over it. It appears in the chooser as an equal option rather than as a
/// special case.
final FestivalSkin kPongalFestival = FestivalSkin(
  id: 'pongal',
  name: 'Pongal',
  region: 'Tamil Nadu',
  blurb: 'Rice boiled with milk and jaggery until the pot goes over, and a '
      'kolam at the door.',
  icon: Icons.soup_kitchen_rounded,
  colour: const Color(0xFFB26500),
  culturalNote: kPongalAdventure.culturalNote,
);

/// Bohag Bihu, the Assamese spring festival.
///
/// The objects come from the same curated Assam reference used by the cultural
/// packs elsewhere in this app — pitha, gur, gamosa, japi, bell metal, bora
/// rice — so the two features cannot disagree about what a japi is.
///
/// The cattle detail is not decoration: the first day of Bohag Bihu is Goru
/// Bihu, when the cattle are washed, rubbed with turmeric and thanked. Bipul
/// asking to bring the cows in is the festival, not a flourish.
const FestivalSkin kBihuFestival = FestivalSkin(
  id: 'bihu',
  name: 'Bohag Bihu',
  region: 'Assam',
  blurb: 'Pitha steaming, a gamosa for the elders, and the cattle brought in '
      'with bells.',
  icon: Icons.music_note_rounded,
  colour: Color(0xFF2E7D32),
  culturalNote: CulturalNote(
    festival: 'Bohag Bihu',
    region: 'Assam, North-East India',
    summary:
        'Bohag Bihu is the Assamese new year and spring festival, held in '
        'mid-April over several days. The first day is Goru Bihu, when the '
        'cattle are washed in the river, rubbed with turmeric and thanked for '
        'their work. The days that follow are for visiting: younger people '
        'give a handwoven gamosa to their elders as a mark of respect, rice '
        'cakes called pitha and coconut sweets called laru are made, and the '
        'dhol and pepa are played for the Bihu dance.',
    references: [
      'The village and everyone in this story are invented. Only the festival '
          'is real.',
      'Still to be checked by an Assamese reviewer. Suggested sources: '
          'Government of Assam cultural publications on Bohag Bihu, and a '
          'standard reference on Assamese cooking for pitha, laru and jolpan.',
    ],
  ),

  // ------------------------------------------------------------- the things
  //
  // Same ids, same prices, same mechanical roles. Only the names, the
  // descriptions and the pictures change.
  itemLabels: {
    'clay_pot': (
      name: 'Earthen pot',
      description:
          'A round clay pot. The pitha are steamed over water in one of these.',
      icon: Icons.soup_kitchen_rounded,
    ),
    'brass_pot': (
      name: 'Bell-metal pot',
      description:
          'Beaten bell metal, heavier than the clay one and it shines. It '
          'costs more and does the job just as well.',
      icon: Icons.emoji_food_beverage_rounded,
    ),
    'rice': (
      name: 'Bora rice',
      description:
          'Sticky rice, ground into flour. This is what pitha are made from.',
      icon: Icons.rice_bowl_rounded,
    ),
    'jaggery': (
      name: 'Gur',
      description:
          'Dark cane jaggery in a round cake. It goes inside the pitha with '
          'the coconut.',
      icon: Icons.cookie_rounded,
    ),
    'palm_sugar': (
      name: 'Grated coconut',
      description:
          'Fresh coconut, already grated. Cooked with a little sugar it fills '
          'a pitha just as well as gur does.',
      icon: Icons.bakery_dining_rounded,
    ),
    'milk': (
      name: 'Curd',
      description:
          'Thick curd in a covered pot, for the jolpan in the morning.',
      icon: Icons.local_drink_rounded,
    ),
    'sugarcane': (
      name: 'Gamosa',
      description:
          'A white handwoven cloth with red at the ends. You give one to your '
          'elders at Bihu, folded, in both hands.',
      icon: Icons.checkroom_rounded,
    ),
    'stencil': (
      name: 'Japi',
      description:
          'A wide cone woven from bamboo and dried leaves, worked in colours. '
          'A decorated one is hung up, or given.',
      icon: Icons.umbrella_rounded,
    ),
  },

  locationLabels: {
    'square': (
      name: 'Village square',
      description:
          'A swept open square with a well in the middle. The road to the '
          'market runs off to the left, and the gate to the namghar courtyard '
          'is on the right.',
    ),
    'market': (
      name: 'Bihu market',
      description:
          'Three stalls under cloth awnings, and more noise than the rest of '
          'the village put together. Everything smells of wet bamboo.',
    ),
    'courtyard': (
      name: 'Namghar courtyard',
      description:
          'The open ground beside the prayer house, swept flat, with a low '
          'fire laid ready and a wide doorway with nothing hanging over it.',
    ),
  },

  slotLabels: {
    'slot_fire': (
      label: 'On the fire',
      filledText:
          'The pot goes on the fire with water underneath, and the first pitha '
          'go in to steam.',
    ),
    'slot_doorway': (
      label: 'Above the doorway',
      filledText:
          'Rupali hangs the japi over the doorway, and the whole courtyard '
          'looks like Bihu at once.',
    ),
    'slot_pillar': (
      label: 'Folded on the seat',
      filledText:
          'The gamosa is folded in three and set on the seat, ready to be '
          'given with both hands.',
    ),
  },

  styleLabels: {
    'style_plain': (
      name: 'Plain and swept',
      description: 'Bare ground, well swept. Let the japi do the talking.',
    ),
    'style_colour': (
      name: 'Full of colour',
      description: 'Every coloured japi Rupali has, all along the wall.',
    ),
    'style_lamps': (
      name: 'Ringed with lamps',
      description: 'Small earthen lamps all round the courtyard, for dusk.',
    ),
  },

  stallNames: {
    'pottery': 'Dhaniram’s pots',
    'grain': 'The rice and sweet stall',
    'dairy': 'The curd pots',
  },

  clueSources: {
    'clue_basket': 'Told by Rupali',
    'clue_dawn': 'Told by Bipul',
    'clue_board': 'Seen at the market',
  },

  // -------------------------------------------------------------- the words
  text: {
    'title': 'The Japi Above the Door',
    'intro':
        'It is Bohag Bihu in the village of Xoruguri, and the courtyard by the '
        'namghar is not ready. The fire is laid, the ground is swept, and '
        'Nirmali is standing in the square with an empty pot and a worried '
        'look. There is a great deal to do before the guests come — and '
        'the japi that should be hanging over the doorway is not there at all.',
    'objective':
        'Help Nirmali and the village of Xoruguri get ready for Bohag Bihu.',

    // ----- Nirmali (was Ammal)
    'char.ammal.name': 'Nirmali',
    'char.ammal.role': 'She is making the pitha',
    'node.ammal.ammal_done.line.0': 'You have everything. Look at it all!',
    'node.ammal.ammal_done.line.1':
        'Take it to the courtyard and we can begin. Rupali is there — she '
        'will know where things go.',
    'node.ammal.ammal_shopping.line.0':
        'Still at the market? Take your time. The fire will keep.',
    'choice.ammal.ammal_shopping.ammal_repeat.text':
        'Tell me the list again.',
    'node.ammal.ammal_list.line.0':
        'A pot to steam the pitha in. Bora rice, ground fine, not the ordinary '
        'sort.',
    'node.ammal.ammal_list.line.1':
        'Something sweet for the filling. Curd for the jolpan. And a gamosa '
        '— a good one, to give.',
    'node.ammal.ammal_list.line.2':
        'Dhaniram is at the market. He will not cheat you.',
    'node.ammal.ammal_first.line.0': 'Oh, good. Another pair of hands.',
    'node.ammal.ammal_first.line.1':
        'The guests will be here by the afternoon and I have nothing ready at '
        'all.',
    'choice.ammal.ammal_first.ammal_ask_list.text':
        'What do you need? I will fetch it.',
    'choice.ammal.ammal_first.ammal_ask_list.reply':
        'Bless you. Here are twenty-six coins — that is what we have.',

    // ----- Bipul (was Murugan). Goru Bihu is the cattle day.
    'char.murugan.name': 'Bipul',
    'char.murugan.role': 'He looks after the cattle',
    'node.murugan.murugan_invited.line.0':
        'I have washed both the cows in the river and rubbed them with '
        'turmeric.',
    'node.murugan.murugan_invited.line.1':
        'I will bring them past at the end, with the bells on. You will hear '
        'them coming.',
    'node.murugan.murugan_declined.line.0':
        'No, you are right, there is a lot to do.',
    'node.murugan.murugan_declined.line.1':
        'I will be down by the river with the cows if you need me.',
    'node.murugan.murugan_ask.line.0':
        'You are running about for Nirmali, then.',
    'node.murugan.murugan_ask.line.1':
        'I was down at the river before it was light, washing the cows. Rupali '
        'went past me towards the market carrying her big basket, and it was '
        'full.',
    'node.murugan.murugan_ask.line.2':
        'Can I bring the cows through the courtyard at the end? It is Goru '
        'Bihu. They should be seen.',
    'choice.murugan.murugan_ask.invite_murugan.text':
        'Yes. Bring them, and bring yourself.',
    'choice.murugan.murugan_ask.invite_murugan.reply':
        'Then I will garland them properly. You will see.',
    'choice.murugan.murugan_ask.decline_murugan.text':
        'Not today — there is too much to do.',
    'choice.murugan.murugan_ask.decline_murugan.reply': 'Another year, then.',
    'node.murugan.murugan_first.line.0':
        'The cows know it is Bihu. They always do.',
    'node.murugan.murugan_first.line.1':
        'Nirmali is looking for someone. You had better go over.',

    // ----- Dhaniram (was Kannan)
    'char.kannan.name': 'Dhaniram',
    'char.kannan.role': 'The potter, at the market',
    'node.kannan.kannan_solved.line.0':
        'So it was under my own nose the whole morning. Take it, take it.',
    'node.kannan.kannan_solved.line.1':
        'And tell Rupali I am sorry. I thought somebody had left it to be '
        'mended.',
    'node.kannan.kannan_searching.line.0':
        'A wide woven cone, worked in colours? That is a japi, that is.',
    'node.kannan.kannan_searching.line.1':
        'Nobody has handed me one. But there is a pile of things behind the '
        'stall waiting to go in the kiln. Have a look yourself, if you like.',
    'node.kannan.kannan_list.line.0':
        'Nirmali sent you. Of course she did.',
    'node.kannan.kannan_list.line.1':
        'Here is your trouble: the gur went by first light. Every cake of it.',
    'node.kannan.kannan_list.line.2':
        'Take the grated coconut instead. Cook it with a little sugar and it '
        'fills a pitha just the same. Nobody will know and nobody would mind.',
    'node.kannan.kannan_first.line.0':
        'Pots, lamps, whatever you need. Mind the wet ones at the back.',

    // ----- Rupali (was Selvi)
    'char.selvi.name': 'Rupali',
    'char.selvi.role': 'She weaves, and hangs the japi',
    'node.selvi.selvi_ready.line.0':
        'Look at it. That is a courtyard ready for Bihu.',
    'node.selvi.selvi_ready.line.1':
        'Whenever you are ready, we will light the fire.',
    'node.selvi.selvi_has_stencil.line.0':
        'You found it! Where on earth — no, never mind where.',
    'node.selvi.selvi_has_stencil.line.1':
        'Hang it over the doorway and I will start on the rest. Bring the pot '
        'and the gamosa as well.',
    'node.selvi.selvi_murugan.line.0':
        'Bipul says he is bringing the cows through at the end, with bells.',
    'node.selvi.selvi_murugan.line.1':
        'Then we had better leave the gateway clear for them. Find me that '
        'japi.',
    'node.selvi.selvi_stencil.line.0':
        'Still no japi. I cannot hang an empty doorway and call it Bihu.',
    'choice.selvi.selvi_stencil.selvi_again.text':
        'Tell me about the japi again.',
    'node.selvi.selvi_explain.line.0':
        'A wide cone of bamboo and dried leaf, worked in red and green. It '
        'hangs over the door for the whole of Bihu.',
    'node.selvi.selvi_explain.line.1':
        'It was in my big basket. I am certain of it, because I packed it '
        'myself.',
    'node.selvi.selvi_first.line.0':
        'You have come at a bad moment. The japi is gone.',
    'node.selvi.selvi_first.line.1':
        'It was in my basket this morning — I packed it myself — and '
        'now the basket is here and the japi is not.',

    // ----- the shopping
    'request.req_pot.label': 'A pot to steam the pitha in',
    'request.req_rice.label': 'Bora rice, ground fine',
    'request.req_sweet.label': 'Something sweet for the filling',
    'request.req_milk.label': 'Curd for the jolpan',
    'request.req_cane.label': 'A gamosa to give to the elders',
    'stall.pottery.keeperLine':
        'Every one of them fired this week. Pick it up, go on.',
    'stall.grain.keeperLine':
        'Bora rice, and it is good rice. The gur I am afraid is gone.',
    'stall.dairy.keeperLine':
        'Set this morning. Bring the pot back when you are done.',

    // ----- the mystery
    'mystery.question': 'Where did the japi go?',
    'mystery.reveal':
        'You lift the japi off the pile. It must have gone out with the basket '
        'before dawn and been set down with Dhaniram’s own things. Nobody '
        'took it anywhere. It simply never came home.',
    'mystery.wrongLocation':
        'Nothing there fits what you have been told. Think about where the '
        'basket actually went this morning, and who saw it go.',
    'mystery.wrongClues':
        'That may well be the place — but say why. You need the basket, '
        'where it was seen going, and what is actually sitting there now.',
    'clue.clue_basket.text':
        'Rupali packed the japi in her big basket herself this morning. The '
        'basket is back; the japi is not.',
    'clue.clue_dawn.text':
        'Bipul saw Rupali carry the full basket towards the market before it '
        'was light.',
    'clue.clue_board.text':
        'In the pile of things behind Dhaniram’s stall there is a wide '
        'woven cone, worked in red and green.',

    // ----- the journal
    'quest.q_list.title': 'Ask Nirmali what she needs',
    'quest.q_list.detail':
        'Nirmali is in the village square with an empty pot.',
    'quest.q_list.hint':
        'Nirmali is the woman standing by the well in the square. Tap her.',
    'quest.q_shop.title': 'Buy everything on the list',
    'quest.q_shop.detail':
        'A pot, bora rice, something sweet, curd, and a gamosa — out of '
        'twenty-six coins.',
    'quest.q_shop.hint':
        'The gur has sold out. Talk to Dhaniram at the market — he will '
        'tell you what else will do.',
    'quest.q_stencil.title': 'Find the missing japi',
    'quest.q_stencil.detail':
        'Rupali cannot dress the doorway without it. Find out where it went.',
    'quest.q_stencil.hint':
        'Three people saw part of this morning: Rupali, Bipul, and Dhaniram. '
        'Then look behind Dhaniram’s stall.',
    'quest.q_prepare.title': 'Get the courtyard ready',
    'quest.q_prepare.detail':
        'Put the pot on the fire, the japi above the doorway and the gamosa '
        'ready to give, then choose how it should look.',
    'quest.q_prepare.hint':
        'In the courtyard, tap "Get the courtyard ready". Tap a thing, then '
        'tap where it goes.',

    // ----- the endings
    'ending.ending_together.title': 'The whole village came',
    'ending.ending_together.celebration':
        'The first pitha come out of the steam, and everybody reaches at once.',
    'ending.ending_together.text':
        'The pitha are ready by the afternoon, exactly as they should be, and '
        'the gamosa is given and taken in both hands. Then the bells start at '
        'the gate: Bipul brings the cows through, washed and garlanded and '
        'entirely pleased with themselves, and Rupali laughs so much she has '
        'to sit down. Somebody says it is the best Bihu in years, and for once '
        'nobody argues.',
    'ending.ending_quiet.title': 'A good, quiet Bihu',
    'ending.ending_quiet.celebration':
        'The first pitha come out of the steam, and Nirmali lets out a breath.',
    'ending.ending_quiet.text':
        'The pitha are ready by the afternoon, exactly as they should be. The '
        'gamosa is given and taken in both hands, the japi hangs over the door '
        'all day, and the jolpan is eaten sitting on the ground in the sun. It '
        'is a calm Bihu, and a good one. Down by the river the cattle bells go '
        'on ringing, a long way off.',
  },
);

/// Every festival, in the order the chooser shows them.
final List<FestivalSkin> kFestivals = [kPongalFestival, kBihuFestival];

/// The bundled adventure for one festival.
///
/// Ids are fixed strings rather than anything derived, because they are written
/// into saved progress and finished runs: changing one would orphan somebody's
/// half-played game. Pongal keeps the id it has always had.
String festivalAdventureId(FestivalSkin festival) =>
    festival.id == 'pongal' ? kPongalAdventure.id : 'bihu_japi_v1';

Adventure adventureForFestival(FestivalSkin festival) {
  if (festival.id == 'pongal') return kPongalAdventure;
  return applyVariation(
    id: festivalAdventureId(festival),
    festival: festival,
    source: AdventureSource.bundled,
  );
}

/// The festival an adventure belongs to, for showing alongside it.
FestivalSkin? festivalOfAdventure(String adventureId) {
  for (final festival in kFestivals) {
    if (festivalAdventureId(festival) == adventureId) return festival;
  }
  return null;
}

FestivalSkin festivalById(String? id) => kFestivals.firstWhere(
  (festival) => festival.id == id,
  orElse: () => kPongalFestival,
);
