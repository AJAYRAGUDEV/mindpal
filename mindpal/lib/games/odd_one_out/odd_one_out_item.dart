import 'package:flutter/material.dart';

/// The groups a round is built from.
///
/// The whole game rests on these being obviously different from one another.
/// A round is never "three red things and one blue thing" or "three big
/// animals and one small one" — those need a judgement call, and a judgement
/// call is not a memory exercise, it is a trick.
enum ItemCategory {
  vehicle(
    'Things that travel',
    'something that travels',
    'things that travel',
    Color(0xFF1565C0),
  ),
  food('Things to eat', 'a food', 'foods', Color(0xFF8F5000)),
  household(
    'Things at home',
    'something used at home',
    'things used at home',
    Color(0xFF5E35B1),
  ),
  nature(
    'Things outdoors',
    'something outdoors',
    'things you find outdoors',
    Color(0xFF2E7D32),
  ),

  // Added for the cultural packs. A pack's items are tagged with these, and a
  // deck only ever offers the categories it actually holds items for — so
  // these existing alongside the four above costs the everyday game nothing.
  instrument(
    'Musical instruments',
    'a musical instrument',
    'musical instruments',
    Color(0xFF8D4004),
  ),
  craft(
    'Handmade things',
    'a handmade thing',
    'handmade things',
    Color(0xFFC62828),
  ),
  farming(
    'Farming and the land',
    'used for farming',
    'things used for farming',
    Color(0xFF558B2F),
  );

  const ItemCategory(this.label, this.singular, this.many, this.color);

  /// "Musical instruments" — the heading form.
  final String label;

  /// "a musical instrument" — for the ONE odd item: "Pitha is a food."
  final String singular;

  /// "musical instruments" — for the REST of the board: "The others are all
  /// musical instruments."
  ///
  /// A separate field rather than a rule for adding "s", because the categories
  /// do not pluralise the same way — "Farming and the land" has no plural at
  /// all, and the first version of this produced "The others are all a handmade
  /// thing."
  final String many;

  final Color color;
}

/// One picture on the board.
///
/// Every item carries a NAME as well as an icon, and the name is shown on
/// screen. Without it the game becomes "can you identify this small pictogram",
/// which is a test of eyesight rather than of thinking.
class OddOneOutItem {
  const OddOneOutItem(
    this.label,
    this.icon,
    this.category, {
    this.description,
    this.fact,
  });

  final String label;
  final IconData icon;
  final ItemCategory category;

  /// A plain sentence for screen readers, and for a name that means nothing on
  /// its own. Null for the everyday items, whose labels explain themselves.
  final String? description;

  /// Offered after the answer is given, as part of the explanation.
  final String? fact;

  String get spokenLabel => description == null ? label : '$label. $description';
}

/// The item pool.
///
/// EIGHT per category, not six. The hardest board is nine tiles — eight from
/// one category plus one odd — so a pool of six would silently produce a
/// seven-tile board instead of a nine-tile one. The test at the bottom of
/// odd_one_out_test.dart guards this.
const List<OddOneOutItem> kOddOneOutItems = [
  // Things that travel
  OddOneOutItem('Car', Icons.directions_car_rounded, ItemCategory.vehicle),
  OddOneOutItem('Bus', Icons.directions_bus_rounded, ItemCategory.vehicle),
  OddOneOutItem('Train', Icons.train_rounded, ItemCategory.vehicle),
  OddOneOutItem('Bicycle', Icons.pedal_bike_rounded, ItemCategory.vehicle),
  OddOneOutItem('Aeroplane', Icons.flight_rounded, ItemCategory.vehicle),
  OddOneOutItem('Boat', Icons.sailing_rounded, ItemCategory.vehicle),
  OddOneOutItem('Scooter', Icons.two_wheeler_rounded, ItemCategory.vehicle),
  OddOneOutItem('Lorry', Icons.local_shipping_rounded, ItemCategory.vehicle),

  // Things to eat and drink
  OddOneOutItem('Cake', Icons.cake_rounded, ItemCategory.food),
  OddOneOutItem('Egg', Icons.egg_rounded, ItemCategory.food),
  OddOneOutItem('Ice cream', Icons.icecream_rounded, ItemCategory.food),
  OddOneOutItem('Bread', Icons.bakery_dining_rounded, ItemCategory.food),
  OddOneOutItem('Tea', Icons.local_cafe_rounded, ItemCategory.food),
  OddOneOutItem('Rice', Icons.rice_bowl_rounded, ItemCategory.food),
  OddOneOutItem('Milk', Icons.local_drink_rounded, ItemCategory.food),
  OddOneOutItem('Fish', Icons.set_meal_rounded, ItemCategory.food),

  // Things at home
  OddOneOutItem('Chair', Icons.chair_rounded, ItemCategory.household),
  OddOneOutItem('Bed', Icons.bed_rounded, ItemCategory.household),
  OddOneOutItem('Lamp', Icons.lightbulb_rounded, ItemCategory.household),
  OddOneOutItem('Door', Icons.door_front_door_rounded, ItemCategory.household),
  OddOneOutItem(
    'Clock',
    Icons.access_time_filled_rounded,
    ItemCategory.household,
  ),
  OddOneOutItem('Key', Icons.vpn_key_rounded, ItemCategory.household),
  OddOneOutItem('Television', Icons.tv_rounded, ItemCategory.household),
  OddOneOutItem('Sofa', Icons.weekend_rounded, ItemCategory.household),

  // Things outdoors
  OddOneOutItem('Flower', Icons.local_florist_rounded, ItemCategory.nature),
  OddOneOutItem('Tree', Icons.park_rounded, ItemCategory.nature),
  OddOneOutItem('Sun', Icons.wb_sunny_rounded, ItemCategory.nature),
  OddOneOutItem('Rain', Icons.water_drop_rounded, ItemCategory.nature),
  OddOneOutItem('Cloud', Icons.cloud_rounded, ItemCategory.nature),
  OddOneOutItem('Grass', Icons.grass_rounded, ItemCategory.nature),
  OddOneOutItem('Moon', Icons.nightlight_round, ItemCategory.nature),
  OddOneOutItem('Snow', Icons.ac_unit_rounded, ItemCategory.nature),
];

/// The items belonging to one category.
List<OddOneOutItem> itemsInCategory(ItemCategory category) =>
    kOddOneOutItems.where((item) => item.category == category).toList();

/// The set of pictures one game of Odd-One-Out draws its rounds from.
///
/// Introduced so a cultural pack can supply the tiles without the rules
/// changing. The everyday deck below reproduces exactly what the game did
/// before, which is why the existing tests still pass untouched.
///
/// A deck derives its categories from the items it actually holds, rather than
/// from `ItemCategory.values`. That is deliberate: the enum now has categories
/// the everyday pool has no items for, and a game that picked one of those
/// would deal an empty board.
class OddOneOutDeck {
  const OddOneOutDeck({required this.items, this.packId, this.label});

  final List<OddOneOutItem> items;

  /// The cultural pack these came from, recorded in the saved result. Null for
  /// the everyday deck.
  final String? packId;

  /// Shown on the game's own screen, e.g. "Assam: Bihu and everyday things".
  final String? label;

  /// The app's original twelve-category-free pool: exactly the previous
  /// behaviour, kept as the default.
  static const OddOneOutDeck everyday = OddOneOutDeck(items: kOddOneOutItems);

  /// The categories this deck can build a majority from — two items at least,
  /// otherwise a "group" of one is not a group.
  List<ItemCategory> get categories => [
    for (final category in ItemCategory.values)
      if (itemsIn(category).length >= 2) category,
  ];

  List<OddOneOutItem> itemsIn(ItemCategory category) =>
      items.where((item) => item.category == category).toList();

  /// The biggest board this deck can honestly fill.
  ///
  /// A nine-tile board needs eight items of one category plus one other. When a
  /// deck cannot manage that, the game deals the biggest board it can and says
  /// so, rather than quietly dealing seven tiles on Hard.
  int get largestBoard {
    var smallest = 0;
    for (final category in categories) {
      final count = itemsIn(category).length;
      if (smallest == 0 || count < smallest) smallest = count;
    }
    // +1 for the odd item, which comes from a different category.
    return smallest == 0 ? 0 : smallest + 1;
  }

  /// False when there is not even one valid round in here.
  bool get isPlayable => categories.length >= 2;
}
