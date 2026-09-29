/// The adventure that ships with MindPal: **The Pongal Pot**.
///
/// Hand-written, complete, and playable with no internet at all. It is the
/// reference every generated adventure is measured against, and the fallback
/// whenever generation fails or is refused.
///
/// **The story is fiction.** Kalvayal is an invented village and Ammal, Kannan,
/// Selvi and Murugan are invented people. The *festival* is real, and what the
/// adventure says about Pongal — the harvest thanksgiving, the pot boiling
/// over, the kolam at the doorway, the sugarcane — comes from the curated
/// reference note below. The app labels the narrative as fiction on the screen
/// before play begins. It is not folklore and MindPal never calls it folklore.
///
/// The cultural note is marked **unreviewed**: the facts are widely published,
/// but no Tamil reviewer has read this text, and the app says so rather than
/// presenting it as checked.
library;

import 'package:flutter/material.dart';

import '../model/adventure.dart';
import '../model/requirement.dart';

const String _flagHasList = 'has_list';
const String _flagHeardStencil = 'heard_about_stencil';
const String _flagMarketDone = 'market_done';
const String _flagMysterySolved = 'mystery_solved';
const String _flagCourtyardReady = 'courtyard_ready';
const String _flagInvited = 'invited_murugan';
const String _flagDeclined = 'declined_murugan';
const String _flagFoundBoards = 'found_boards';
const String _flagKnowsAlternative = 'knows_alternative';

const Adventure kPongalAdventure = Adventure(
  id: 'pongal_pot_v1',
  title: 'The Pongal Pot',
  source: AdventureSource.bundled,
  objective: 'Help Ammal and the village of Kalvayal get ready for Pongal.',
  intro:
      'It is the morning of Pongal in the village of Kalvayal. The sun is up, '
      'the fire is laid, and Ammal is standing in the square with an empty pot '
      'and a worried look. There is a great deal to do before the milk can be '
      'set to boil — and something that should be hanging in the '
      'courtyard is not there at all.',
  startLocationId: 'square',
  culturalNote: CulturalNote(
    festival: 'Pongal',
    region: 'Tamil Nadu, South India',
    summary:
        'Pongal is the Tamil harvest festival, held in mid-January over four '
        'days. It gives thanks for the harvest. The dish it is named after is '
        'rice boiled with milk and jaggery in a pot; the pot is watched until '
        'it boils over, and the boiling over is the good omen everyone waits '
        'for. A kolam is drawn on the ground at the doorway, whole sugarcane '
        'is stood up by the house, and on the day called Mattu Pongal the '
        'cattle are washed, decorated and thanked for their work.',
    references: [
      'The village of Kalvayal and everyone in this story are invented. Only '
          'the festival is real.',
      'Still to be checked by a Tamil reviewer. Suggested sources: Tamil Nadu '
          'government cultural publications on Pongal, and a standard '
          'reference on Tamil festivals for the four days and the kolam.',
    ],
  ),

  // ------------------------------------------------------------------ items
  items: [
    AdventureItem(
      id: 'clay_pot',
      name: 'Clay pot',
      description:
          'A round earthen pot with a wide mouth, the usual thing to boil '
          'pongal in.',
      icon: Icons.soup_kitchen_rounded,
      color: Color(0xFF8D4004),
      price: 6,
    ),
    AdventureItem(
      id: 'brass_pot',
      name: 'Brass pot',
      description:
          'Heavier than the clay one, and it shines. It costs more, and it '
          'will do the job just as well.',
      icon: Icons.emoji_food_beverage_rounded,
      color: Color(0xFF9A6700),
      price: 9,
    ),
    AdventureItem(
      id: 'rice',
      name: 'New rice',
      description: 'Rice from this harvest, which is the whole point of today.',
      icon: Icons.rice_bowl_rounded,
      color: Color(0xFFB26500),
      price: 4,
    ),
    AdventureItem(
      id: 'jaggery',
      name: 'Jaggery',
      description:
          'Dark unrefined sugar, pressed into a round cake. What pongal is '
          'usually sweetened with.',
      icon: Icons.cookie_rounded,
      color: Color(0xFF5D4037),
      price: 5,
    ),
    AdventureItem(
      id: 'palm_sugar',
      name: 'Palm sugar',
      description:
          'Sweet and dark, made from palm sap instead of cane. It sweetens the '
          'pot just as well as jaggery does.',
      icon: Icons.bakery_dining_rounded,
      color: Color(0xFF6D4C41),
      price: 6,
    ),
    AdventureItem(
      id: 'milk',
      name: 'Milk',
      description: 'Fresh milk, still warm, in a covered pail.',
      icon: Icons.local_drink_rounded,
      color: Color(0xFF1565C0),
      price: 3,
    ),
    AdventureItem(
      id: 'sugarcane',
      name: 'Sugarcane',
      description:
          'Two whole canes, taller than you are, leaves and all. They are '
          'stood up by the house at Pongal.',
      icon: Icons.grass_rounded,
      color: Color(0xFF2E7D32),
      price: 3,
    ),
    AdventureItem(
      id: 'stencil',
      name: 'Kolam stencil',
      description:
          'A flat wooden board pricked with holes. Powder is pushed through it '
          'to lay a kolam pattern on the ground.',
      icon: Icons.grid_on_rounded,
      color: Color(0xFF6A1B9A),
    ),
  ],

  // -------------------------------------------------------------- locations
  locations: [
    AdventureLocation(
      id: 'square',
      name: 'Village square',
      description:
          'A swept open square with a well in the middle. The road to the '
          'market runs off to the left, and the courtyard gate is on the '
          'right.',
      visitFlag: 'been_square',
      skyColor: Color(0xFFBBDEFB),
      groundColor: Color(0xFFD7C4A3),
      hotspots: [
        Hotspot(
          id: 'sq_ammal',
          label: 'Ammal',
          kind: HotspotKind.character,
          targetId: 'ammal',
          x: 0.26,
          y: 0.52,
          icon: Icons.face_3_rounded,
          color: Color(0xFFAD1457),
        ),
        Hotspot(
          id: 'sq_murugan',
          label: 'Murugan',
          kind: HotspotKind.character,
          targetId: 'murugan',
          x: 0.72,
          y: 0.58,
          icon: Icons.face_rounded,
          color: Color(0xFF00695C),
        ),
        Hotspot(
          id: 'sq_well',
          label: 'The well',
          kind: HotspotKind.object,
          x: 0.5,
          y: 0.72,
          icon: Icons.water_drop_rounded,
          color: Color(0xFF1565C0),
          inspectText:
              'The well is cool and dark. Someone has already drawn the water '
              'for the day — two full pots stand beside it.',
        ),
        Hotspot(
          id: 'sq_to_market',
          label: 'To the market',
          kind: HotspotKind.exit,
          targetId: 'market',
          x: 0.1,
          y: 0.86,
          icon: Icons.storefront_rounded,
          color: Color(0xFF8D4004),
        ),
        Hotspot(
          id: 'sq_to_courtyard',
          label: 'To the courtyard',
          kind: HotspotKind.exit,
          targetId: 'courtyard',
          x: 0.9,
          y: 0.86,
          icon: Icons.deck_rounded,
          color: Color(0xFF6A1B9A),
        ),
      ],
    ),
    AdventureLocation(
      id: 'market',
      name: 'Market',
      description:
          'Three stalls under cloth awnings, and more noise than the rest of '
          'the village put together. Everything smells of cut cane.',
      visitFlag: 'been_market',
      skyColor: Color(0xFFFFE0B2),
      groundColor: Color(0xFFC8A87C),
      hotspots: [
        Hotspot(
          id: 'mk_kannan',
          label: 'Kannan',
          kind: HotspotKind.character,
          targetId: 'kannan',
          x: 0.24,
          y: 0.5,
          icon: Icons.face_6_rounded,
          color: Color(0xFF8D4004),
        ),
        Hotspot(
          id: 'mk_stalls',
          label: 'The stalls',
          kind: HotspotKind.market,
          x: 0.63,
          y: 0.48,
          icon: Icons.storefront_rounded,
          color: Color(0xFFB26500),
        ),
        Hotspot(
          id: 'mk_boards',
          label: 'A stack of boards',
          kind: HotspotKind.object,
          x: 0.44,
          y: 0.74,
          icon: Icons.dashboard_rounded,
          color: Color(0xFF6A1B9A),
          // Only worth a second look once you know a flat board is missing.
          visibleWhen: Requirement(clues: {'clue_basket'}),
          repeatable: false,
          inspectText:
              'Behind Kannan’s stall there is a stack of flat boards '
              'waiting to be fired. One of them is not clay at all — it is '
              'wood, and it is pricked all over with little holes.',
          onInspect: Effect(
            setFlags: {_flagFoundBoards},
            revealClues: {'clue_board'},
          ),
        ),
        Hotspot(
          id: 'mk_to_square',
          label: 'Back to the square',
          kind: HotspotKind.exit,
          targetId: 'square',
          x: 0.88,
          y: 0.86,
          icon: Icons.holiday_village_rounded,
          color: Color(0xFF00695C),
        ),
      ],
    ),
    AdventureLocation(
      id: 'courtyard',
      name: 'Celebration courtyard',
      description:
          'An open courtyard with a swept floor, a low fire laid ready, and a '
          'wide doorway where the kolam should go.',
      visitFlag: 'been_courtyard',
      skyColor: Color(0xFFFFF3C4),
      groundColor: Color(0xFFCDBBA0),
      hotspots: [
        Hotspot(
          id: 'cy_selvi',
          label: 'Selvi',
          kind: HotspotKind.character,
          targetId: 'selvi',
          x: 0.25,
          y: 0.5,
          icon: Icons.face_2_rounded,
          color: Color(0xFF6A1B9A),
        ),
        Hotspot(
          id: 'cy_prepare',
          label: 'Get the courtyard ready',
          kind: HotspotKind.prepare,
          x: 0.62,
          y: 0.58,
          icon: Icons.local_fire_department_rounded,
          color: Color(0xFFB26500),
        ),
        Hotspot(
          id: 'cy_accuse',
          label: 'Say where the stencil went',
          kind: HotspotKind.accuse,
          x: 0.4,
          y: 0.78,
          icon: Icons.search_rounded,
          color: Color(0xFF1565C0),
          visibleWhen: Requirement(clues: {'clue_basket'}),
        ),
        Hotspot(
          id: 'cy_to_square',
          label: 'Back to the square',
          kind: HotspotKind.exit,
          targetId: 'square',
          x: 0.88,
          y: 0.86,
          icon: Icons.holiday_village_rounded,
          color: Color(0xFF00695C),
        ),
      ],
    ),
  ],

  // ------------------------------------------------------------- characters
  //
  // The FIRST node whose requirement is met is the one a character opens with,
  // so every list runs from most specific to most general and finishes with an
  // unconditional line. Nobody can ever be tapped and say nothing.
  characters: [
    AdventureCharacter(
      id: 'ammal',
      name: 'Ammal',
      role: 'She is cooking the pongal',
      locationId: 'square',
      icon: Icons.face_3_rounded,
      color: Color(0xFFAD1457),
      nodes: [
        DialogueNode(
          id: 'ammal_done',
          requires: Requirement(flags: {_flagMarketDone}),
          isKeyMoment: true,
          lines: [
            'You have everything. Look at it all!',
            'Take it to the courtyard, and we can begin. Selvi is there — '
                'she will know where things go.',
          ],
        ),
        DialogueNode(
          id: 'ammal_shopping',
          requires: Requirement(flags: {_flagHasList}),
          lines: ['Still shopping? Take your time. The fire will keep.'],
          choices: [
            DialogueChoice(
              id: 'ammal_repeat',
              text: 'Tell me the list again.',
              goTo: 'ammal_list',
            ),
          ],
        ),
        // Reached only by going to it, and guarded so it cannot become
        // the line Ammal opens with.
        DialogueNode(
          id: 'ammal_list',
          requires: Requirement(flags: {_flagHasList}),
          isKeyMoment: true,
          lines: [
            'A pot big enough to boil over. New rice, from this harvest, not '
                'last year’s.',
            'Something sweet to go in with the milk. Milk itself. And '
                'sugarcane — whole canes, to stand by the house.',
            'Kannan is at the market. He will not cheat you.',
          ],
        ),
        DialogueNode(
          id: 'ammal_first',
          isKeyMoment: true,
          lines: [
            'Oh, good. Another pair of hands.',
            'The pot has to boil over before noon or it is no good at all, and '
                'I have nothing yet.',
          ],
          choices: [
            DialogueChoice(
              id: 'ammal_ask_list',
              text: 'What do you need? I will fetch it.',
              reply:
                  'Bless you. Here are twenty-six coins — that is what we '
                  'have.',
              effect: Effect(setFlags: {_flagHasList}),
              goTo: 'ammal_list',
            ),
          ],
        ),
      ],
    ),
    AdventureCharacter(
      id: 'murugan',
      name: 'Murugan',
      role: 'He looks after the cattle',
      locationId: 'square',
      icon: Icons.face_rounded,
      color: Color(0xFF00695C),
      nodes: [
        DialogueNode(
          id: 'murugan_invited',
          requires: Requirement(flags: {_flagInvited}),
          lines: [
            'I have washed both the cows and put the bells on them.',
            'They will come in at the end. You will hear them.',
          ],
        ),
        DialogueNode(
          id: 'murugan_declined',
          requires: Requirement(flags: {_flagDeclined}),
          lines: [
            'No, you are right, there is a lot to do.',
            'I will be up on the ridge with the cows if you need me.',
          ],
        ),
        DialogueNode(
          id: 'murugan_ask',
          requires: Requirement(flags: {_flagHasList}),
          isKeyMoment: true,
          // Being told this is what reveals the clue, so it cannot be missed by
          // anybody who talks to him.
          onEnter: Effect(revealClues: {'clue_dawn'}),
          lines: [
            'You are running about for Ammal, then.',
            'I was up before it was light with the cows. Selvi went past me '
                'towards the market carrying her flower basket, and it was '
                'full.',
            'Can I come to the courtyard at the end? I want to bring the cows '
                'in with their bells on.',
          ],
          choices: [
            DialogueChoice(
              id: 'invite_murugan',
              text: 'Yes. Bring them, and bring yourself.',
              reply: 'I will wash them properly, then. You will see.',
              isDecision: true,
              effect: Effect(setFlags: {_flagInvited}),
            ),
            DialogueChoice(
              id: 'decline_murugan',
              text: 'Not today — there is too much to do.',
              reply: 'Another year, then.',
              isDecision: true,
              effect: Effect(setFlags: {_flagDeclined}),
            ),
          ],
        ),
        DialogueNode(
          id: 'murugan_first',
          lines: [
            'The cows know it is a festival. They always do.',
            'Ammal is looking for someone. You had better go over.',
          ],
        ),
      ],
    ),
    AdventureCharacter(
      id: 'kannan',
      name: 'Kannan',
      role: 'The potter, at the market',
      locationId: 'market',
      icon: Icons.face_6_rounded,
      color: Color(0xFF8D4004),
      nodes: [
        DialogueNode(
          id: 'kannan_solved',
          requires: Requirement(flags: {_flagMysterySolved}),
          lines: [
            'So it was under my own nose the whole morning. Take it, take it.',
            'And tell Selvi I am sorry. I thought it was one of mine.',
          ],
        ),
        DialogueNode(
          id: 'kannan_searching',
          requires: Requirement(clues: {'clue_basket'}),
          isKeyMoment: true,
          lines: [
            'A flat wooden board, full of little holes? That is a kolam '
                'stencil, that is.',
            'Nobody has handed me one. But I have a stack of boards behind the '
                'stall waiting for the kiln. Have a look yourself, if you '
                'like.',
          ],
        ),
        DialogueNode(
          id: 'kannan_list',
          requires: Requirement(flags: {_flagHasList}),
          isKeyMoment: true,
          // The acceptable alternative, explained by somebody rather than
          // printed on a sign.
          onEnter: Effect(setFlags: {_flagKnowsAlternative}),
          lines: [
            'Ammal sent you. Of course she did.',
            'Here is your trouble: the jaggery went by first light. Every cake '
                'of it.',
            'Take the palm sugar instead. It is darker and it costs a coin '
                'more, but it sweetens the pot just the same. Nobody will know '
                'and nobody would mind.',
          ],
        ),
        DialogueNode(
          id: 'kannan_first',
          lines: [
            'Pots, lamps, whatever you need. Mind the wet ones at the back.',
          ],
        ),
      ],
    ),
    AdventureCharacter(
      id: 'selvi',
      name: 'Selvi',
      role: 'She draws the kolam',
      locationId: 'courtyard',
      icon: Icons.face_2_rounded,
      color: Color(0xFF6A1B9A),
      nodes: [
        DialogueNode(
          id: 'selvi_ready',
          requires: Requirement(flags: {_flagCourtyardReady}),
          lines: [
            'Look at it. That is a courtyard ready for Pongal.',
            'Whenever you are ready, we will light the fire.',
          ],
        ),
        DialogueNode(
          id: 'selvi_has_stencil',
          requires: Requirement(items: {'stencil'}),
          isKeyMoment: true,
          lines: [
            'You found it! Where on earth — no, never mind where.',
            'Set it down by the doorway and I will start. Bring the pot and '
                'the cane as well.',
          ],
        ),
        // The one place Murugan's invitation comes back. A decision that
        // changes only the ending is a decision the player never sees working.
        DialogueNode(
          id: 'selvi_murugan',
          requires: Requirement(
            flags: {_flagInvited, _flagHeardStencil},
          ),
          lines: [
            'Murugan says he is bringing the cows in at the end, with bells.',
            'Then I had better make the kolam wide enough for them to walk '
                'through. Find me that stencil.',
          ],
        ),
        DialogueNode(
          id: 'selvi_stencil',
          requires: Requirement(flags: {_flagHeardStencil}),
          lines: [
            'Still no stencil. I cannot lay a kolam that size freehand, not '
                'today.',
          ],
          choices: [
            DialogueChoice(
              id: 'selvi_again',
              text: 'Tell me about the stencil again.',
              goTo: 'selvi_explain',
            ),
          ],
        ),
        DialogueNode(
          id: 'selvi_explain',
          requires: Requirement(flags: {_flagHeardStencil}),
          isKeyMoment: true,
          onEnter: Effect(revealClues: {'clue_basket'}),
          lines: [
            'A flat board, pricked with holes. You push the powder through it '
                'and the pattern comes out perfect.',
            'It was in my flower basket. I am certain of it, because I packed '
                'it myself.',
          ],
        ),
        DialogueNode(
          id: 'selvi_first',
          isKeyMoment: true,
          onEnter: Effect(
            setFlags: {_flagHeardStencil},
            revealClues: {'clue_basket'},
          ),
          lines: [
            'You have come at a bad moment. The kolam stencil is gone.',
            'It was in my flower basket this morning — I packed it myself '
                '— and now the basket is here and the stencil is not.',
          ],
        ),
      ],
    ),
  ],

  // --------------------------------------------------------------- shopping
  market: MarketConfig(
    startingCoins: 26,
    completedFlag: _flagMarketDone,
    // Cheapest complete basket: clay pot 6 + rice 4 + palm sugar 6 + milk 3 +
    // cane 3 = 22, so 26 leaves room for the brass pot instead (25) without
    // making the list impossible. The validator recomputes this rather than
    // trusting the comment.
    stalls: [
      MarketStall(
        id: 'pottery',
        name: 'Kannan’s pots',
        keeperLine: 'Every one of them fired this week. Pick it up, go on.',
        itemIds: ['clay_pot', 'brass_pot'],
        icon: Icons.soup_kitchen_rounded,
        color: Color(0xFF8D4004),
      ),
      MarketStall(
        id: 'grain',
        name: 'The grain and sweet stall',
        keeperLine:
            'New rice, and it is good rice. The jaggery I am afraid is gone.',
        itemIds: ['rice', 'jaggery', 'palm_sugar', 'sugarcane'],
        // The one unavailable item the player has to work around.
        soldOutItemIds: {'jaggery'},
        icon: Icons.rice_bowl_rounded,
        color: Color(0xFFB26500),
      ),
      MarketStall(
        id: 'dairy',
        name: 'The milk pails',
        keeperLine: 'Still warm. Bring the pail back when you are done.',
        itemIds: ['milk'],
        icon: Icons.local_drink_rounded,
        color: Color(0xFF1565C0),
      ),
    ],
    requests: [
      MarketRequest(
        id: 'req_pot',
        label: 'A pot big enough to boil over',
        acceptedItemIds: ['clay_pot', 'brass_pot'],
      ),
      MarketRequest(
        id: 'req_rice',
        label: 'New rice from this harvest',
        acceptedItemIds: ['rice'],
      ),
      MarketRequest(
        id: 'req_sweet',
        label: 'Something sweet for the pot',
        acceptedItemIds: ['jaggery', 'palm_sugar'],
      ),
      MarketRequest(
        id: 'req_milk',
        label: 'Milk',
        acceptedItemIds: ['milk'],
      ),
      MarketRequest(
        id: 'req_cane',
        label: 'Whole sugarcane to stand by the house',
        acceptedItemIds: ['sugarcane'],
      ),
    ],
  ),

  // ---------------------------------------------------------------- mystery
  mystery: MysteryConfig(
    question: 'Where did the kolam stencil go?',
    solvedFlag: _flagMysterySolved,
    decorationItemId: 'stencil',
    candidateLocationIds: ['square', 'market', 'courtyard'],
    solutionLocationId: 'market',
    supportingClueIds: {'clue_basket', 'clue_dawn', 'clue_board'},
    clues: [
      Clue(
        id: 'clue_basket',
        text:
            'Selvi packed the stencil in her flower basket herself this '
            'morning. The basket is back; the stencil is not.',
        source: 'Told by Selvi',
        icon: Icons.shopping_basket_rounded,
      ),
      Clue(
        id: 'clue_dawn',
        text:
            'Murugan saw Selvi carry the full flower basket towards the market '
            'before it was light.',
        source: 'Told by Murugan',
        icon: Icons.wb_twilight_rounded,
      ),
      Clue(
        id: 'clue_board',
        text:
            'In the stack of boards behind Kannan’s stall there is one '
            'made of wood, pricked all over with little holes.',
        source: 'Seen at the market',
        icon: Icons.grid_on_rounded,
      ),
    ],
    revealText:
        'You lift the wooden board off the stack. It is the stencil — it '
        'must have gone out with the flowers before dawn and been set down '
        'with Kannan’s own boards. Nobody took it anywhere. It simply '
        'never came home.',
    wrongLocationHint:
        'Nothing there fits what you have been told. Think about where the '
        'basket actually went this morning, and who saw it go.',
    wrongCluesHint:
        'That may well be the place — but say why. You need the basket, '
        'where it was seen going, and what is actually sitting there now.',
  ),

  // ------------------------------------------------------------- courtyard
  preparation: PreparationConfig(
    readyFlag: _flagCourtyardReady,
    slots: [
      PreparationSlot(
        id: 'slot_fire',
        label: 'On the fire',
        acceptedItemIds: ['clay_pot', 'brass_pot'],
        x: 0.32,
        y: 0.62,
        filledText:
            'The pot goes on the fire. The rice and the milk go in, and now '
            'everybody will watch it until it rises.',
      ),
      PreparationSlot(
        id: 'slot_doorway',
        label: 'By the doorway',
        acceptedItemIds: ['stencil'],
        x: 0.62,
        y: 0.7,
        filledText:
            'Selvi lays the stencil flat, and the powder goes through it in '
            'one sweep. The kolam is there as if it had always been.',
      ),
      PreparationSlot(
        id: 'slot_pillar',
        label: 'Against the pillar',
        acceptedItemIds: ['sugarcane'],
        x: 0.84,
        y: 0.5,
        filledText:
            'The canes lean against the pillar, taller than the doorway, '
            'leaves still on.',
      ),
    ],
    // None of these is ever wrong. They are a matter of taste and the game
    // treats them that way.
    styles: [
      DecorationStyle(
        id: 'style_plain',
        name: 'Plain and bright',
        description: 'White kolam, and nothing else. Let the courtyard show.',
        color: Color(0xFF1565C0),
        icon: Icons.brightness_5_rounded,
      ),
      DecorationStyle(
        id: 'style_colour',
        name: 'Full of colour',
        description: 'Every powder Selvi has, and the mango leaves as well.',
        color: Color(0xFFAD1457),
        icon: Icons.palette_rounded,
      ),
      DecorationStyle(
        id: 'style_lamps',
        name: 'Ringed with lamps',
        description: 'Small oil lamps all round the kolam, for the evening.',
        color: Color(0xFF9A6700),
        icon: Icons.light_rounded,
      ),
    ],
  ),

  // ----------------------------------------------------------------- quests
  quests: [
    QuestStep(
      id: 'q_list',
      title: 'Ask Ammal what she needs',
      detail: 'Ammal is in the village square with an empty pot.',
      doneWhen: Requirement(flags: {_flagHasList}),
      hint: 'Ammal is the woman standing by the well in the square. Tap her.',
    ),
    QuestStep(
      id: 'q_shop',
      title: 'Buy everything on the list',
      detail:
          'A pot, new rice, something sweet, milk, and sugarcane — out of '
          'twenty-six coins.',
      activeWhen: Requirement(flags: {_flagHasList}),
      doneWhen: Requirement(flags: {_flagMarketDone}),
      hint:
          'The jaggery has sold out. Talk to Kannan at the market — he '
          'will tell you what else will do.',
    ),
    QuestStep(
      id: 'q_stencil',
      title: 'Find the missing kolam stencil',
      detail:
          'Selvi cannot lay the kolam without it. Find out where it went.',
      activeWhen: Requirement(flags: {_flagHeardStencil}),
      doneWhen: Requirement(flags: {_flagMysterySolved}),
      hint:
          'Three people saw part of this morning: Selvi, Murugan, and Kannan. '
          'Then look behind Kannan’s stall.',
    ),
    QuestStep(
      id: 'q_prepare',
      title: 'Get the courtyard ready',
      detail:
          'Put the pot on the fire, the stencil by the doorway and the cane '
          'against the pillar, then choose how it should look.',
      activeWhen: Requirement(flags: {_flagMarketDone, _flagMysterySolved}),
      doneWhen: Requirement(flags: {_flagCourtyardReady}),
      hint:
          'In the courtyard, tap "Get the courtyard ready". Tap a thing, then '
          'tap where it goes.',
    ),
  ],

  // ---------------------------------------------------------------- endings
  //
  // Checked in order, first match wins, and the last one is unconditional so
  // that every finished game has something to show.
  endings: [
    Ending(
      id: 'ending_together',
      title: 'The whole village came',
      requires: Requirement(flags: {_flagInvited}),
      color: Color(0xFFAD1457),
      icon: Icons.celebration_rounded,
      celebration:
          'The milk climbs the side of the pot and goes over, and everybody '
          'shouts at once.',
      text:
          'The pot boils over just before noon, exactly as it should, and the '
          'shout goes up. Then the bells start at the gate: Murugan brings the '
          'cows in, washed and painted, straight across Selvi’s kolam, '
          'which she made wide enough on purpose. Ammal laughs until she has '
          'to sit down. Somebody says it is the best Pongal in years, and for '
          'once nobody argues.',
    ),
    Ending(
      id: 'ending_quiet',
      title: 'A good, quiet Pongal',
      color: Color(0xFF00695C),
      icon: Icons.wb_sunny_rounded,
      celebration:
          'The milk climbs the side of the pot and goes over, and Ammal lets '
          'out a breath.',
      text:
          'The pot boils over just before noon, exactly as it should. Ammal '
          'serves it out, Selvi’s kolam holds its shape all day, and the '
          'sugarcane stands by the door until evening. It is a calm Pongal, '
          'and a good one. Out on the ridge the cattle bells go on ringing, a '
          'long way off.',
    ),
  ],
);
