## Implementation of Quill editor Delta format in Dart.

See official [documentation][] for more details.

[documentation]: https://quilljs.com/docs/delta/

## Usage

```dart
import 'package:quill_delta/quill_delta.dart';

void main() {
  var delta = new Delta();
  delta..insert('Hello world');
  var change = new Delta()
    ..retain(6)
    ..delete(5)
    ..insert('Earth');
  var result = delta.compose(change);
  print(delta);
  print(change);
  print(result);

  // Prints:
  // Delta[insert("Hello world")]
  // Delta[retain(6), insert("Earth"), delete(5)]
  // Delta[insert("Hello Earth")]
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/pulyaevskiy/dart-quill-delta/issues
