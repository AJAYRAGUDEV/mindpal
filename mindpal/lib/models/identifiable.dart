/// Anything that can be kept in a [JsonListStore].
///
/// This is an *interface*: it declares what a class must be able to do, but
/// contains no code itself. `Person implements Identifiable` is a promise that
/// a Person has an `id`.
///
/// Why it exists: JsonListStore is generic — it works with any type T. But to
/// find "the item with id 7" or to work out the next free id, it has to be
/// able to ask an item for its id. Without this interface, T could be anything
/// at all (an int, a String) and `item.id` would not compile.
///
/// `abstract interface class` means: cannot be instantiated, and other classes
/// may only `implement` it (not `extend` it).
abstract interface class Identifiable {
  int get id;
}
