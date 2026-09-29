import 'package:flutter/material.dart';

import '../cultural_pack.dart';

/// The starter pack: everyday things and customs of Assam.
///
/// One region, named specifically. Assam is not "the North East", and this
/// pack does not stand in for Manipur, Nagaland, Meghalaya or anywhere else —
/// each deserves its own pack written with someone from there, which is why
/// [kCulturalPacks] lists only this one rather than showing seven buttons that
/// do nothing.
///
/// **Review status is `pendingReview`, and that is not a formality.** Every
/// sentence below was written from general published knowledge and has not
/// been read by an Assamese reviewer. The app shows an "unchecked" marker
/// wherever these facts appear. Marking this `reviewed` is a decision for a
/// person, not a code change to be made casually.
const CulturalPack kAssamBihuPack = CulturalPack(
  id: 'assam_bihu_v1',
  title: 'Assam: Bihu and everyday things',
  region: 'Assam, North-East India',
  languageNote:
      'Written in English. The Assamese names of things are used as they are '
      'said, in Latin letters — not in the Assamese script.',
  review: PackReview.pendingReview,
  artworkNote:
      'The pictures are stand-in symbols from the Material icon set, not '
      'photographs. They are chosen to be told apart easily, and the name of '
      'every object is always shown beside its picture. Real photographs or '
      'drawn artwork still need to be commissioned or licensed.',
  sources: [
    'Every fact here still needs checking against a published source and an '
        'Assamese reviewer. Suggested places to check: Government of Assam '
        'publications on handloom, textiles and sericulture (gamosa, muga '
        'silk); documentation of Assamese folk instruments held by the '
        'Sangeet Natak Akademi (dhol, pepa, gogona, khol, taal); and a '
        'standard reference on Assamese cuisine (pitha, jolpan, khar, masor '
        'tenga, narikol laru).',
  ],
  items: [
    // ------------------------------------------------------ instruments
    CulturalItem(
      id: 'dhol',
      name: 'Dhol',
      kind: ItemKind.instrument,
      icon: Icons.music_note_rounded,
      color: Color(0xFF8D4004),
      description:
          'A drum with a skin at each end, hung from the shoulder. One side '
          'is struck with a stick and the other with the hand.',
      fact: 'The dhol sets the beat for the Bihu dance.',
      source: 'Needs checking against a reference on Assamese folk music.',
    ),
    CulturalItem(
      id: 'pepa',
      name: 'Pepa',
      kind: ItemKind.instrument,
      icon: Icons.campaign_rounded,
      color: Color(0xFF00695C),
      description:
          'A pipe made from a buffalo horn. It is blown, and makes a long, '
          'low call.',
      fact: 'The sound of the pepa is a sign that Bihu has arrived.',
      source: 'Needs checking against a reference on Assamese folk music.',
    ),
    CulturalItem(
      id: 'gogona',
      name: 'Gogona',
      kind: ItemKind.instrument,
      icon: Icons.graphic_eq_rounded,
      color: Color(0xFF2E7D32),
      description:
          'A small split piece of bamboo held between the teeth and plucked, '
          'so the mouth shapes the sound.',
      fact: 'A gogona is played held against the teeth, not with the hands '
          'alone.',
      source: 'Needs checking against a reference on Assamese folk music.',
    ),
    CulturalItem(
      id: 'taal',
      name: 'Taal',
      kind: ItemKind.instrument,
      icon: Icons.album_rounded,
      color: Color(0xFF9A6700),
      description: 'A pair of round brass cymbals, clapped together to keep '
          'time.',
      fact: 'Taal are clapped together to keep time while singing.',
      source: 'Needs checking against a reference on Assamese devotional '
          'singing.',
    ),
    CulturalItem(
      id: 'khol',
      name: 'Khol',
      kind: ItemKind.instrument,
      icon: Icons.audiotrack_rounded,
      color: Color(0xFF5D4037),
      description:
          'A drum with a body of baked clay, wider at one end than the other, '
          'played with both hands.',
      fact: 'The khol is played for singing in the namghar, the village '
          'prayer house.',
      source: 'Needs checking against a reference on Assamese devotional '
          'singing.',
    ),

    // ------------------------------------------------------------- food
    CulturalItem(
      id: 'pitha',
      name: 'Pitha',
      kind: ItemKind.food,
      icon: Icons.bakery_dining_rounded,
      color: Color(0xFFB26500),
      description:
          'A cake made from rice flour, often filled with coconut or sesame '
          'and cooked over a fire.',
      fact: 'Many kinds of pitha are made at Bihu time.',
      source: 'Needs checking against a reference on Assamese cooking.',
    ),
    CulturalItem(
      id: 'jolpan',
      name: 'Jolpan',
      kind: ItemKind.food,
      icon: Icons.breakfast_dining_rounded,
      color: Color(0xFF00838F),
      description:
          'A light morning meal of flattened or puffed rice, eaten with curd, '
          'cream or jaggery.',
      fact: 'Jolpan is eaten in the morning, before the day’s work.',
      source: 'Needs checking against a reference on Assamese cooking.',
    ),
    CulturalItem(
      id: 'masor_tenga',
      name: 'Masor tenga',
      kind: ItemKind.food,
      icon: Icons.set_meal_rounded,
      color: Color(0xFF1565C0),
      description: 'A fish curry with a sour taste, eaten with rice.',
      fact: 'Masor tenga is made sour with tomato, lemon or dried thekera.',
      source: 'Needs checking against a reference on Assamese cooking.',
    ),
    CulturalItem(
      id: 'narikol_laru',
      name: 'Narikol laru',
      kind: ItemKind.food,
      icon: Icons.cookie_rounded,
      color: Color(0xFFAD1457),
      description:
          'A sweet ball made of grated coconut cooked with jaggery, rolled by '
          'hand.',
      fact: 'Narikol laru is offered to guests at Bihu.',
      source: 'Needs checking against a reference on Assamese cooking.',
    ),
    CulturalItem(
      id: 'khar',
      name: 'Khar',
      kind: ItemKind.food,
      icon: Icons.rice_bowl_rounded,
      color: Color(0xFF4527A0),
      description:
          'An Assamese dish named after the alkaline water used to make it, '
          'usually eaten first in a meal.',
      fact: 'Khar is traditionally made using water strained through the ash '
          'of sun-dried banana peel.',
      source: 'Needs checking against a reference on Assamese cooking.',
    ),

    // --------------------------------------------------- handmade things
    CulturalItem(
      id: 'gamosa',
      name: 'Gamosa',
      kind: ItemKind.craft,
      icon: Icons.checkroom_rounded,
      color: Color(0xFFC62828),
      description:
          'A white woven cloth with red patterns at the ends, worn round the '
          'neck or given to someone as a mark of respect.',
      fact: 'Giving a gamosa is a way of showing respect.',
      source: 'Needs checking against Government of Assam handloom '
          'publications.',
    ),
    CulturalItem(
      id: 'japi',
      name: 'Japi',
      kind: ItemKind.craft,
      icon: Icons.umbrella_rounded,
      color: Color(0xFF827717),
      description:
          'A wide cone-shaped hat woven from bamboo and dried leaves, worn '
          'against the sun and rain.',
      fact: 'A plain japi is worn in the fields; a decorated one is given as '
          'a gift.',
      source: 'Needs checking against Government of Assam handicrafts '
          'publications.',
    ),
    CulturalItem(
      id: 'xorai',
      name: 'Xorai',
      kind: ItemKind.craft,
      icon: Icons.wine_bar_rounded,
      color: Color(0xFF6D4C41),
      description:
          'A tray standing on a base, beaten from bell metal, used to offer '
          'things to a guest or at prayer.',
      fact: 'A xorai is made of bell metal, an alloy of copper and tin.',
      source: 'Needs checking against a reference on Assam bell-metal work.',
    ),
    CulturalItem(
      id: 'muga_silk',
      name: 'Muga silk',
      kind: ItemKind.craft,
      icon: Icons.texture_rounded,
      color: Color(0xFF9A6700),
      description:
          'A strong silk cloth with a natural golden colour, woven in Assam.',
      fact: 'Muga silk is golden without being dyed.',
      source: 'Needs checking against Government of Assam sericulture '
          'publications.',
    ),
    CulturalItem(
      id: 'bamboo_basket',
      name: 'Bamboo basket',
      kind: ItemKind.craft,
      icon: Icons.shopping_basket_rounded,
      color: Color(0xFF33691E),
      description:
          'A basket woven from strips of split bamboo, used to carry and '
          'store almost anything.',
      fact: 'Bamboo and cane weaving is one of the oldest crafts in Assam.',
      source: 'Needs checking against Government of Assam handicrafts '
          'publications.',
    ),

    // ------------------------------------------------ farming and the land
    CulturalItem(
      id: 'paddy',
      name: 'Paddy',
      kind: ItemKind.farming,
      icon: Icons.grass_rounded,
      color: Color(0xFF558B2F),
      description: 'Rice still on the stalk, standing in a wet field.',
      fact: 'Rice is the main crop grown in Assam.',
      source: 'Needs checking against Government of Assam agriculture '
          'statistics.',
    ),
    CulturalItem(
      id: 'plough',
      name: 'Wooden plough',
      kind: ItemKind.farming,
      icon: Icons.agriculture_rounded,
      color: Color(0xFF4E342E),
      description:
          'A wooden plough pulled through wet soil to break it up before rice '
          'is planted.',
      fact: 'The field is ploughed while it is still wet, before planting.',
      source: 'Needs checking against a reference on rice farming.',
    ),
    CulturalItem(
      id: 'sickle',
      name: 'Sickle',
      kind: ItemKind.farming,
      icon: Icons.content_cut_rounded,
      color: Color(0xFF37474F),
      description:
          'A short curved blade held in one hand, used to cut the rice at '
          'harvest.',
      fact: 'The rice is cut by hand with a sickle at harvest time.',
      source: 'Needs checking against a reference on rice farming.',
    ),
    CulturalItem(
      id: 'winnowing_fan',
      name: 'Winnowing fan',
      kind: ItemKind.farming,
      icon: Icons.waves_rounded,
      color: Color(0xFF00838F),
      description:
          'A flat bamboo tray shaken so that the light husk blows away and '
          'the grain stays behind.',
      fact: 'Shaking the tray lets the wind carry the husk away from the '
          'grain.',
      source: 'Needs checking against a reference on rice processing.',
    ),
    CulturalItem(
      id: 'bullock_cart',
      name: 'Bullock cart',
      kind: ItemKind.farming,
      icon: Icons.agriculture_outlined,
      color: Color(0xFF5D4037),
      description:
          'A wooden cart on two wheels, pulled by a pair of bullocks, used to '
          'carry the harvest home.',
      fact: 'A bullock cart carries the cut rice from the field to the house.',
      source: 'Needs checking against a reference on rural transport.',
    ),
  ],
  stories: [
    // Three scenes: the gentlest sequence, used on Easy.
    CulturalStory(
      id: 'assam_tea_morning',
      title: 'Tea in the morning',
      origin: ContentOrigin.original,
      attribution:
          'Written for MindPal. It describes how tea is made in Assam, but it '
          'is not a traditional tale, and MindPal does not call it one.',
      text:
          'Assam is known for its tea. Early in the morning the pluckers go '
          'into the garden and pick the youngest leaves. The leaves are '
          'carried to the factory, where they are dried until they turn dark. '
          'Later that day the dried tea is boiled with water and milk, and '
          'poured out hot.',
      hint: 'The leaf has to be picked before anything else can happen to it.',
      explanation:
          'The leaves are picked first, while they are fresh. They are dried '
          'next, because wet leaves cannot be kept. The tea is poured last, '
          'once there is dried tea to boil.',
      scenes: [
        StoryScene(
          id: 'pluck',
          caption: 'The youngest leaves are picked in the garden.',
          icon: Icons.eco_rounded,
          color: Color(0xFF2E7D32),
          description: 'A hand picking leaves from a tea bush.',
        ),
        StoryScene(
          id: 'dry',
          caption: 'The leaves are dried until they turn dark.',
          icon: Icons.wb_sunny_rounded,
          color: Color(0xFFB26500),
          description: 'Tea leaves spread out to dry.',
        ),
        StoryScene(
          id: 'pour',
          caption: 'The hot tea is poured out to drink.',
          icon: Icons.local_cafe_rounded,
          color: Color(0xFF6D4C41),
          description: 'Tea being poured into a cup.',
        ),
      ],
    ),

    // Four scenes: used on Medium.
    CulturalStory(
      id: 'getting_ready_for_bihu',
      title: 'Getting ready for Bihu',
      origin: ContentOrigin.original,
      attribution:
          'Written for MindPal. It shows customs of Bohag Bihu in Assam, but '
          'it is not a traditional tale, and MindPal does not call it one.',
      text:
          'Bihu is coming, and there is a lot to do. In the morning the loom '
          'is set up in the veranda and a new gamosa is woven. In the kitchen '
          'rice is ground and pitha are cooked over the fire. When the work is '
          'finished the dhol is brought out into the courtyard and tightened '
          'until the sound is right. In the evening the neighbours arrive, the '
          'drum starts, and the dancing begins.',
      hint: 'The dancing cannot start until the day’s work is done.',
      explanation:
          'The weaving and the cooking are done in the morning, while there is '
          'time. The drum is tuned once that work is finished. The dancing '
          'comes last, in the evening, when everyone is free to gather.',
      scenes: [
        StoryScene(
          id: 'weave',
          caption: 'A new gamosa is woven on the loom.',
          icon: Icons.texture_rounded,
          color: Color(0xFFC62828),
          description: 'Cloth being woven on a wooden loom.',
        ),
        StoryScene(
          id: 'cook',
          caption: 'Pitha are cooked over the fire.',
          icon: Icons.bakery_dining_rounded,
          color: Color(0xFFB26500),
          description: 'Rice cakes cooking on a fire.',
        ),
        StoryScene(
          id: 'tune',
          caption: 'The dhol is tightened in the courtyard.',
          icon: Icons.music_note_rounded,
          color: Color(0xFF8D4004),
          description: 'A drum being tightened by hand.',
        ),
        StoryScene(
          id: 'dance',
          caption: 'In the evening, everyone dances together.',
          icon: Icons.celebration_rounded,
          color: Color(0xFF6A1B9A),
          description: 'People dancing together in a courtyard.',
        ),
      ],
    ),

    // Five scenes: used on Hard.
    CulturalStory(
      id: 'muga_shawl',
      title: 'How the golden shawl was made',
      origin: ContentOrigin.original,
      attribution:
          'Written for MindPal. It describes how muga silk is produced in '
          'Assam, but it is not a traditional tale, and MindPal does not call '
          'it one.',
      text:
          'Muga silk comes from Assam, and it is golden without being dyed. '
          'The silkworms are reared outdoors on the leaves of som trees. When '
          'they have finished feeding, each one spins a cocoon, and the '
          'cocoons are gathered from the branches. The thread is drawn off the '
          'cocoons and wound onto a reel. The reeled thread is woven into '
          'cloth on a loom. At the end, the finished shawl is folded and kept '
          'for a wedding.',
      hint: 'Follow the thread: it has to exist before it can be woven.',
      explanation:
          'The worms feed first, then spin their cocoons. The thread is drawn '
          'off the cocoons, so that comes next. Only then can it be woven. The '
          'finished shawl is put away last.',
      scenes: [
        StoryScene(
          id: 'feed',
          caption: 'The silkworms feed on som leaves.',
          icon: Icons.park_rounded,
          color: Color(0xFF2E7D32),
          description: 'Silkworms feeding on the leaves of a tree.',
        ),
        StoryScene(
          id: 'cocoon',
          caption: 'Each worm spins a cocoon.',
          icon: Icons.egg_rounded,
          color: Color(0xFF9A6700),
          description: 'Cocoons hanging among branches.',
        ),
        StoryScene(
          id: 'reel',
          caption: 'The thread is wound onto a reel.',
          icon: Icons.donut_large_rounded,
          color: Color(0xFF00838F),
          description: 'Silk thread being wound onto a reel.',
        ),
        StoryScene(
          id: 'weave',
          caption: 'The thread is woven into cloth.',
          icon: Icons.texture_rounded,
          color: Color(0xFFB26500),
          description: 'Golden cloth being woven on a loom.',
        ),
        StoryScene(
          id: 'fold',
          caption: 'The finished shawl is folded and kept.',
          icon: Icons.inventory_2_rounded,
          color: Color(0xFF5D4037),
          description: 'A folded golden shawl put away in a box.',
        ),
      ],
    ),
  ],
);
