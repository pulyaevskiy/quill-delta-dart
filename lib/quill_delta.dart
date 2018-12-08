// Copyright (c) 2018, Anatoly Pulyaevskiy. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Implementation of Quill Delta format in Dart.
library quill_delta;

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:quiver_hashcode/hashcode.dart';

const _attributeEquality = const MapEquality<String, dynamic>(
  keys: const DefaultEquality<String>(),
  values: const DefaultEquality(),
);

enum OperationType { insert, retain, delete}

/// Operation performed on a rich-text document.
class Operation {
  /// Key of this operation, can be "insert", "delete" or "retain".
  final OperationType operationType;

  /// Length of this operation.
  final int length;

  /// Payload of "insert" operation, for other types is set to empty string.
  final String data;

  /// Rich-text attributes set by this operation, can be `null`.
  Map<String, dynamic> get attributes =>
      _attributes == null ? null : new Map<String, dynamic>.from(_attributes);
  final Map<String, dynamic> _attributes;

  Operation._(this.operationType, this.length, this.data, Map attributes)
      : assert(operationType != null && length != null && data != null),
        assert(() {
          if (operationType != OperationType.insert) return true;
          return data.length == length;
        }(), 'Length of insert operation must be equal to the text length.'),
        _attributes = attributes != null
            ? new Map<String, dynamic>.from(attributes)
            : null;

  static String getOperationTypeString(OperationType opType) {
    return opType.toString().split('.').last;
  }

  /// Creates new [Operation] from JSON payload.
  static Operation fromJson(data) {
    final map = new Map<String, dynamic>.from(data);
    if (map.containsKey('insert')) {
      final String text = map['insert'];
      return new Operation._(OperationType.insert, text.length, text, map['attributes']);
    } else if (map.containsKey('delete')) {
      final int length = map['delete'];
      return new Operation._(OperationType.delete, length, '', null);
    } else if (map.containsKey('retain')) {
      final int length = map['retain'];
      return new Operation._(OperationType.retain, length, '', map['attributes']);
    }
    throw new ArgumentError.value(data, 'Invalid data for Delta operation.');
  }

  /// Returns JSON-serializable representation of this operation.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {getOperationTypeString(operationType): value};
    if (_attributes != null) json['attributes'] = attributes;
    return json;
  }

  /// Creates operation which deletes [length] of characters.
  factory Operation.delete(int length) =>
      new Operation._(OperationType.delete, length, '', null);

  /// Creates operation which inserts [text] with optional [attributes].
  factory Operation.insert(String text, [Map<String, dynamic> attributes]) =>
      new Operation._(OperationType.insert, text.length, text, attributes);

  /// Creates operation which retains [length] of characters and optionally
  /// applies attributes.
  factory Operation.retain(int length, [Map<String, dynamic> attributes]) =>
      new Operation._(OperationType.retain, length, '', attributes);

  /// Returns value of this operation.
  ///
  /// For insert operations this returns text, for delete and retain - length.
  dynamic get value => (operationType == OperationType.insert) ? data : length;

  /// Returns `true` if this is a delete operation.
  bool get isDelete => operationType == OperationType.delete;

  /// Returns `true` if this is an insert operation.
  bool get isInsert => operationType == OperationType.insert;

  /// Returns `true` if this is a retain operation.
  bool get isRetain => operationType == OperationType.retain;

  /// Returns `true` if this operation has no attributes, e.g. is plain text.
  bool get isPlain => (_attributes == null || _attributes.isEmpty);

  /// Returns `true` if this operation sets at least one attribute.
  bool get isNotPlain => !isPlain;

  /// Returns `true` is this operation is empty.
  ///
  /// An operation is considered empty if its [length] is equal to `0`.
  bool get isEmpty => length == 0;

  /// Returns `true` is this operation is not empty.
  bool get isNotEmpty => length > 0;

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other is! Operation) return false;
    Operation typedOther = other;
    return operationType == typedOther.operationType &&
        length == typedOther.length &&
        data == typedOther.data &&
        hasSameAttributes(typedOther);
  }

  /// Returns `true` if this operation has attribute specified by [name].
  bool hasAttribute(String name) => isNotPlain && _attributes.containsKey(name);

  /// Returns `true` if [other] operation has the same attributes as this one.
  bool hasSameAttributes(Operation other) {
    return _attributeEquality.equals(_attributes, other._attributes);
  }

  @override
  int get hashCode {
    if (_attributes != null && _attributes.isNotEmpty) {
      int attrsHash =
          hashObjects(_attributes.entries.map((e) => hash2(e.key, e.value)));
      return hash3(operationType, value, attrsHash);
    }
    return hash2(operationType, value);
  }

  @override
  String toString() {
    String attr = attributes == null ? '' : ' + $attributes';
    String text = isInsert ? data.replaceAll('\n', '⏎') : '$length';
    String key = getOperationTypeString(operationType);
    return '$key⟨ $text ⟩$attr';
  }
}

/// Delta represents a document or a modification of a document as a sequence of
/// insert, delete and retain operations.
///
/// Delta consisting of only "insert" operations is usually referred to as
/// "document delta". When delta includes also "retain" or "delete" operations
/// it is a "change delta".
class Delta {
  /// Transforms two attribute sets.
  static Map<String, dynamic> transformAttributes(
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
  static Map<String, dynamic> composeAttributes(
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

  final List<Operation> _operations;

  int _modificationCount = 0;

  Delta._(List<Operation> operations)
      : assert(operations != null),
        _operations = operations;

  /// Creates new empty [Delta].
  factory Delta() => new Delta._(new List<Operation>());

  /// Creates new [Delta] from [other].
  factory Delta.from(Delta other) =>
      new Delta._(new List<Operation>.from(other._operations));

  /// Creates [Delta] from de-serialized JSON representation.
  static Delta fromJson(List data) {
    return new Delta._(data.map(Operation.fromJson).toList());
  }

  /// Returns list of operations in this delta.
  List<Operation> toList() => new List.from(_operations);

  /// Returns JSON-serializable version of this delta.
  List toJson() => toList();

  /// Returns `true` if this delta is empty.
  bool get isEmpty => _operations.isEmpty;

  /// Returns `true` if this delta is not empty.
  bool get isNotEmpty => _operations.isNotEmpty;

  /// Returns number of operations in this delta.
  int get length => _operations.length;

  /// Returns [Operation] at specified [index] in this delta.
  Operation operator [](int index) => _operations[index];

  /// Returns [Operation] at specified [index] in this delta.
  Operation elementAt(int index) => _operations.elementAt(index);

  /// Returns the first [Operation] in this delta.
  Operation get first => _operations.first;

  /// Returns the last [Operation] in this delta.
  Operation get last => _operations.last;

  @override
  operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! Delta) return false;
    Delta typedOther = other;
    final comparator =
        new ListEquality<Operation>(const DefaultEquality<Operation>());
    return comparator.equals(_operations, typedOther._operations);
  }

  @override
  int get hashCode => hashObjects(_operations);

  /// Retain [count] of characters from current position.
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

  /// Delete [count] characters from current position.
  void delete(int count) {
    assert(count >= 0);
    if (count == 0) return;
    push(new Operation.delete(count));
  }

  void _mergeWithTail(Operation operation) {
    assert(isNotEmpty);
    assert(operation != null && last.operationType == operation.operationType);

    final int length = operation.length + last.length;
    final String data = last.data + operation.data;
    final int index = _operations.length;
    _operations.replaceRange(index - 1, index, [
      new Operation._(operation.operationType, length, data, operation.attributes),
    ]);
  }

  /// Pushes new operation into this delta.
  ///
  /// Performs compaction by composing [operation] with current tail operation
  /// of this delta, when possible. For instance, if current tail is
  /// `insert('abc')` and pushed operation is `insert('123')` then existing
  /// tail is replaced with `insert('abc123')` - a compound result of the two
  /// operations.
  void push(Operation operation) {
    if (operation.isEmpty) return;

    int index = _operations.length;
    Operation lastOp = _operations.isNotEmpty ? _operations.last : null;
    if (lastOp != null) {
      if (lastOp.isDelete && operation.isDelete) {
        _mergeWithTail(operation);
        return;
      }

      if (lastOp.isDelete && operation.isInsert) {
        index -= 1; // Always insert before deleting
        lastOp = (index > 0) ? _operations.elementAt(index - 1) : null;
        if (lastOp == null) {
          _operations.insert(0, operation);
          return;
        }
      }

      if (lastOp.isInsert && operation.isInsert) {
        if (lastOp.hasSameAttributes(operation)) {
          _mergeWithTail(operation);
          return;
        }
      }

      if (lastOp.isRetain && operation.isRetain) {
        if (lastOp.hasSameAttributes(operation)) {
          _mergeWithTail(operation);
          return;
        }
      }
    }
    if (index == _operations.length) {
      _operations.add(operation);
    } else {
      final opAtIndex = _operations.elementAt(index);
      _operations.replaceRange(index, index + 1, [operation, opAtIndex]);
    }
    _modificationCount++;
  }

  /// Composes next operation from [thisIter] and [otherIter].
  ///
  /// Returns new operation or `null` if operations from [thisIter] and
  /// [otherIter] nullify each other. For instance, for the pair `insert('abc')`
  /// and `delete(3)` composition result would be empty string.
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
      // otherOp == delete && thisOp in [retain, insert]
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

    // At this point only delete and retain operations are possible.
    if (thisOp.isDelete) {
      // otherOp is either delete or retain, so they nullify each other.
      return null;
    } else if (otherOp.isDelete) {
      return otherOp;
    } else {
      // Retain otherOp which is either retain or insert.
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
    if (isNotEmpty) {
      final Operation last = _operations.last;
      if (last.isRetain && last.isPlain) _operations.removeLast();
    }
  }

  /// Concatenates [other] with this delta and returns the result.
  Delta concat(Delta other) {
    final Delta result = new Delta.from(this);
    if (other.isNotEmpty) {
      // In case first operation of other can be merged with last operation in
      // our list.
      result.push(other._operations.first);
      result._operations.addAll(other._operations.sublist(1));
    }
    return result;
  }

  /// Transforms [index] against this delta.
  ///
  /// Any "delete" operation before specified [index] shifts it backward, as
  /// well as any "insert" operation shifts it forward.
  ///
  /// The [force] argument is used to resolve scenarios when there is an
  /// insert operation at the same position as [index]. If [force] is set to
  /// `true` (default) then position is forced to shift forward, otherwise
  /// position stays at the same index. In other words setting [force] to
  /// `false` gives higher priority to the transformed position.
  ///
  /// Useful to adjust caret or selection positions.
  int transformPosition(int index, {bool force: true}) {
    final iter = new DeltaIterator(this);
    int offset = 0;
    while (iter.hasNext && offset <= index) {
      final op = iter.next();
      if (op.isDelete) {
        index -= math.min(op.length, index - offset);
        continue;
      } else if (op.isInsert && (offset < index || force)) {
        index += op.length;
      }
      offset += op.length;
    }
    return index;
  }

  @override
  String toString() => _operations.join('\n');
}

/// Specialized iterator for [Delta]s.
class DeltaIterator {
  final Delta delta;
  int _index = 0;
  num _offset = 0;
  int _modificationCount;

  DeltaIterator(this.delta) : _modificationCount = delta._modificationCount;

  bool get isNextInsert => nextOperationType == OperationType.insert;
  bool get isNextDelete => nextOperationType == OperationType.delete;
  bool get isNextRetain => nextOperationType == OperationType.retain;

  OperationType get nextOperationType {
    if (_index < delta.length) {
      return delta.elementAt(_index).operationType;
    } else
      return null;
  }

  bool get hasNext => peekLength() < double.infinity;

  /// Returns length of next operation without consuming it.
  ///
  /// Returns [double.infinity] if there is no more operations left to iterate.
  num peekLength() {
    if (_index < delta.length) {
      final Operation operation = delta._operations[_index];
      return operation.length - _offset;
    }
    return double.infinity;
  }

  /// Consumes and returns next operation.
  ///
  /// Optional [length] specifies maximum length of operation to return. Note
  /// that actual length of returned operation may be less than specified value.
  Operation next([num length = double.infinity]) {
    assert(length != null);

    if (_modificationCount != delta._modificationCount) {
      throw new ConcurrentModificationError(delta);
    }

    if (_index < delta.length) {
      final op = delta.elementAt(_index);
      final opType = op.operationType;
      final opAttributes = op.attributes;
      final _currentOffset = _offset;
      num actualLength = math.min(op.length - _currentOffset, length);
      if (actualLength == op.length - _currentOffset) {
        _index++;
        _offset = 0;
      } else {
        _offset += actualLength;
      }
      final String opData = op.isInsert
          ? op.data.substring(_currentOffset, _currentOffset + actualLength)
          : '';
      final int opLength = (opData.isNotEmpty) ? opData.length : actualLength;
      return new Operation._(opType, opLength, opData, opAttributes);
    }
    return new Operation.retain(length);
  }

  /// Skips [length] characters in source delta.
  ///
  /// Returns last skipped operation, or `null` if there was nothing to skip.
  Operation skip(int length) {
    int skipped = 0;
    Operation op;
    while (skipped < length && hasNext) {
      int opLength = peekLength();
      int skip = math.min(length - skipped, opLength);
      op = next(skip);
      skipped += op.length;
    }
    return op;
  }
}
