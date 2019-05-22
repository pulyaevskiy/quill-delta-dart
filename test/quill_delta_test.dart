// Copyright (c) 2018, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'dart:convert';

import 'package:quill_delta/quill_delta.dart';
import 'package:test/test.dart';

void main() {
  group('invertAttributes', () {
    test("attributes is null", () {
      expect(Delta.invertAttributes(null, {'b': true}), {});
    });

    test("base is null", () {
      expect(Delta.invertAttributes({'b': true}, null), {'b': null});
    });

    test("both is null", () {
      expect(Delta.invertAttributes(null, null), {});
    });

    test("missing", () {
      expect(Delta.invertAttributes({'b': null}, {'b': true}), {'b': true});
    });

    test("overrite", () {
      expect(
          Delta.invertAttributes({'s': '10px'}, {'s': '12px'}), {'s': '12px'});
    });

    test("remove", () {
      expect(Delta.invertAttributes({'b': true}, {'b': true}), {});
    });

    test("combined", () {
      var attributes = {'b': true, 'i': null, 'c': 'red', 's': '12px'};
      var base = {'f': 'serif', 'i': true, 'c': 'blue', 's': '12px'};
      var expected = {'b': null, 'i': true, 'c': 'blue'};
      expect(Delta.invertAttributes(attributes, base), expected);
    });
  });

  group('composeAttributes', () {
    final attributes = const {'b': true, 'color': 'red'};

    test('left is null', () {
      expect(Delta.composeAttributes(null, attributes), attributes);
    });

    test('right is null', () {
      expect(Delta.composeAttributes(attributes, null), attributes);
    });

    test('both are null', () {
      expect(Delta.composeAttributes(null, null), isNull);
    });

    test('missing', () {
      expect(Delta.composeAttributes(attributes, const {'i': true}),
          {'b': true, 'color': 'red', 'i': true});
    });

    test('overwrite', () {
      expect(
          Delta.composeAttributes(
              attributes, const {'b': false, 'color': 'blue'}),
          {'b': false, 'color': 'blue'});
    });

    test('remove', () {
      expect(Delta.composeAttributes(attributes, const {'b': null}),
          {'color': 'red'});
    });

    test('remove to null', () {
      expect(
          Delta.composeAttributes(attributes, const {'b': null, 'color': null}),
          isNull);
    });

    test('remove missing', () {
      expect(
          Delta.composeAttributes(attributes, const {'i': null}), attributes);
    });
  });

  group('transformAttributes', () {
    final left = const {'bold': true, 'color': 'red', 'font': null};
    final right = const {'color': 'blue', 'font': 'serif', 'italic': true};

    test('left is null', () {
      expect(Delta.transformAttributes(null, left, false), left);
    });

    test('right is null', () {
      expect(Delta.transformAttributes(left, null, false), null);
    });

    test('both are null', () {
      expect(Delta.transformAttributes(null, null, false), null);
    });

    test('with priority', () {
      expect(
          Delta.transformAttributes(left, right, true), const {'italic': true});
    });

    test('without priority', () {
      expect(Delta.transformAttributes(left, right, false), right);
    });
  });

  group('$Operation', () {
    test('insert factory', () {
      final op = new Operation.insert('a', const {'b': true});
      expect(op.isInsert, isTrue);
      expect(op.length, 1);
      expect(op.attributes, const {'b': true});
    });

    test('delete factory', () {
      final op = new Operation.delete(5);
      expect(op.isDelete, isTrue);
      expect(op.length, 5);
      expect(op.attributes, isNull);
    });

    test('retain factory', () {
      final op = new Operation.retain(5, const {'b': true});
      expect(op.isRetain, isTrue);
      expect(op.length, 5);
      expect(op.attributes, const {'b': true});
    });

    test('isPlain', () {
      final op1 = new Operation.retain(1);
      final op2 = new Operation.retain(1, {});
      final op3 = new Operation.retain(1, {'b': true});
      expect(op1.isPlain, isTrue);
      expect(op2.isPlain, isTrue);
      expect(op3.isPlain, isFalse);
      expect(op1.isNotPlain, isFalse);
      expect(op2.isNotPlain, isFalse);
      expect(op3.isNotPlain, isTrue);
    });

    test('isEmpty', () {
      final op1 = new Operation.retain(0);
      final op2 = new Operation.retain(0, {});
      final op3 = new Operation.retain(1);
      expect(op1.isEmpty, isTrue);
      expect(op2.isEmpty, isTrue);
      expect(op3.isEmpty, isFalse);
      expect(op1.isNotEmpty, isFalse);
      expect(op2.isNotEmpty, isFalse);
      expect(op3.isNotEmpty, isTrue);
    });

    test('equality', () {
      final op1 = new Operation.insert('a');
      final op2 = new Operation.insert('b', const {'h': '1', 'b': true});
      final op3 = new Operation.insert('b', const {'h': true, 'b': '1'});
      final op4 = new Operation.insert('a');
      expect(op1, isNot(op2));
      expect(op2, isNot(op3));
      expect(op1, op4);
    });

    test('hashCode', () {
      final op1 = new Operation.insert('b', const {'h': '1', 'b': true});
      final op2 = new Operation.insert('b', const {'h': '1', 'b': true});
      final op3 = new Operation.insert('b', const {'h': true, 'b': '1'});
      expect(op2.hashCode, isNot(op3.hashCode));
      expect(op2.hashCode, op1.hashCode);
    });

    test('toString', () {
      var op1 = new Operation.insert(
          'Hello world!\nAnd fancy line-breaks.\n', {'b': true});
      var op2 = new Operation.retain(3, {'b': '1'});
      var op3 = new Operation.delete(3);
      expect(
          "$op1", 'insert⟨ Hello world!⏎And fancy line-breaks.⏎ ⟩ + {b: true}');
      expect("$op2", 'retain⟨ 3 ⟩ + {b: 1}');
      expect("$op3", 'delete⟨ 3 ⟩');
    });

    test('attributes immutable', () {
      var op = new Operation.insert('\n', {'b': true});
      var attrs = op.attributes;
      attrs['b'] = null;
      expect(op.attributes, {'b': true});
    });
  });

  group('Delta', () {
    test('isEmpty', () {
      final delta = new Delta();
      expect(delta, isEmpty);
    });

    test('json', () {
      final delta = new Delta()..insert('abc', {'b': true})..insert('def');
      final result = json.encode(delta);
      expect(result,
          '[{"insert":"abc","attributes":{"b":true}},{"insert":"def"}]');
      final decoded = Delta.fromJson(json.decode(result));
      expect(decoded, delta);
    });

    test('toString', () {
      final delta = new Delta()
        ..insert('Hello world!', {'b': true})
        ..retain(5);
      expect("$delta", 'insert⟨ Hello world! ⟩ + {b: true}\nretain⟨ 5 ⟩');
    });

    group("invert", () {
      test('insert', () {
        final delta = new Delta()
          ..retain(2)
          ..insert('A');
        final base = new Delta()..insert('123456');
        final expected = new Delta()
          ..retain(2)
          ..delete(1);
        final inverted = delta.invert(base);
        expect(expected, inverted);
        expect(base.compose(delta).compose(inverted), base);
      });

      test('delete', () {
        final delta = new Delta()
          ..retain(2)
          ..delete(3);
        final base = new Delta()..insert('123456');
        final expected = new Delta()
          ..retain(2)
          ..insert('345');
        final inverted = delta.invert(base);
        expect(expected, inverted);
        expect(base.compose(delta).compose(inverted), base);
      });

      test('retain', () {
        final delta = new Delta()..retain(2)..retain(3, {'b': true});
        final base = new Delta()..insert('123456');
        final expected = new Delta()..retain(2)..retain(3, {'b': null});
        final inverted = delta.invert(base);
        expect(expected, inverted);
        expect(base.compose(delta).compose(inverted), base);
      });

      test('retain on a delta with different attributes', () {
        final base = new Delta()..insert('123')..insert('4', {'b': true});
        final delta = new Delta()..retain(4, {'i': true});
        final expected = new Delta()..retain(4, {'i': null});
        final inverted = delta.invert(base);
        expect(expected, inverted);
        expect(base.compose(delta).compose(inverted), base);
      });
    });

    group('push', () {
      // ==== insert combinations ====

      test('insert + insert', () {
        final delta = new Delta()..insert('abc')..insert('123');
        expect(delta.first, new Operation.insert('abc123'));
      });

      test('insert + delete', () {
        final delta = new Delta()
          ..insert('abc')
          ..delete(3);
        expect(delta[0], new Operation.insert('abc'));
        expect(delta[1], new Operation.delete(3));
      });

      test('insert + retain', () {
        final delta = new Delta()
          ..insert('abc')
          ..retain(3);
        expect(delta[0], new Operation.insert('abc'));
        expect(delta[1], new Operation.retain(3));
      });

      // ==== delete combinations ====

      test('delete + insert', () {
        final delta = new Delta()
          ..delete(2)
          ..insert('abc');
        expect(delta[0], new Operation.insert('abc'));
        expect(delta[1], new Operation.delete(2));
      });

      test('delete + delete', () {
        final delta = new Delta()..delete(2)..delete(3);
        expect(delta.first, new Operation.delete(5));
      });

      test('delete + retain', () {
        final delta = new Delta()
          ..delete(2)
          ..retain(3);
        expect(delta[0], new Operation.delete(2));
        expect(delta[1], new Operation.retain(3));
      });

      // ==== retain combinations ====

      test('retain + insert', () {
        final delta = new Delta()
          ..retain(2)
          ..insert('abc');
        expect(delta[0], new Operation.retain(2));
        expect(delta[1], new Operation.insert('abc'));
      });

      test('retain + delete', () {
        final delta = new Delta()
          ..retain(2)
          ..delete(3);
        expect(delta[0], new Operation.retain(2));
        expect(delta[1], new Operation.delete(3));
      });

      test('retain + retain', () {
        final delta = new Delta()..retain(2)..retain(3);
        expect(delta.first, new Operation.retain(5));
      });

      // ==== edge scenarios ====

      test('consequent inserts with different attributes do not merge', () {
        final delta = new Delta()
          ..insert('abc', const {'b': true})
          ..insert('123');
        expect(delta.toList(), [
          new Operation.insert('abc', const {'b': true}),
          new Operation.insert('123'),
        ]);
      });

      test('consequent retain with different attributes do not merge', () {
        final delta = new Delta()..retain(5, const {'b': true})..retain(3);
        expect(delta.toList(), [
          new Operation.retain(5, const {'b': true}),
          new Operation.retain(3),
        ]);
      });

      test('consequent inserts with same attributes merge', () {
        final ul = {'block': 'ul'};
        final doc = new Delta()
          ..insert('DartConf')
          ..insert('\n', ul)
          ..insert('Los Angeles')
          ..insert('\n', ul);
        final change = new Delta()
          ..retain(8)
          ..insert('\n', ul);
        final result = doc.compose(change);
        final expected = new Delta()
          ..insert('DartConf')
          ..insert('\n\n', ul)
          ..insert('Los Angeles')
          ..insert('\n', ul);
        expect(result, expected);
      });
    });

    group('compose', () {
      // ==== insert combinations ====

      test('insert + insert', () {
        final a = new Delta()..insert('A');
        final b = new Delta()..insert('B');
        final expected = new Delta()..insert('BA');
        expect(a.compose(b), expected);
      });

      test('insert + delete', () {
        final a = new Delta()..insert('A');
        final b = new Delta()..delete(1);
        expect(a.compose(b), isEmpty);
      });

      test('insert + retain', () {
        final a = new Delta()..insert('A');
        final b = new Delta()..retain(1, const {'b': true});
        expect(a.compose(b).toList(), [
          new Operation.insert('A', const {'b': true})
        ]);
      });

      // ==== delete combinations ====

      test('delete + insert', () {
        final a = new Delta()..delete(1);
        final b = new Delta()..insert('B');
        final expected = new Delta()
          ..insert('B')
          ..delete(1);
        expect(a.compose(b), expected);
      });

      test('delete + delete', () {
        final a = new Delta()..delete(1);
        final b = new Delta()..delete(1);
        final expected = new Delta()..delete(2);
        expect(a.compose(b), expected);
      });

      test('delete + retain', () {
        final a = new Delta()..delete(1);
        final b = new Delta()..retain(1, const {'b': true});
        final expected = new Delta()
          ..delete(1)
          ..retain(1, const {'b': true});
        expect(a.compose(b), expected);
      });

      // ==== retain combinations ====

      test('retain + insert', () {
        final a = new Delta()..retain(1, const {'b': true});
        final b = new Delta()..insert('B');
        final expected = new Delta()
          ..insert('B')
          ..retain(1, const {'b': true});
        expect(a.compose(b), expected);
      });

      test('retain + delete', () {
        final a = new Delta()..retain(1, const {'b': true});
        final b = new Delta()..delete(1);
        final expected = new Delta()..delete(1);
        expect(a.compose(b), expected);
      });

      test('retain + retain', () {
        final a = new Delta()..retain(1, const {'color': 'blue'});
        final b = new Delta()..retain(1, const {'color': 'red', 'b': true});
        final expected = new Delta()
          ..retain(1, const {'color': 'red', 'b': true});
        expect(a.compose(b), expected);
      });

      // ===== other scenarios =====

      test('insert in middle of text', () {
        final a = new Delta()..insert('Hello');
        final b = new Delta()
          ..retain(3)
          ..insert('X');
        final expected = new Delta()..insert('HelXlo');
        expect(a.compose(b), expected);
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
        expect(a.compose(insertFirst), expected);
        expect(b.compose(deleteFirst), expected);
      });

      test('delete entire text', () {
        final a = new Delta()
          ..retain(4)
          ..insert('Hello');
        final b = new Delta()..delete(9);
        final expected = new Delta()..delete(4);
        expect(a.compose(b), expected);
      });

      test('retain more than length of text', () {
        final a = new Delta()..insert('Hello');
        final b = new Delta()..retain(10);
        final expected = new Delta()..insert('Hello');
        expect(a.compose(b), expected);
      });

      test('remove all attributes', () {
        final a = new Delta()..insert('A', const {'b': true});
        final b = new Delta()..retain(1, const {'b': null});
        final expected = new Delta()..insert('A');
        expect(a.compose(b), expected);
      });
    });

    group('transform', () {
      test('insert + insert', () {
        var a1 = new Delta()..insert('A');
        var b1 = new Delta()..insert('B');
        var a2 = new Delta.from(a1);
        var b2 = new Delta.from(b1);
        var expected1 = new Delta()
          ..retain(1)
          ..insert('B');
        var expected2 = new Delta()..insert('B');
        expect(a1.transform(b1, true), expected1);
        expect(a2.transform(b2, false), expected2);
      });

      test('insert + retain', () {
        var a = new Delta()..insert('A');
        var b = new Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var expected = new Delta()
          ..retain(1)
          ..retain(1, const {'bold': true, 'color': 'red'});
        expect(a.transform(b, true), expected);
      });

      test('insert + delete', () {
        var a = new Delta()..insert('A');
        var b = new Delta()..delete(1);
        var expected = new Delta()
          ..retain(1)
          ..delete(1);
        expect(a.transform(b, true), expected);
      });

      test('delete + insert', () {
        var a = new Delta()..delete(1);
        var b = new Delta()..insert('B');
        var expected = new Delta()..insert('B');
        expect(a.transform(b, true), expected);
      });

      test('delete + retain', () {
        var a = new Delta()..delete(1);
        var b = new Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var expected = new Delta();
        expect(a.transform(b, true), expected);
      });

      test('delete + delete', () {
        var a = new Delta()..delete(1);
        var b = new Delta()..delete(1);
        var expected = new Delta();
        expect(a.transform(b, true), expected);
      });

      test('retain + insert', () {
        var a = new Delta()..retain(1, const {'color': 'blue'});
        var b = new Delta()..insert('B');
        var expected = new Delta()..insert('B');
        expect(a.transform(b, true), expected);
      });

      test('retain + retain', () {
        var a1 = new Delta()..retain(1, const {'color': 'blue'});
        var b1 = new Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var a2 = new Delta()..retain(1, const {'color': 'blue'});
        var b2 = new Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var expected1 = new Delta()..retain(1, const {'bold': true});
        var expected2 = new Delta();
        expect(a1.transform(b1, true), expected1);
        expect(b2.transform(a2, true), expected2);
      });

      test('retain + retain without priority', () {
        var a1 = new Delta()..retain(1, const {'color': 'blue'});
        var b1 = new Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var a2 = new Delta()..retain(1, const {'color': 'blue'});
        var b2 = new Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var expected1 = new Delta()
          ..retain(1, const {'bold': true, 'color': 'red'});
        var expected2 = new Delta()..retain(1, const {'color': 'blue'});
        expect(a1.transform(b1, false), expected1);
        expect(b2.transform(a2, false), expected2);
      });

      test('retain + delete', () {
        var a = new Delta()..retain(1, const {'color': 'blue'});
        var b = new Delta()..delete(1);
        var expected = new Delta()..delete(1);
        expect(a.transform(b, true), expected);
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
        var a2 = new Delta.from(a1);
        var b2 = new Delta.from(b1);
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
        expect(a1.transform(b1, false), expected1);
        expect(b2.transform(a2, false), expected2);
      });

      test('conflicting appends', () {
        var a1 = new Delta()
          ..retain(3)
          ..insert('aa');
        var b1 = new Delta()
          ..retain(3)
          ..insert('bb');
        var a2 = new Delta.from(a1);
        var b2 = new Delta.from(b1);
        var expected1 = new Delta()
          ..retain(5)
          ..insert('bb');
        var expected2 = new Delta()
          ..retain(3)
          ..insert('aa');
        expect(a1.transform(b1, true), expected1);
        expect(b2.transform(a2, false), expected2);
      });

      test('prepend + append', () {
        var a1 = new Delta()..insert('aa');
        var b1 = new Delta()
          ..retain(3)
          ..insert('bb');
        var expected1 = new Delta()
          ..retain(5)
          ..insert('bb');
        var a2 = new Delta.from(a1);
        var b2 = new Delta.from(b1);
        var expected2 = new Delta()..insert('aa');
        expect(a1.transform(b1, false), expected1);
        expect(b2.transform(a2, false), expected2);
      });

      test('trailing deletes with differing lengths', () {
        var a1 = new Delta()
          ..retain(2)
          ..delete(1);
        var b1 = new Delta()..delete(3);
        var expected1 = new Delta()..delete(2);
        var a2 = new Delta.from(a1);
        var b2 = new Delta.from(b1);
        var expected2 = new Delta();
        expect(a1.transform(b1, false), expected1);
        expect(b2.transform(a2, false), expected2);
      });
    });

    group('transformPosition', () {
      test('insert before position', () {
        var delta = new Delta()..insert('A');
        expect(delta.transformPosition(2), 3);
      });

      test('insert after position', () {
        var delta = new Delta()
          ..retain(2)
          ..insert('A');
        expect(delta.transformPosition(1), 1);
      });

      test('insert at position', () {
        var delta = new Delta()
          ..retain(2)
          ..insert('A');
        expect(delta.transformPosition(2, force: false), 2);
        expect(delta.transformPosition(2, force: true), 3);
      });

      test('delete before position', () {
        var delta = new Delta()..delete(2);
        expect(delta.transformPosition(4), 2);
      });

      test('delete after position', () {
        var delta = new Delta()
          ..retain(4)
          ..delete(2);
        expect(delta.transformPosition(2), 2);
      });

      test('delete across position', () {
        var delta = new Delta()
          ..retain(1)
          ..delete(4);
        expect(delta.transformPosition(2), 1);
      });

      test('insert and delete before position', () {
        var delta = new Delta()
          ..retain(2)
          ..insert('A')
          ..delete(2);
        expect(delta.transformPosition(4), 3);
      });

      test('insert before and delete across position', () {
        var delta = new Delta()
          ..retain(2)
          ..insert('A')
          ..delete(4);
        expect(delta.transformPosition(4), 3);
      });

      test('delete before and delete across position', () {
        var delta = new Delta()
          ..delete(1)
          ..retain(1)
          ..delete(4);
        expect(delta.transformPosition(4), 1);
      });
    });
  });

  group('$DeltaIterator', () {
    Delta delta = new Delta()
      ..insert('Hello', {'b': true})
      ..retain(3)
      ..insert(' world', {'i': true})
      ..delete(4);
    DeltaIterator iterator;

    setUp(() {
      iterator = new DeltaIterator(delta);
    });

    test('hasNext', () {
      expect(iterator.hasNext, isTrue);
      iterator..next()..next()..next()..next();
      expect(iterator.hasNext, isFalse);
    });

    test('peekLength', () {
      expect(iterator.peekLength(), 5);
      iterator.next();
      expect(iterator.peekLength(), 3);
      iterator.next();
      expect(iterator.peekLength(), 6);
      iterator.next();
      expect(iterator.peekLength(), 4);
      iterator.next();
    });

    test('peekLength with operation split', () {
      iterator.next(2);
      expect(iterator.peekLength(), 5 - 2);
    });

    test('peekLength after EOF', () {
      iterator.skip(18);
      expect(iterator.peekLength(), double.infinity);
    });

    test('peek operation type', () {
      expect(iterator.isNextInsert, isTrue);
      iterator.next();
      expect(iterator.isNextRetain, isTrue);
      iterator.next();
      expect(iterator.isNextInsert, isTrue);
      iterator.next();
      expect(iterator.isNextDelete, isTrue);
      iterator.next();
    });

    test('next', () {
      expect(iterator.next(), new Operation.insert('Hello', {'b': true}));
      expect(iterator.next(), new Operation.retain(3));
      expect(iterator.next(), new Operation.insert(' world', {'i': true}));
      expect(iterator.next(), new Operation.delete(4));
    });

    test('next with operation split', () {
      expect(iterator.next(2), new Operation.insert('He', {'b': true}));
      expect(iterator.next(10), new Operation.insert('llo', {'b': true}));
      expect(iterator.next(1), new Operation.retain(1));
      expect(iterator.next(2), new Operation.retain(2));
    });
  });
}
