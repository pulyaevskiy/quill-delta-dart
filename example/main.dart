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
