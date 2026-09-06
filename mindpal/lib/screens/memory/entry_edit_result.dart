/// What an edit form decided when it closed.
///
/// A form can end three ways: the user saved, the user deleted, or the user
/// backed out. Rather than inventing a signal for each (return the item?
/// return null? a separate callback?), the form pops one of these and the list
/// screen handles all three in one place.
///
///   * `null`                         -> user cancelled, do nothing
///   * `EntryEditResult.save(item)`   -> add it or update it
///   * `EntryEditResult.delete()`     -> remove it
///
/// `<T>` is the model type, so `EntryEditResult<Person>` carries a Person.
class EntryEditResult<T> {
  const EntryEditResult.save(T this.item) : deleted = false;

  const EntryEditResult.delete() : item = null, deleted = true;

  /// The edited item. Non-null exactly when [deleted] is false.
  final T? item;

  final bool deleted;
}
