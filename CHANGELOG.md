## 2.0.0

* **Breaking change**: changed `Operation.value` type from `dynamic` to `Object` to allow better
  static analysis and prevent bugs where operation value is always assumed to be a String object. 
  If you get analyzer errors after this change you must add an explicit type cast on the
  operation value to the desired type (String or the type of an embed).
* Added: `dataDecoder` parameter to `Delta.fromJson` and `Operation.fromJson`. Can be used to convert
  raw JSON values to concrete data types. Mainly useful with embedded data. Text data should always
  be `String`.
* Fixed: changed `Delta.fromJson` type of the `data` parameter to `List` so that this factory method
  can actually be used with the output of `jsonDecode`.

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
