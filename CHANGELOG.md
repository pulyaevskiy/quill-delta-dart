## 1.1.3

* Reverted last change to operation value type and will publish it as a major version update
  since it's breaking existing users.

## 1.1.2

* Changed operation value type from `dynamic` to `Object` to allow better static analysis.
  If you get analyzer errors after this change you must add an explicit type cast on the operation
  value to the desired class.

## 1.1.1

* Fix iterator for custom embed objects (#14)

## 1.1.0

* Changed insert operations to allow inserting dynamic object values. (#13)
  Object values must be JSON-serializable.

## 1.0.2

* Fix attributes comparison for operations when attributes have complex values (maps, lists).

## 1.0.1

* Fixed assertion error for sequences of insert-delete-insert operations.

## 1.0.0

* Added `Delta.invert()`, `Delta.slice()` and `Delta.invertAttributes()`.

## 1.0.0-dev.4.0

* Internal clean-up replacing hardcoded strings with constants.

## 1.0.0-dev.3.0

* Updated dependency on quiver_hashcode.

## 1.0.0-dev.2.0

* Prepare for Dart 2 stable.

## 1.0.0-dev.1.0

* Initial release.
