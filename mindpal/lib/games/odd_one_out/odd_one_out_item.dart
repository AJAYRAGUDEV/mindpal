import 'package:flutter/material.dart';

/// The groups a round is built from.
///
/// The whole game rests on these being obviously different from one another.
/// A round is never "three red things and one blue thing" or "three big
/// animals and one small one" — those need a judgement call, and a judgement
/// call is not a memory exercise, it is a trick.
enum ItemCategory {
  vehicle('Things that travel', Color(0xFF1565C0)),
  food('Things to eat', Color(0xFF8F5000)),
  household('Things at home', Color(0xFF5E35B1)),
  nature('Things outdoors', Color(0xFF2E7D32));

  const ItemCategory(this.label, this.color);

  final String label;
  final Color color;
}

/// One picture on the board.
///
/// Every item carries a NAME as well as an icon, and the name is shown on
/// screen. Without it the game becomes "can you identify this small pictogram",
/// which is a test of eyesight rather than of thinking.
class OddOneOutItem {
  const OddOneOutItem(this.label, this.icon, this.category);

  final String label;
  final IconData icon;
  final ItemCategory category;
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
