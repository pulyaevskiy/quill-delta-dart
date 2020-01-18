[![Build Status](https://travis-ci.org/pulyaevskiy/quill-delta-dart.svg?branch=master)](https://travis-ci.org/pulyaevskiy/quill-delta-dart) [![codecov](https://codecov.io/gh/pulyaevskiy/quill-delta-dart/branch/master/graph/badge.svg)](https://codecov.io/gh/pulyaevskiy/quill-delta-dart) [![Pub](https://img.shields.io/pub/v/quill_delta.svg)](https://pub.dev/packages/quill_delta)

Implementation of Quill editor Delta format in Dart. Refer to official
[documentation][] for more details.

[documentation]: https://quilljs.com/docs/delta/

## Usage

```dart
import 'package:quill_delta/quill_delta.dart';

void main() {
  var doc = new Delta()..insert('Hello world', {'h': '1'});
  var change = new Delta()
    ..retain(6)
    ..delete(5)
    ..insert('Earth');
  var result = doc.compose(change);
  print('Original document:\n$doc\n');
  print('Change:\n$change\n');
  print('Updated document:\n$result\n');

  /// Prints:
  ///
  ///     Original document:
  ///     ins⟨Hello world⟩ + {h: 1}
  ///
  ///     Change:
  ///     ret⟨6⟩
  ///     ins⟨Earth⟩
  ///     del⟨5⟩
  ///
  ///     Updated document:
  ///     ins⟨Hello ⟩ + {h: 1}
  ///     ins⟨Earth⟩
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/pulyaevskiy/quill-delta-dart/issues
