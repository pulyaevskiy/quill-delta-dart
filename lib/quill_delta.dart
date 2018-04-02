// Copyright (c) 2018, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Implementation of Quill Delta format in Dart.
library delta;

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:quiver_hashcode/hashcode.dart';

/// An operation performed on a rich-text document.
class Operation {
  /// Key of this operation, can be "insert", "delete" or "retain".
  final String key;

  /// Length of this operation.
  final int length;

  /// Payload of "insert" operation, for other types is set to `null`.
  final String data;

  /// Rich-text attributes set by this operation.
  final Map<String, dynamic> attributes;

  Operation._(this.key, this.length, this.data, this.attributes)
      : assert(key != null && length != null && data != null);

  static Operation fromJson(values) {
    final map = new Map<String, dynamic>.from(values);
    if (map.containsKey('insert')) {
      final String text = map['insert'];
      return new Operation._('insert', text.length, text, map['attributes']);
    } else if (map.containsKey('delete')) {
      final int length = map['delete'];
      return new Operation._('delete', length, '', null);
    } else if (map.containsKey('retain')) {
      final int length = map['retain'];
      return new Operation._('retain', length, '', map['attributes']);
    }
    throw new ArgumentError.value(
        values, 'Invalid values for Delta operation.');
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {key: value};
    if (attributes != null) json['attributes'] = attributes;
    return json;
  }

  factory Operation.delete(int length) =>
      new Operation._('delete', length, '', null);

  factory Operation.insert(String text, [Map<String, dynamic> attributes]) =>
      new Operation._('insert', text.length, text, attributes);

  factory Operation.retain(int length, [Map<String, dynamic> attributes]) =>
      new Operation._('retain', length, '', attributes);

  /// Value of this operation. For insert operations this returns text,
  /// for delete and retain - length.
  dynamic get value => (key == 'insert') ? data : length;

  /// Returns `true` if this operation is a delete operation.
  bool get isDelete => key == 'delete';

  /// Returns `true` if this operation is an insert operation.
  bool get isInsert => key == 'insert';

  /// Returns `true` if this operation is a retcol operation.
  bool get isRetain => key == 'retain';

  /// Returns `true` if this operation does not actually mutate a document.
  bool get isNoOp {
    return (isRetain) && (attributes == null || attributes.isEmpty);
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other is! Operation) return false;
    Operation typedOther = other;
    return key == typedOther.key &&
        length == typedOther.length &&
        data == typedOther.data &&
        _compareAttributes(typedOther.attributes);
  }

  bool _compareAttributes(Map<String, dynamic> otherAttributes) {
    final comparator = new MapEquality<String, dynamic>(
      keys: const DefaultEquality<String>(),
      values: const DefaultEquality<dynamic>(),
    );
    return comparator.equals(attributes, otherAttributes);
  }

  @override
  int get hashCode {
    if (attributes != null && attributes.isNotEmpty) {
      int keysHash = hashObjects(attributes.keys);
      int valuesHash = hashObjects(attributes.values);
      return hash4(key, value, keysHash, valuesHash);
    }
    return hash2(key, value);
  }

  @override
  String toString() {
    String attr = attributes == null ? '' : ', $attributes';
    return isInsert ? '$key("$value"$attr)' : '$key($value$attr)';
  }
}

/// Transform two attribute sets.
Map<String, dynamic> transformAttributes(
    Map<String, dynamic> a, Map<String, dynamic> b, bool priority) {
  if (a == null) return b;
  if (b == null) return null;

  if (!priority) return b;

  final Map<String, dynamic> result =
      b.keys.fold<Map<String, dynamic>>({}, (attributes, key) {
    if (!a.containsKey(key)) attributes[key] = b[key];
    return attributes;
  });

  return result.isEmpty ? null : result;
}

/// Composes two attribute sets.
Map<String, dynamic> composeAttributes(
    Map<String, dynamic> a, Map<String, dynamic> b,
    {bool keepNull: false}) {
  a ??= const {};
  b ??= const {};

  final Map<String, dynamic> result = new Map.from(a)..addAll(b);
  List<String> keys = result.keys.toList(growable: false);

  if (!keepNull) {
    for (final String key in keys) {
      if (result[key] == null) result.remove(key);
    }
  }

  return result.isEmpty ? null : result;
}

/// Delta represents a rich-text document or a change to one as a sequence of
/// insert, delete and retain operations.
///
/// Delta containing only "insert" operations is usually referred to as
/// "document delta".
class Delta {
  final List<Operation> _operations;

  List<Operation> get operations => _operations;

  int _modificationCount = 0;

  Delta._(List<Operation> operations)
      : assert(operations != null),
        _operations = operations;

  /// Creates new empty delta.
  factory Delta() => new Delta._(new List<Operation>());

  /// Creates new delta from [operations].
  factory Delta.fromOperations(List<Operation> operations) =>
      new Delta._(operations);

  static Delta fromJson(List data) {
    return new Delta._(data.map(Operation.fromJson).toList());
  }

  List toJson() => operations;

  /// Returns `true` if this delta does not contain mutating operations.
  bool get isNoOp =>
      _operations.isEmpty || _operations.every((op) => op.isNoOp);

  @override
  operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! Delta) return false;
    Delta typedOther = other;
    final comparator =
        new ListEquality<Operation>(const DefaultEquality<Operation>());
    return comparator.equals(operations, typedOther.operations);
  }

  @override
  int get hashCode => hashObjects(operations);

  /// Retain [count] of characters.
  void retain(int count, [Map<String, dynamic> attributes]) {
    assert(count >= 0);
    if (count == 0) return; // no-op
    push(new Operation.retain(count, attributes));
  }

  /// Insert [text] at current position.
  void insert(String text, [Map<String, dynamic> attributes]) {
    assert(text != null);
    if (text.isEmpty) return; // no-op
    push(new Operation.insert(text, attributes));
  }

  /// Delete [length] columns after current position.
  void delete(int length) {
    assert(length >= 0);
    if (length == 0) return;
    push(new Operation.delete(length));
  }

  void _mergeWithTail(Operation operation) {
    assert(_operations.isNotEmpty);
    assert(operation != null && _operations.last.key == operation.key);
    final Operation last = _operations.last;

    final int length = operation.length + last.length;
    final String data = last.data + operation.data;
    final int index = _operations.length;
    _operations.replaceRange(index - 1, index, [
      new Operation._(operation.key, length, data, operation.attributes),
    ]);
  }

  /// Pushes new operation into this delta.
  ///
  /// Performs compaction by composing [newOp] with current tail operation
  /// of this delta, when possible. For instance,
  ///
  /// - if tail is `insert('abc')` and newOp is `insert('123')` then tail is
  ///   replaced with `insert('abc123')` - a compound result of the two
  ///   operations
  void push(Operation newOp) {
    if (newOp.isRetain && newOp.length == 0 && newOp.isNoOp) return;

    int index = _operations.length;
    Operation lastOp = _operations.isNotEmpty ? _operations.last : null;
    if (lastOp != null) {
      if (lastOp.isDelete && newOp.isDelete) {
        _mergeWithTail(newOp);
        return;
      }

      if (lastOp.isDelete && newOp.isInsert) {
        index -= 1; // Always insert before deleting
        lastOp = (index > 0) ? _operations.elementAt(index - 1) : null;
        if (lastOp == null) {
          _operations.insert(0, newOp);
          return;
        }
      }

      if (lastOp.isInsert && newOp.isInsert) {
        if (lastOp.attributes == newOp.attributes) {
          _mergeWithTail(newOp);
          return;
        }
      }

      if (lastOp.isRetain && newOp.isRetain) {
        if (lastOp.attributes == newOp.attributes) {
          _mergeWithTail(newOp);
          return;
        }
      }
    }
    if (index == _operations.length) {
      _operations.add(newOp);
    } else {
      final opAtIndex = _operations.elementAt(index);
      _operations.replaceRange(index, index + 1, [newOp, opAtIndex]);
    }
    _modificationCount++;
  }

  /// Composes next operation from [thisIter] and [otherIter].
  ///
  /// Returns new operation or `null` if operations from [thisIter] and
  /// [otherIter] nullify each other. For instance, for the pair `insert('abc')`
  /// and `delete(3)` composition result would be no-op.
  Operation _composeOperation(DeltaIterator thisIter, DeltaIterator otherIter) {
    if (otherIter.isNextInsert) return otherIter.next();
    if (thisIter.isNextDelete) return thisIter.next();

    num length = math.min(thisIter.peekLength(), otherIter.peekLength());
    Operation thisOp = thisIter.next(length);
    Operation otherOp = otherIter.next(length);
    assert(thisOp.length == otherOp.length);

    if (otherOp.isRetain) {
      final attributes = composeAttributes(
        thisOp.attributes,
        otherOp.attributes,
        keepNull: thisOp.isRetain,
      );
      if (thisOp.isRetain) {
        return new Operation.retain(thisOp.length, attributes);
      } else if (thisOp.isInsert) {
        return new Operation.insert(thisOp.data, attributes);
      } else {
        throw new StateError('Unreachable');
      }
    } else {
      // otherOp == delete && thisOp in [retcol, insert]
      assert(otherOp.isDelete);
      if (thisOp.isRetain) return otherOp;
      assert(thisOp.isInsert);
      // otherOp(delete) + thisOp(insert) => null
    }
    return null;
  }

  /// Composes this delta with [other] and returns new [Delta].
  ///
  /// It is not required for this and [other] delta to represent a document
  /// delta (consisting only of insert operations).
  Delta compose(Delta other) {
    final Delta result = new Delta();
    DeltaIterator thisIter = new DeltaIterator(this);
    DeltaIterator otherIter = new DeltaIterator(other);

    while (thisIter.hasNext || otherIter.hasNext) {
      final Operation newOp = _composeOperation(thisIter, otherIter);
      if (newOp != null) result.push(newOp);
    }
    return result..trim();
  }

  /// Transforms next operation from [otherIter] against next operation in
  /// [thisIter].
  ///
  /// Returns `null` if both operations nullify each other.
  Operation _transformOperation(
      DeltaIterator thisIter, DeltaIterator otherIter, bool priority) {
    if (thisIter.isNextInsert && (priority || !otherIter.isNextInsert)) {
      return new Operation.retain(thisIter.next().length);
    } else if (otherIter.isNextInsert) {
      return otherIter.next();
    }

    num length = math.min(thisIter.peekLength(), otherIter.peekLength());
    Operation thisOp = thisIter.next(length);
    Operation otherOp = otherIter.next(length);
    assert(thisOp.length == otherOp.length);

    // At this point only delete and retcol operations are possible.
    if (thisOp.isDelete) {
      // otherOp is either delete or retcol, so they nullify each other.
      return null;
    } else if (otherOp.isDelete) {
      return otherOp;
    } else {
      // Retain otherOp which is either retcol or insert.
      return new Operation.retain(
        length,
        transformAttributes(thisOp.attributes, otherOp.attributes, priority),
      );
    }
  }

  /// Transforms [other] delta against operations in this delta.
  Delta transform(Delta other, bool priority) {
    final Delta result = new Delta();
    DeltaIterator thisIter = new DeltaIterator(this);
    DeltaIterator otherIter = new DeltaIterator(other);

    while (thisIter.hasNext || otherIter.hasNext) {
      final Operation newOp =
          _transformOperation(thisIter, otherIter, priority);
      if (newOp != null) result.push(newOp);
    }
    return result..trim();
  }

  /// Removes trailing retain operation with empty attributes, if present.
  void trim() {
    if (_operations.isNotEmpty) {
      final Operation last = _operations.last;
      if (last.isNoOp) _operations.removeLast();
    }
  }

  Delta concat(Delta other) {
    final Delta delta = new Delta.fromOperations(operations);
    if (other.operations.isNotEmpty) {
      // In case first operation of other can be merged with last operation in
      // our list.
      delta.push(other.operations.first);
      delta.operations.addAll(other.operations.sublist(1));
    }
    return delta;
  }

  @override
  String toString() => '$Delta$operations';
}

class DeltaIterator {
  final Delta delta;
  int _index = 0;
  num _offset = 0;
  int _modificationCount;

  DeltaIterator(this.delta) : _modificationCount = delta._modificationCount;

  bool get isNextInsert => nextOpKey == 'insert';
  bool get isNextDelete => nextOpKey == 'delete';
  bool get isNextRetain => nextOpKey == 'retain';

  String get nextOpKey {
    if (_index < delta.operations.length) {
      return delta.operations.elementAt(_index).key;
    } else
      return null;
  }

  bool get hasNext => peekLength() < double.infinity;

  num peekLength() {
    if (_index < delta.operations.length) {
      final Operation operation = delta.operations[_index];
      return operation.length - _offset;
    }
    return double.infinity;
  }

  Operation next([num length = double.infinity]) {
    assert(length != null);

    if (_modificationCount != delta._modificationCount) {
      throw new ConcurrentModificationError(delta);
    }

    if (_index < delta.operations.length) {
      final Operation op = delta.operations.elementAt(_index);
      final String opKey = op.key;
      final Map<String, dynamic> opAttributes = op.attributes;
      final _currentOffset = _offset;
      num maxLength =
          length == double.infinity ? (op.length - _currentOffset) : length;
      if (maxLength == op.length - _currentOffset) {
        _index++;
        _offset = 0;
      } else {
        _offset += maxLength;
      }
      final String opData = op.isInsert
          ? op.data.substring(_currentOffset, _currentOffset + maxLength)
          : '';
      final int opLength = (opData.isNotEmpty) ? opData.length : maxLength;
      return new Operation._(opKey, opLength, opData, opAttributes);
    }
    return new Operation.retain(length);
  }
}
