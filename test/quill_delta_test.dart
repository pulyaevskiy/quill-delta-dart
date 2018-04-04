import 'dart:convert';

// Copyright (c) 2018, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:quill_delta/quill_delta.dart';
import 'package:test/test.dart';

void main() {
  group('composeAttributes', () {
    final attributes = const {'b': '1', 'color': 'red'};

    test('left is null', () {
      expect(composeAttributes(null, attributes), attributes);
    });

    test('right is null', () {
      expect(composeAttributes(attributes, null), attributes);
    });

    test('both are null', () {
      expect(composeAttributes(null, null), isNull);
    });

    test('missing', () {
      expect(composeAttributes(attributes, const {'i': '1'}),
          {'b': '1', 'color': 'red', 'i': '1'});
    });

    test('overwrite', () {
      expect(composeAttributes(attributes, const {'b': '0', 'color': 'blue'}),
          {'b': '0', 'color': 'blue'});
    });

    test('remove', () {
      expect(
          composeAttributes(attributes, const {'b': null}), {'color': 'red'});
    });

    test('remove to null', () {
      expect(composeAttributes(attributes, const {'b': null, 'color': null}),
          isNull);
    });

    test('remove missing', () {
      expect(composeAttributes(attributes, const {'i': null}), attributes);
    });
  });

  group('transformAttributes', () {
    final left = const {'bold': true, 'color': 'red', 'font': null};
    final right = const {'color': 'blue', 'font': 'serif', 'italic': true};

    test('left is null', () {
      expect(transformAttributes(null, left, false), left);
    });

    test('right is null', () {
      expect(transformAttributes(left, null, false), null);
    });

    test('both are null', () {
      expect(transformAttributes(null, null, false), null);
    });

    test('with priority', () {
      expect(transformAttributes(left, right, true), const {'italic': true});
    });

    test('without priority', () {
      expect(transformAttributes(left, right, false), right);
    });
  });

  group('$Operation', () {
    test('insert factory', () {
      final op = new Operation.insert('a', const {'b': '1'});
      expect(op.isInsert, isTrue);
      expect(op.length, 1);
      expect(op.attributes, const {'b': '1'});
    });

    test('delete factory', () {
      final op = new Operation.delete(5);
      expect(op.isDelete, isTrue);
      expect(op.length, 5);
      expect(op.attributes, isNull);
    });

    test('retain factory', () {
      final op = new Operation.retain(5, const {'b': '1'});
      expect(op.isRetain, isTrue);
      expect(op.length, 5);
      expect(op.attributes, const {'b': '1'});
    });

    test('isNoOp', () {
      final op2 = new Operation.retain(1);
      final op3 = new Operation.insert('a');
      final op4 = new Operation.delete(1);
      final op8 = new Operation.retain(1, const {'b': '1'});
      expect(op2.isNoOp, isTrue);
      expect(op3.isNoOp, isFalse);
      expect(op4.isNoOp, isFalse);
      expect(op8.isNoOp, isFalse);
    });

    test('equality', () {
      final op1 = new Operation.insert('a');
      final op2 = new Operation.insert('b', const {'h': '1', 'b': 'true'});
      final op3 = new Operation.insert('b', const {'h': 'true', 'b': '1'});
      final op4 = new Operation.insert('a');
      expect(op1, isNot(op2));
      expect(op2, isNot(op3));
      expect(op1, op4);
    });

    test('hashCode', () {
      final op1 = new Operation.insert('b', const {'h': '1', 'b': 'true'});
      final op2 = new Operation.insert('b', const {'h': '1', 'b': 'true'});
      final op3 = new Operation.insert('b', const {'h': 'true', 'b': '1'});
      expect(op2.hashCode, isNot(op3.hashCode));
      expect(op2.hashCode, op1.hashCode);
    });

    test('toString', () {
      var op1 = new Operation.insert('Hello world!\nAnd fancy line-breaks.\n');
      var op2 = new Operation.retain(3);
      var op3 = new Operation.delete(3);
      expect("$op1", 'insert("Hello world!⏎And fancy line-breaks.⏎")');
      expect("$op2", 'retain(3)');
      expect("$op3", 'delete(3)');
    });
  });

  group('Delta', () {
    test('new is empty', () {
      final delta = new Delta();
      expect(delta.operations, isEmpty);
    });

    test('no-op', () {
      final delta = new Delta();
      expect(delta.isNoOp, isTrue);
      delta.retain(1);
      expect(delta.isNoOp, isTrue);
    });

    test('json', () {
      final delta = new Delta()..insert('abc', {'bold': true});
      final result = json.encode(delta);
      expect(result, '[{"insert":"abc","attributes":{"bold":true}}]');
      final decoded = Delta.fromJson(json.decode(result));
      expect(decoded, delta);
    });

    group('push', () {
      // ==== insert combinations ====

      test('insert + insert', () {
        final delta = new Delta()..insert('abc')..insert('123');
        expect(delta.operations, [new Operation.insert('abc123')]);
      });

      test('insert + delete', () {
        final delta = new Delta()
          ..insert('abc')
          ..delete(3);
        expect(delta.operations,
            [new Operation.insert('abc'), new Operation.delete(3)]);
      });

      test('insert + retain', () {
        final delta = new Delta()
          ..insert('abc')
          ..retain(3);
        expect(delta.operations,
            [new Operation.insert('abc'), new Operation.retain(3)]);
      });

      // ==== delete combinations ====

      test('delete + insert', () {
        final delta = new Delta()
          ..delete(2)
          ..insert('abc');
        expect(delta.operations,
            [new Operation.insert('abc'), new Operation.delete(2)]);
      });

      test('delete + delete', () {
        final delta = new Delta()..delete(2)..delete(3);
        expect(delta.operations, [new Operation.delete(5)]);
      });

      test('delete + retain', () {
        final delta = new Delta()
          ..delete(2)
          ..retain(3);
        expect(delta.operations,
            [new Operation.delete(2), new Operation.retain(3)]);
      });

      // ==== retain combinations ====

      test('retain + insert', () {
        final delta = new Delta()
          ..retain(2)
          ..insert('abc');
        expect(delta.operations,
            [new Operation.retain(2), new Operation.insert('abc')]);
      });

      test('retain + delete', () {
        final delta = new Delta()
          ..retain(2)
          ..delete(3);
        expect(delta.operations,
            [new Operation.retain(2), new Operation.delete(3)]);
      });

      test('retain + retain', () {
        final delta = new Delta()..retain(2)..retain(3);
        expect(delta.operations, [new Operation.retain(5)]);
      });

      // ==== edge scenarios ====

      test('consequent inserts with different attributes do not merge', () {
        final delta = new Delta()
          ..insert('abc', const {'b': 'true'})
          ..insert('123');
        expect(delta.operations, [
          new Operation.insert('abc', const {'b': 'true'}),
          new Operation.insert('123'),
        ]);
      });

      test('consequent retain with different attributes do not merge', () {
        final delta = new Delta()..retain(5, const {'b': '1'})..retain(3);
        expect(delta.operations, [
          new Operation.retain(5, const {'b': '1'}),
          new Operation.retain(3),
        ]);
      });
    });

    group('compose', () {
      // ==== insert combinations ====

      test('insert + insert', () {
        final a = new Delta()..insert('A');
        final b = new Delta()..insert('B');
        final expected = new Delta()..insert('BA');
        expect(a.compose(b).operations, expected.operations);
      });

      test('insert + delete', () {
        final a = new Delta()..insert('A');
        final b = new Delta()..delete(1);
        expect(a.compose(b).operations, isEmpty);
      });

      test('insert + retain', () {
        final a = new Delta()..insert('A');
        final b = new Delta()..retain(1, const {'b': '1'});
        expect(a.compose(b).operations, [
          new Operation.insert('A', const {'b': '1'})
        ]);
      });

      // ==== delete combinations ====

      test('delete + insert', () {
        final a = new Delta()..delete(1);
        final b = new Delta()..insert('B');
        final expected = new Delta()
          ..insert('B')
          ..delete(1);
        expect(a.compose(b).operations, expected.operations);
      });

      test('delete + delete', () {
        final a = new Delta()..delete(1);
        final b = new Delta()..delete(1);
        final expected = new Delta()..delete(2);
        expect(a.compose(b).operations, expected.operations);
      });

      test('delete + retain', () {
        final a = new Delta()..delete(1);
        final b = new Delta()..retain(1, const {'b': '1'});
        final expected = new Delta()
          ..delete(1)
          ..retain(1, const {'b': '1'});
        expect(a.compose(b).operations, expected.operations);
      });

      // ==== retain combinations ====

      test('retain + insert', () {
        final a = new Delta()..retain(1, const {'b': '1'});
        final b = new Delta()..insert('B');
        final expected = new Delta()
          ..insert('B')
          ..retain(1, const {'b': '1'});
        expect(a.compose(b).operations, expected.operations);
      });

      test('retain + delete', () {
        final a = new Delta()..retain(1, const {'b': '1'});
        final b = new Delta()..delete(1);
        final expected = new Delta()..delete(1);
        expect(a.compose(b).operations, expected.operations);
      });

      test('retain + retain', () {
        final a = new Delta()..retain(1, const {'color': 'blue'});
        final b = new Delta()..retain(1, const {'color': 'red', 'b': '1'});
        final expected = new Delta()
          ..retain(1, const {'color': 'red', 'b': '1'});
        expect(a.compose(b).operations, expected.operations);
      });

      // ===== other scenarios =====

      test('insert in middle of text', () {
        final a = new Delta()..insert('Hello');
        final b = new Delta()
          ..retain(3)
          ..insert('X');
        final expected = new Delta()..insert('HelXlo');
        expect(a.compose(b).operations, expected.operations);
      });

      test('insert and delete ordering', () {
        final a = new Delta()..insert('Hello');
        final b = new Delta()..insert('Hello');
        final insertFirst = new Delta()
          ..retain(3)
          ..insert('X')
          ..delete(1);
        final deleteFirst = new Delta()
          ..retain(3)
          ..delete(1)
          ..insert('X');
        final expected = new Delta()..insert('HelXo');
        expect(a.compose(insertFirst).operations, expected.operations);
        expect(b.compose(deleteFirst).operations, expected.operations);
      });

      test('delete entire text', () {
        final a = new Delta()
          ..retain(4)
          ..insert('Hello');
        final b = new Delta()..delete(9);
        final expected = new Delta()..delete(4);
        expect(a.compose(b).operations, expected.operations);
      });

      test('retain more than length of text', () {
        final a = new Delta()..insert('Hello');
        final b = new Delta()..retain(10);
        final expected = new Delta()..insert('Hello');
        expect(a.compose(b).operations, expected.operations);
      });

      test('remove all attributes', () {
        final a = new Delta()..insert('A', const {'b': '1'});
        final b = new Delta()..retain(1, const {'b': null});
        final expected = new Delta()..insert('A');
        expect(a.compose(b).operations, expected.operations);
      });
    });

    group('transform', () {
      test('insert + insert', () {
        var a1 = new Delta()..insert('A');
        var b1 = new Delta()..insert('B');
        var a2 = new Delta.fromOperations(a1.operations);
        var b2 = new Delta.fromOperations(b1.operations);
        var expected1 = new Delta()
          ..retain(1)
          ..insert('B');
        var expected2 = new Delta()..insert('B');
        expect(a1.transform(b1, true).operations, expected1.operations);
        expect(a2.transform(b2, false).operations, expected2.operations);
      });

      test('insert + retain', () {
        var a = new Delta()..insert('A');
        var b = new Delta()..retain(1, const {'bold': '1', 'color': 'red'});
        var expected = new Delta()
          ..retain(1)
          ..retain(1, const {'bold': '1', 'color': 'red'});
        expect(a.transform(b, true).operations, expected.operations);
      });

      test('insert + delete', () {
        var a = new Delta()..insert('A');
        var b = new Delta()..delete(1);
        var expected = new Delta()
          ..retain(1)
          ..delete(1);
        expect(a.transform(b, true).operations, expected.operations);
      });

      test('delete + insert', () {
        var a = new Delta()..delete(1);
        var b = new Delta()..insert('B');
        var expected = new Delta()..insert('B');
        expect(a.transform(b, true).operations, expected.operations);
      });

      test('delete + retain', () {
        var a = new Delta()..delete(1);
        var b = new Delta()..retain(1, const {'bold': '1', 'color': 'red'});
        var expected = new Delta();
        expect(a.transform(b, true).operations, expected.operations);
      });

      test('delete + delete', () {
        var a = new Delta()..delete(1);
        var b = new Delta()..delete(1);
        var expected = new Delta();
        expect(a.transform(b, true).operations, expected.operations);
      });

      test('retain + insert', () {
        var a = new Delta()..retain(1, const {'color': 'blue'});
        var b = new Delta()..insert('B');
        var expected = new Delta()..insert('B');
        expect(a.transform(b, true).operations, expected.operations);
      });

      test('retain + retain', () {
        var a1 = new Delta()..retain(1, const {'color': 'blue'});
        var b1 = new Delta()..retain(1, const {'bold': '1', 'color': 'red'});
        var a2 = new Delta()..retain(1, const {'color': 'blue'});
        var b2 = new Delta()..retain(1, const {'bold': '1', 'color': 'red'});
        var expected1 = new Delta()..retain(1, const {'bold': '1'});
        var expected2 = new Delta();
        expect(a1.transform(b1, true).operations, expected1.operations);
        expect(b2.transform(a2, true).operations, expected2.operations);
      });

      test('retain + retain without priority', () {
        var a1 = new Delta()..retain(1, const {'color': 'blue'});
        var b1 = new Delta()..retain(1, const {'bold': '1', 'color': 'red'});
        var a2 = new Delta()..retain(1, const {'color': 'blue'});
        var b2 = new Delta()..retain(1, const {'bold': '1', 'color': 'red'});
        var expected1 = new Delta()
          ..retain(1, const {'bold': '1', 'color': 'red'});
        var expected2 = new Delta()..retain(1, const {'color': 'blue'});
        expect(a1.transform(b1, false).operations, expected1.operations);
        expect(b2.transform(a2, false).operations, expected2.operations);
      });

      test('retain + delete', () {
        var a = new Delta()..retain(1, const {'color': 'blue'});
        var b = new Delta()..delete(1);
        var expected = new Delta()..delete(1);
        expect(a.transform(b, true).operations, expected.operations);
      });

      test('alternating edits', () {
        var a1 = new Delta()
          ..retain(2)
          ..insert('si')
          ..delete(5);
        var b1 = new Delta()
          ..retain(1)
          ..insert('e')
          ..delete(5)
          ..retain(1)
          ..insert('ow');
        var a2 = new Delta.fromOperations(a1.operations);
        var b2 = new Delta.fromOperations(b1.operations);
        var expected1 = new Delta()
          ..retain(1)
          ..insert('e')
          ..delete(1)
          ..retain(2)
          ..insert('ow');
        var expected2 = new Delta()
          ..retain(2)
          ..insert('si')
          ..delete(1);
        expect(a1.transform(b1, false).operations, expected1.operations);
        expect(b2.transform(a2, false).operations, expected2.operations);
      });

      test('conflicting appends', () {
        var a1 = new Delta()
          ..retain(3)
          ..insert('aa');
        var b1 = new Delta()
          ..retain(3)
          ..insert('bb');
        var a2 = new Delta.fromOperations(a1.operations);
        var b2 = new Delta.fromOperations(b1.operations);
        var expected1 = new Delta()
          ..retain(5)
          ..insert('bb');
        var expected2 = new Delta()
          ..retain(3)
          ..insert('aa');
        expect(a1.transform(b1, true).operations, expected1.operations);
        expect(b2.transform(a2, false).operations, expected2.operations);
      });

      test('prepend + append', () {
        var a1 = new Delta()..insert('aa');
        var b1 = new Delta()
          ..retain(3)
          ..insert('bb');
        var expected1 = new Delta()
          ..retain(5)
          ..insert('bb');
        var a2 = new Delta.fromOperations(a1.operations);
        var b2 = new Delta.fromOperations(b1.operations);
        var expected2 = new Delta()..insert('aa');
        expect(a1.transform(b1, false).operations, expected1.operations);
        expect(b2.transform(a2, false).operations, expected2.operations);
      });

      test('trailing deletes with differing lengths', () {
        var a1 = new Delta()
          ..retain(2)
          ..delete(1);
        var b1 = new Delta()..delete(3);
        var expected1 = new Delta()..delete(2);
        var a2 = new Delta.fromOperations(a1.operations);
        var b2 = new Delta.fromOperations(b1.operations);
        var expected2 = new Delta();
        expect(a1.transform(b1, false).operations, expected1.operations);
        expect(b2.transform(a2, false).operations, expected2.operations);
      });
    });
  });
}
