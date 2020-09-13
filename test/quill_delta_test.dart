// Copyright (c) 2018, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.
import 'dart:convert';

import 'package:quill_delta/quill_delta.dart';
import 'package:test/test.dart';

void main() {
  group('invertAttributes', () {
    test('attr is null', () {
      var base = {'bold': true};
      expect(Delta.invertAttributes(null, base), {});
    });

    test('base is null', () {
      var attributes = {'bold': true};
      var expected = {'bold': null};
      expect(Delta.invertAttributes(attributes, null), expected);
    });

    test('both null', () {
      expect(Delta.invertAttributes(null, null), {});
    });

    test('merge', () {
      var attributes = {'bold': true};
      var base = {'italic': true};
      var expected = {'bold': null};
      expect(Delta.invertAttributes(attributes, base), expected);
    });

    test('null', () {
      var attributes = {'bold': null};
      var base = {'bold': true};
      var expected = {'bold': true};
      expect(Delta.invertAttributes(attributes, base), expected);
    });

    test('replace', () {
      var attributes = {'color': 'red'};
      var base = {'color': 'blue'};
      var expected = base;
      expect(Delta.invertAttributes(attributes, base), expected);
    });

    test('noop', () {
      var attributes = {'color': 'red'};
      var base = {'color': 'red'};
      var expected = {};
      expect(Delta.invertAttributes(attributes, base), expected);
    });

    test('combined', () {
      var attributes = {
        'bold': true,
        'italic': null,
        'color': 'red',
        'size': '12px'
      };
      var base = {
        'font': 'serif',
        'italic': true,
        'color': 'blue',
        'size': '12px'
      };
      var expected = {'bold': null, 'italic': true, 'color': 'blue'};
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
      final op = Operation.insert('a', const {'b': true});
      expect(op.isInsert, isTrue);
      expect(op.length, 1);
      expect(op.attributes, const {'b': true});
    });

    test('insert (object) factory', () {
      final op = Operation.insert({}, const {'b': true});
      expect(op.isInsert, isTrue);
      expect(op.length, 1);
      expect(op.attributes, const {'b': true});
    });

    test('delete factory', () {
      final op = Operation.delete(5);
      expect(op.isDelete, isTrue);
      expect(op.length, 5);
      expect(op.attributes, isNull);
    });

    test('retain factory', () {
      final op = Operation.retain(5, const {'b': true});
      expect(op.isRetain, isTrue);
      expect(op.length, 5);
      expect(op.attributes, const {'b': true});
    });

    test('isPlain', () {
      final op1 = Operation.retain(1);
      final op2 = Operation.retain(1, {});
      final op3 = Operation.retain(1, {'b': true});
      expect(op1.isPlain, isTrue);
      expect(op2.isPlain, isTrue);
      expect(op3.isPlain, isFalse);
      expect(op1.isNotPlain, isFalse);
      expect(op2.isNotPlain, isFalse);
      expect(op3.isNotPlain, isTrue);
    });

    test('isEmpty', () {
      final op1 = Operation.retain(0);
      final op2 = Operation.retain(0, {});
      final op3 = Operation.retain(1);
      expect(op1.isEmpty, isTrue);
      expect(op2.isEmpty, isTrue);
      expect(op3.isEmpty, isFalse);
      expect(op1.isNotEmpty, isFalse);
      expect(op2.isNotEmpty, isFalse);
      expect(op3.isNotEmpty, isTrue);
    });

    test('equality', () {
      final op1 = Operation.insert('a');
      final op2 = Operation.insert('b', const {'h': '1', 'b': true});
      final op3 = Operation.insert('b', const {'h': true, 'b': '1'});
      final op4 = Operation.insert('a');
      expect(op1, isNot(op2));
      expect(op2, isNot(op3));
      expect(op1, op4);
    });

    test('hashCode', () {
      final op1 = Operation.insert('b', const {'h': '1', 'b': true});
      final op2 = Operation.insert('b', const {'h': '1', 'b': true});
      final op3 = Operation.insert('b', const {'h': true, 'b': '1'});
      expect(op2.hashCode, isNot(op3.hashCode));
      expect(op2.hashCode, op1.hashCode);
    });

    test('toString', () {
      var op1 = Operation.insert(
          'Hello world!\nAnd fancy line-breaks.\n', {'b': true});
      var op2 = Operation.retain(3, {'b': '1'});
      var op3 = Operation.delete(3);
      var op4 = Operation.insert({'a': 1}, {'b': true});
      expect(
          '$op1', 'insert⟨ Hello world!⏎And fancy line-breaks.⏎ ⟩ + {b: true}');
      expect('$op2', 'retain⟨ 3 ⟩ + {b: 1}');
      expect('$op3', 'delete⟨ 3 ⟩');
      expect('$op4', 'insert⟨ {a: 1} ⟩ + {b: true}');
    });

    test('attributes immutable', () {
      var op = Operation.insert('\n', {'b': true});
      var attrs = op.attributes;
      attrs['b'] = null;
      expect(op.attributes, {'b': true});
    });

    test('attributes operator== simple', () {
      var op1 = Operation.insert('\n', {'b': true});
      var op2 = Operation.insert('\n', {'b': true});
      expect(op1 == op2, isTrue);
    });

    test('attributes operator== complex', () {
      var op1 = Operation.insert('\n', {
        'b': {'c': 'd'}
      });
      var op2 = Operation.insert('\n', {
        'b': {'c': 'd'}
      });
      expect(op1 == op2, isTrue);
    });
  });

  group('Delta', () {
    test('isEmpty', () {
      final delta = Delta();
      expect(delta, isEmpty);
    });

    test('json', () {
      final delta = Delta()
        ..insert('abc', {'b': true})
        ..insert('def')
        ..insert({'a': 1});
      final result = json.encode(delta);
      expect(result,
          '[{"insert":"abc","attributes":{"b":true}},{"insert":"def"},{"insert":{"a":1}}]');
      final decoded = Delta.fromJson(json.decode(result));
      expect(decoded, delta);
    });

    test('toString', () {
      final delta = Delta()
        ..insert('Hello world!', {'b': true})
        ..retain(5);
      expect('$delta', 'insert⟨ Hello world! ⟩ + {b: true}\nretain⟨ 5 ⟩');
    });

    group('invert', () {
      test('insert', () {
        final delta = Delta()
          ..retain(2)
          ..insert('A');
        final base = Delta()..insert('123456');
        final expected = Delta()
          ..retain(2)
          ..delete(1);
        final inverted = delta.invert(base);
        expect(expected, inverted);
        expect(base.compose(delta).compose(inverted), base);
      });

      test('delete', () {
        final delta = Delta()
          ..retain(2)
          ..delete(3);
        final base = Delta()..insert('123456');
        final expected = Delta()
          ..retain(2)
          ..insert('345');
        final inverted = delta.invert(base);
        expect(expected, inverted);
        expect(base.compose(delta).compose(inverted), base);
      });

      test('retain', () {
        final delta = Delta()..retain(2)..retain(3, {'b': true});
        final base = Delta()..insert('123456');
        final expected = Delta()..retain(2)..retain(3, {'b': null});
        final inverted = delta.invert(base);
        expect(expected, inverted);
        expect(base.compose(delta).compose(inverted), base);
      });

      test('retain on a delta with different attributes', () {
        final base = Delta()..insert('123')..insert('4', {'b': true});
        final delta = Delta()..retain(4, {'i': true});
        final expected = Delta()..retain(4, {'i': null});
        final inverted = delta.invert(base);
        expect(expected, inverted);
        expect(base.compose(delta).compose(inverted), base);
      });

      test('combined', () {
        var delta = Delta()
          ..retain(2)
          ..delete(2)
          ..insert('AB', {'italic': true})
          ..retain(2, {'italic': null, 'bold': true})
          ..retain(2, {'color': 'red'})
          ..delete(1);
        var base = Delta()
          ..insert('123', {'bold': true})
          ..insert('456', {'italic': true})
          ..insert('789', {'color': 'red', 'bold': true});
        var expected = Delta()
          ..retain(2)
          ..insert('3', {'bold': true})
          ..insert('4', {'italic': true})
          ..delete(2)
          ..retain(2, {'italic': true, 'bold': null})
          ..retain(2)
          ..insert('9', {'color': 'red', 'bold': true});

        var inverted = delta.invert(base);
        expect(inverted, expected);
        expect(base.compose(delta).compose(inverted), base);
      });
    });

    group('push', () {
      // ==== insert combinations ====

      test('insert + insert', () {
        final delta = Delta()..insert('abc')..insert('123');
        expect(delta.first, Operation.insert('abc123'));
      });

      test('insert + insert (object)', () {
        const data = {};
        final delta = Delta()..insert('abc')..insert(data);
        expect(delta[0], Operation.insert('abc'));
        expect(delta[1], Operation.insert(data));
      });

      test('insert (object) + insert', () {
        const data = {};
        final delta = Delta()..insert(data)..insert('abc');
        expect(delta[0], Operation.insert(data));
        expect(delta[1], Operation.insert('abc'));
      });

      test('insert + delete', () {
        final delta = Delta()
          ..insert('abc')
          ..delete(3);
        expect(delta[0], Operation.insert('abc'));
        expect(delta[1], Operation.delete(3));
      });

      test('insert (object) + delete', () {
        final delta = Delta()
          ..insert(const {})
          ..delete(3);
        expect(delta[0], Operation.insert(const {}));
        expect(delta[1], Operation.delete(3));
      });

      test('insert + retain', () {
        final delta = Delta()
          ..insert('abc')
          ..retain(3);
        expect(delta[0], Operation.insert('abc'));
        expect(delta[1], Operation.retain(3));
      });

      test('insert (object) + retain', () {
        final delta = Delta()
          ..insert(const {})
          ..retain(3);
        expect(delta[0], Operation.insert(const {}));
        expect(delta[1], Operation.retain(3));
      });

      // ==== delete combinations ====

      test('delete + insert', () {
        final delta = Delta()
          ..delete(2)
          ..insert('abc');
        expect(delta[0], Operation.insert('abc'));
        expect(delta[1], Operation.delete(2));
      });

      test('delete + insert (object)', () {
        final delta = Delta()
          ..delete(2)
          ..insert(const {});
        expect(delta[0], Operation.insert(const {}));
        expect(delta[1], Operation.delete(2));
      });

      test('delete + delete', () {
        final delta = Delta()..delete(2)..delete(3);
        expect(delta.first, Operation.delete(5));
      });

      test('delete + retain', () {
        final delta = Delta()
          ..delete(2)
          ..retain(3);
        expect(delta[0], Operation.delete(2));
        expect(delta[1], Operation.retain(3));
      });

      // ==== retain combinations ====

      test('retain + insert', () {
        final delta = Delta()
          ..retain(2)
          ..insert('abc');
        expect(delta[0], Operation.retain(2));
        expect(delta[1], Operation.insert('abc'));
      });

      test('retain + insert (object)', () {
        final delta = Delta()
          ..retain(2)
          ..insert(const {});
        expect(delta[0], Operation.retain(2));
        expect(delta[1], Operation.insert(const {}));
      });

      test('retain + delete', () {
        final delta = Delta()
          ..retain(2)
          ..delete(3);
        expect(delta[0], Operation.retain(2));
        expect(delta[1], Operation.delete(3));
      });

      test('retain + retain', () {
        final delta = Delta()..retain(2)..retain(3);
        expect(delta.first, Operation.retain(5));
      });

      // ==== edge scenarios ====

      test('consequent inserts with different attributes do not merge', () {
        final delta = Delta()..insert('abc', const {'b': true})..insert('123');
        expect(delta.toList(), [
          Operation.insert('abc', const {'b': true}),
          Operation.insert('123'),
        ]);
      });

      test('consequent inserts (object) do not merge', () {
        final delta = Delta()..insert(const {})..insert(const {});
        expect(delta.toList(), [
          Operation.insert(const {}),
          Operation.insert(const {}),
        ]);
      });

      test('consequent inserts (object) with different attributes do not merge',
          () {
        final delta = Delta()
          ..insert(const {}, const {'b': true})
          ..insert(const {});
        expect(delta.toList(), [
          Operation.insert(const {}, const {'b': true}),
          Operation.insert(const {}),
        ]);
      });

      test('consequent inserts (object) with same attributes do not merge', () {
        final delta = Delta()
          ..insert(const {}, const {'b': true})
          ..insert(const {}, const {'b': true});
        expect(delta.toList(), [
          Operation.insert(const {}, const {'b': true}),
          Operation.insert(const {}, const {'b': true}),
        ]);
      });

      test('consequent retain with different attributes do not merge', () {
        final delta = Delta()..retain(5, const {'b': true})..retain(3);
        expect(delta.toList(), [
          Operation.retain(5, const {'b': true}),
          Operation.retain(3),
        ]);
      });

      test('consequent inserts with same attributes merge', () {
        final ul = {'block': 'ul'};
        final doc = Delta()
          ..insert('DartConf')
          ..insert('\n', ul)
          ..insert('Los Angeles')
          ..insert('\n', ul);
        final change = Delta()
          ..retain(8)
          ..insert('\n', ul);
        final result = doc.compose(change);
        final expected = Delta()
          ..insert('DartConf')
          ..insert('\n\n', ul)
          ..insert('Los Angeles')
          ..insert('\n', ul);
        expect(result, expected);
      });

      test('consequent deletes and inserts', () {
        final doc = Delta()..insert('YOLOYOLO');
        final change = Delta()
          ..insert('YATA')
          ..delete(4)
          ..insert('YATA');
        final result = doc.compose(change);
        final expected = Delta()..insert('YATAYATAYOLO');
        expect(result, expected);
      });

      test('consequent deletes and inserts (object)', () {
        final doc = Delta()
          ..insert(const {})
          ..insert(const {})
          ..insert(const {});
        final change = Delta()
          ..insert('YATA')
          ..delete(2)
          ..insert('YATA');
        final result = doc.compose(change);
        final expected = Delta()..insert('YATAYATA')..insert(const {});
        expect(result, expected);
      });
    });
    group('compose', () {
      // ==== insert combinations ====

      test('insert + insert', () {
        final a = Delta()..insert('A');
        final b = Delta()..insert('B');
        final expected = Delta()..insert('BA');
        expect(a.compose(b), expected);
      });

      test('insert + insert (object)', () {
        final a = Delta()..insert('A');
        final b = Delta()..insert(const {});
        final expected = Delta()..insert(const {})..insert('A');
        expect(a.compose(b), expected);
      });

      test('insert (object) + insert', () {
        final a = Delta()..insert(const {});
        final b = Delta()..insert('B');
        final expected = Delta()..insert('B')..insert(const {});
        expect(a.compose(b), expected);
      });

      test('insert + delete', () {
        final a = Delta()..insert('A');
        final b = Delta()..delete(1);
        expect(a.compose(b), isEmpty);
      });

      test('insert (object) + delete', () {
        final a = Delta()..insert(const {});
        final b = Delta()..delete(1);
        expect(a.compose(b), isEmpty);
      });

      test('insert + retain', () {
        final a = Delta()..insert('A');
        final b = Delta()..retain(1, const {'b': true});
        expect(a.compose(b).toList(), [
          Operation.insert('A', const {'b': true})
        ]);
      });

      test('insert (object) + retain', () {
        final a = Delta()..insert(const {});
        final b = Delta()..retain(1, const {'b': true});
        expect(a.compose(b).toList(), [
          Operation.insert(const {}, const {'b': true})
        ]);
      });

      // ==== delete combinations ====

      test('delete + insert', () {
        final a = Delta()..delete(1);
        final b = Delta()..insert('B');
        final expected = Delta()
          ..insert('B')
          ..delete(1);
        expect(a.compose(b), expected);
      });

      test('delete + insert (object)', () {
        final a = Delta()..delete(1);
        final b = Delta()..insert(const {});
        final expected = Delta()
          ..insert(const {})
          ..delete(1);
        expect(a.compose(b), expected);
      });

      test('delete + delete', () {
        final a = Delta()..delete(1);
        final b = Delta()..delete(1);
        final expected = Delta()..delete(2);
        expect(a.compose(b), expected);
      });

      test('delete + retain', () {
        final a = Delta()..delete(1);
        final b = Delta()..retain(1, const {'b': true});
        final expected = Delta()
          ..delete(1)
          ..retain(1, const {'b': true});
        expect(a.compose(b), expected);
      });

      // ==== retain combinations ====

      test('retain + insert', () {
        final a = Delta()..retain(1, const {'b': true});
        final b = Delta()..insert('B');
        final expected = Delta()
          ..insert('B')
          ..retain(1, const {'b': true});
        expect(a.compose(b), expected);
      });

      test('retain + insert (object)', () {
        final a = Delta()..retain(1, const {'b': true});
        final b = Delta()..insert(const {});
        final expected = Delta()
          ..insert(const {})
          ..retain(1, const {'b': true});
        expect(a.compose(b), expected);
      });

      test('retain + delete', () {
        final a = Delta()..retain(1, const {'b': true});
        final b = Delta()..delete(1);
        final expected = Delta()..delete(1);
        expect(a.compose(b), expected);
      });

      test('retain + retain', () {
        final a = Delta()..retain(1, const {'color': 'blue'});
        final b = Delta()..retain(1, const {'color': 'red', 'b': true});
        final expected = Delta()..retain(1, const {'color': 'red', 'b': true});
        expect(a.compose(b), expected);
      });

      // ===== other scenarios =====

      test('insert in middle of text', () {
        final a = Delta()..insert('Hello');
        final b = Delta()
          ..retain(3)
          ..insert('X');
        final expected = Delta()..insert('HelXlo');
        expect(a.compose(b), expected);
      });

      test('insert (object) in middle of text', () {
        final a = Delta()..insert('Hello');
        final b = Delta()
          ..retain(3)
          ..insert(const {});
        final expected = Delta()..insert('Hel')..insert(const {})..insert('lo');
        expect(a.compose(b), expected);
      });

      test('insert and delete ordering', () {
        final a = Delta()..insert('Hello');
        final b = Delta()..insert('Hello');
        final insertFirst = Delta()
          ..retain(3)
          ..insert('X')
          ..delete(1);
        final deleteFirst = Delta()
          ..retain(3)
          ..delete(1)
          ..insert('X');
        final expected = Delta()..insert('HelXo');
        expect(a.compose(insertFirst), expected);
        expect(b.compose(deleteFirst), expected);
      });

      test('insert (object) and delete ordering', () {
        final a = Delta()
          ..insert(const [1])
          ..insert(const [2])
          ..insert(const [3]);
        final b = Delta()
          ..insert(const [1])
          ..insert(const [2])
          ..insert(const [3]);
        final insertFirst = Delta()
          ..retain(2)
          ..insert('X')
          ..delete(1);
        final deleteFirst = Delta()
          ..retain(2)
          ..delete(1)
          ..insert('X');
        final expected = Delta()
          ..insert(const [1])
          ..insert(const [2])
          ..insert('X');
        expect(a.compose(insertFirst), expected);
        expect(b.compose(deleteFirst), expected);
      });

      test('delete entire text', () {
        final a = Delta()
          ..retain(4)
          ..insert('Hello');
        final b = Delta()..delete(9);
        final expected = Delta()..delete(4);
        expect(a.compose(b), expected);
      });

      test('delete object', () {
        final a = Delta()
          ..retain(4)
          ..insert(const {});
        final b = Delta()..delete(5);
        final expected = Delta()..delete(4);
        expect(a.compose(b), expected);
      });

      test('retain more than length of text', () {
        final a = Delta()..insert('Hello');
        final b = Delta()..retain(10);
        final expected = Delta()..insert('Hello');
        expect(a.compose(b), expected);
      });

      test('retain more than length of op with object', () {
        final a = Delta()..insert(const {});
        final b = Delta()..retain(10);
        final expected = Delta()..insert(const {});
        expect(a.compose(b), expected);
      });

      test('remove all attributes', () {
        final a = Delta()..insert('A', const {'b': true});
        final b = Delta()..retain(1, const {'b': null});
        final expected = Delta()..insert('A');
        expect(a.compose(b), expected);
      });

      test('remove all attributes in object', () {
        final a = Delta()..insert(const {}, const {'b': true});
        final b = Delta()..retain(1, const {'b': null});
        final expected = Delta()..insert(const {});
        expect(a.compose(b), expected);
      });
    });

    group('transform', () {
      test('insert + insert', () {
        var a1 = Delta()..insert('A');
        var b1 = Delta()..insert('B');
        var a2 = Delta.from(a1);
        var b2 = Delta.from(b1);
        var expected1 = Delta()
          ..retain(1)
          ..insert('B');
        var expected2 = Delta()..insert('B');
        expect(a1.transform(b1, true), expected1);
        expect(a2.transform(b2, false), expected2);
      });

      test('insert + insert (object)', () {
        var a1 = Delta()..insert('A');
        var b1 = Delta()..insert(const {});
        var a2 = Delta.from(a1);
        var b2 = Delta.from(b1);
        var expected1 = Delta()
          ..retain(1)
          ..insert(const {});
        var expected2 = Delta()..insert(const {});
        expect(a1.transform(b1, true), expected1);
        expect(a2.transform(b2, false), expected2);
      });

      test('insert + retain', () {
        var a = Delta()..insert('A');
        var b = Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var expected = Delta()
          ..retain(1)
          ..retain(1, const {'bold': true, 'color': 'red'});
        expect(a.transform(b, true), expected);
      });

      test('insert (object) + retain', () {
        var a = Delta()..insert(const {});
        var b = Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var expected = Delta()
          ..retain(1)
          ..retain(1, const {'bold': true, 'color': 'red'});
        expect(a.transform(b, true), expected);
      });

      test('insert + delete', () {
        var a = Delta()..insert('A');
        var b = Delta()..delete(1);
        var expected = Delta()
          ..retain(1)
          ..delete(1);
        expect(a.transform(b, true), expected);
      });

      test('insert (object) + delete', () {
        var a = Delta()..insert(const {});
        var b = Delta()..delete(1);
        var expected = Delta()
          ..retain(1)
          ..delete(1);
        expect(a.transform(b, true), expected);
      });

      test('delete + insert', () {
        var a = Delta()..delete(1);
        var b = Delta()..insert('B');
        var expected = Delta()..insert('B');
        expect(a.transform(b, true), expected);
      });

      test('delete + insert (object)', () {
        var a = Delta()..delete(1);
        var b = Delta()..insert(const {});
        var expected = Delta()..insert(const {});
        expect(a.transform(b, true), expected);
      });

      test('delete + retain', () {
        var a = Delta()..delete(1);
        var b = Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var expected = Delta();
        expect(a.transform(b, true), expected);
      });

      test('delete + delete', () {
        var a = Delta()..delete(1);
        var b = Delta()..delete(1);
        var expected = Delta();
        expect(a.transform(b, true), expected);
      });

      test('retain + insert', () {
        var a = Delta()..retain(1, const {'color': 'blue'});
        var b = Delta()..insert('B');
        var expected = Delta()..insert('B');
        expect(a.transform(b, true), expected);
      });

      test('retain + insert (object)', () {
        var a = Delta()..retain(1, const {'color': 'blue'});
        var b = Delta()..insert(const {});
        var expected = Delta()..insert(const {});
        expect(a.transform(b, true), expected);
      });

      test('retain + retain', () {
        var a1 = Delta()..retain(1, const {'color': 'blue'});
        var b1 = Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var a2 = Delta()..retain(1, const {'color': 'blue'});
        var b2 = Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var expected1 = Delta()..retain(1, const {'bold': true});
        var expected2 = Delta();
        expect(a1.transform(b1, true), expected1);
        expect(b2.transform(a2, true), expected2);
      });

      test('retain + retain without priority', () {
        var a1 = Delta()..retain(1, const {'color': 'blue'});
        var b1 = Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var a2 = Delta()..retain(1, const {'color': 'blue'});
        var b2 = Delta()..retain(1, const {'bold': true, 'color': 'red'});
        var expected1 = Delta()
          ..retain(1, const {'bold': true, 'color': 'red'});
        var expected2 = Delta()..retain(1, const {'color': 'blue'});
        expect(a1.transform(b1, false), expected1);
        expect(b2.transform(a2, false), expected2);
      });

      test('retain + delete', () {
        var a = Delta()..retain(1, const {'color': 'blue'});
        var b = Delta()..delete(1);
        var expected = Delta()..delete(1);
        expect(a.transform(b, true), expected);
      });

      test('alternating edits', () {
        var a1 = Delta()
          ..retain(2)
          ..insert('si')
          ..delete(5);
        var b1 = Delta()
          ..retain(1)
          ..insert('e')
          ..delete(5)
          ..retain(1)
          ..insert('ow');
        var a2 = Delta.from(a1);
        var b2 = Delta.from(b1);
        var expected1 = Delta()
          ..retain(1)
          ..insert('e')
          ..delete(1)
          ..retain(2)
          ..insert('ow');
        var expected2 = Delta()
          ..retain(2)
          ..insert('si')
          ..delete(1);
        expect(a1.transform(b1, false), expected1);
        expect(b2.transform(a2, false), expected2);
      });

      test('conflicting appends', () {
        var a1 = Delta()
          ..retain(3)
          ..insert('aa');
        var b1 = Delta()
          ..retain(3)
          ..insert('bb');
        var a2 = Delta.from(a1);
        var b2 = Delta.from(b1);
        var expected1 = Delta()
          ..retain(5)
          ..insert('bb');
        var expected2 = Delta()
          ..retain(3)
          ..insert('aa');
        expect(a1.transform(b1, true), expected1);
        expect(b2.transform(a2, false), expected2);
      });

      test('prepend + append', () {
        var a1 = Delta()..insert('aa');
        var b1 = Delta()
          ..retain(3)
          ..insert('bb');
        var expected1 = Delta()
          ..retain(5)
          ..insert('bb');
        var a2 = Delta.from(a1);
        var b2 = Delta.from(b1);
        var expected2 = Delta()..insert('aa');
        expect(a1.transform(b1, false), expected1);
        expect(b2.transform(a2, false), expected2);
      });

      test('trailing deletes with differing lengths', () {
        var a1 = Delta()
          ..retain(2)
          ..delete(1);
        var b1 = Delta()..delete(3);
        var expected1 = Delta()..delete(2);
        var a2 = Delta.from(a1);
        var b2 = Delta.from(b1);
        var expected2 = Delta();
        expect(a1.transform(b1, false), expected1);
        expect(b2.transform(a2, false), expected2);
      });
    });

    group('transformPosition', () {
      test('insert before position', () {
        var delta = Delta()..insert('A');
        expect(delta.transformPosition(2), 3);
      });

      test('insert (object) before position', () {
        var delta = Delta()..insert(const {});
        expect(delta.transformPosition(2), 3);
      });

      test('insert after position', () {
        var delta = Delta()
          ..retain(2)
          ..insert('A');
        expect(delta.transformPosition(1), 1);
      });

      test('insert (object) after position', () {
        var delta = Delta()
          ..retain(2)
          ..insert(const {});
        expect(delta.transformPosition(1), 1);
      });

      test('insert at position', () {
        var delta = Delta()
          ..retain(2)
          ..insert('A');
        expect(delta.transformPosition(2, force: false), 2);
        expect(delta.transformPosition(2, force: true), 3);
      });

      test('insert (object) at position', () {
        var delta = Delta()
          ..retain(2)
          ..insert(const {});
        expect(delta.transformPosition(2, force: false), 2);
        expect(delta.transformPosition(2, force: true), 3);
      });

      test('delete before position', () {
        var delta = Delta()..delete(2);
        expect(delta.transformPosition(4), 2);
      });

      test('delete after position', () {
        var delta = Delta()
          ..retain(4)
          ..delete(2);
        expect(delta.transformPosition(2), 2);
      });

      test('delete across position', () {
        var delta = Delta()
          ..retain(1)
          ..delete(4);
        expect(delta.transformPosition(2), 1);
      });

      test('insert and delete before position', () {
        var delta = Delta()
          ..retain(2)
          ..insert('A')
          ..delete(2);
        expect(delta.transformPosition(4), 3);
      });

      test('insert before and delete across position', () {
        var delta = Delta()
          ..retain(2)
          ..insert('A')
          ..delete(4);
        expect(delta.transformPosition(4), 3);
      });

      test('delete before and delete across position', () {
        var delta = Delta()
          ..delete(1)
          ..retain(1)
          ..delete(4);
        expect(delta.transformPosition(4), 1);
      });
    });

    group('slice', () {
      test('start', () {
        var slice = (Delta()
              ..retain(2)
              ..insert('A'))
            .slice(2);
        var expected = Delta()..insert('A');
        expect(slice, expected);
      });

      test('start and end chop', () {
        var slice = (Delta()..insert('0123456789')).slice(2, 7);
        var expected = Delta()..insert('23456');
        expect(slice, expected);
      });

      test('start and end multiple chop', () {
        var slice = (Delta()..insert('0123', {'bold': true})..insert('4567'))
            .slice(3, 5);
        var expected = Delta()..insert('3', {'bold': true})..insert('4');
        expect(slice, expected);
      });

      test('start and end', () {
        var slice = (Delta()
              ..retain(2)
              ..insert('A', {'bold': true})
              ..insert('B'))
            .slice(2, 3);
        var expected = Delta()..insert('A', {'bold': true});
        expect(slice, expected);
      });

      test('start and end objects', () {
        var slice = (Delta()
              ..insert(const [1])
              ..insert(const [2])
              ..insert(const [3])
              ..insert(const [4])
              ..insert(const [5]))
            .slice(2, 3);
        var expected = Delta()..insert(const [3]);
        expect(slice, expected);
      });

      test('from beginning', () {
        var delta = Delta()
          ..retain(2)
          ..insert('A', {'bold': true})
          ..insert('B');
        var slice = delta.slice(0);
        expect(slice, delta);
      });

      test('split ops', () {
        var slice =
            (Delta()..insert('AB', {'bold': true})..insert('C')).slice(1, 2);
        var expected = Delta()..insert('B', {'bold': true});
        expect(slice, expected);
      });

      test('split ops multiple times', () {
        var slice =
            (Delta()..insert('ABC', {'bold': true})..insert('D')).slice(1, 2);
        var expected = Delta()..insert('B', {'bold': true});
        expect(slice, expected);
      });
    });
  });

  group('DeltaIterator', () {
    var delta = Delta()
      ..insert('Hello', {'b': true})
      ..retain(3)
      ..insert(' world', {'i': true})
      ..insert(Embed('hr'))
      ..delete(4);
    DeltaIterator iterator;

    setUp(() {
      iterator = DeltaIterator(delta);
    });

    test('hasNext', () {
      expect(iterator.hasNext, isTrue);
      iterator..next()..next()..next()..next()..next();
      expect(iterator.hasNext, isFalse);
    });

    test('peekLength', () {
      expect(iterator.peekLength(), 5);
      iterator.next();
      expect(iterator.peekLength(), 3);
      iterator.next();
      expect(iterator.peekLength(), 6);
      iterator.next();
      expect(iterator.peekLength(), 1);
      iterator.next();
      expect(iterator.peekLength(), 4);
      iterator.next();
    });

    test('peekLength with operation split', () {
      iterator.next(2);
      expect(iterator.peekLength(), 5 - 2);
    });

    test('peekLength after EOF', () {
      iterator.skip(19);
      expect(iterator.peekLength(), double.infinity);
    });

    test('peek operation type', () {
      expect(iterator.isNextInsert, isTrue);
      iterator.next();
      expect(iterator.isNextRetain, isTrue);
      iterator.next();
      expect(iterator.isNextInsert, isTrue);
      iterator.next();
      expect(iterator.isNextInsert, isTrue);
      iterator.next();
      expect(iterator.isNextDelete, isTrue);
      iterator.next();
    });

    test('next', () {
      expect(iterator.next(), Operation.insert('Hello', {'b': true}));
      expect(iterator.next(), Operation.retain(3));
      expect(iterator.next(), Operation.insert(' world', {'i': true}));
      expect(iterator.next(), Operation.insert(Embed('hr')));
      expect(iterator.next(), Operation.delete(4));
    });

    test('next with operation split', () {
      expect(iterator.next(2), Operation.insert('He', {'b': true}));
      expect(iterator.next(10), Operation.insert('llo', {'b': true}));
      expect(iterator.next(1), Operation.retain(1));
      expect(iterator.next(2), Operation.retain(2));
    });
  });
}

class Embed {
  final String data;

  Embed(this.data);

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! Embed) return false;
    final typedOther = other as Embed;
    return typedOther.data == data;
  }

  @override
  int get hashCode => data.hashCode;

  Map<String, dynamic> toJson() => {'data': data};
}
