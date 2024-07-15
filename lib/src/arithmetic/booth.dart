// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// booth.dart
// Generation of Booth Encoded partial products for multiplication
//
// 2024 May 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/utils.dart';

/// Simplest version of bit string representation
String bitString(LogicValue value) => value.toString(includeWidth: false);

/// A bundle for the leaf radix compute nodes
///    This holds the multiples of the multiplicand that are needed for encoding
class RadixEncode extends LogicStructure {
  /// Which multiples need to be selected
  final Logic multiples;

  /// 'sign' of multiple
  final Logic sign;

  /// Structure for holding Radix Encoding
  RadixEncode({required int numMultiples})
      : this._(
            Logic(width: numMultiples, name: 'multiples'), Logic(name: 'sign'));

  RadixEncode._(this.multiples, this.sign, {String? name})
      : super([multiples, sign], name: name ?? 'RadixLogic');

  @override
  RadixEncode clone({String? name}) =>
      RadixEncode(numMultiples: multiples.width);
}

/// Base interface for radix radixEncoder
class RadixEncoder {
  /// The radix of the radixEncoder
  int radix;

  /// Baseline call for setting up an empty radixEncoder
  RadixEncoder(this.radix);

  /// Encode a multiplier slice into the Booth encoded value
  RadixEncode encode(Logic multiplierSlice) {
    assert(
        multiplierSlice.width == log2Ceil(radix) + 1,
        'multiplier slice width ${multiplierSlice.width}'
        'must be same length as log(radix)+1=${log2Ceil(radix) + 1}');
    final width = log2Ceil(radix) + 1;
    final inputXor = Logic(width: width);
    inputXor <=
        (multiplierSlice ^ (multiplierSlice >>> 1))
            .slice(multiplierSlice.width - 1, 0);

    final multiples = <Logic>[];
    for (var i = 2; i < radix + 1; i += 2) {
      final variantA = LogicValue.ofInt(i - 1, width);
      final xorA = variantA ^ (variantA >>> 1);
      final variantB = LogicValue.ofInt(i, width);
      final xorB = variantB ^ (variantB >>> 1);
      // Multiples don't agree on a bit position so we will skip that position
      final multiplesDisagree = xorA ^ xorB;
      // Where multiples agree, we need the sense or direction (1 or 0)
      final senseMultiples = xorA & xorB;

      multiples.add([
        for (var j = 0; j < width - 1; j++)
          if (multiplesDisagree[j].isZero)
            if (senseMultiples[j].isZero) ~inputXor[j] else inputXor[j]
      ].swizzle().and());
    }

    return RadixEncode._(
        multiples.rswizzle(), multiplierSlice[multiplierSlice.width - 1]);
  }
}

/// A class that generates the Booth encoding of the multipler
class MultiplierEncoder {
  /// Access the multiplier
  Logic multiplier = Logic();

  /// Number of row radixEncoders
  late final int rows;

  Logic _extendedMultiplier = Logic();
  late final RadixEncoder _encoder;
  late final int _sliceWidth;

  /// Generate an encoding of the input multiplier
  MultiplierEncoder(this.multiplier, RadixEncoder radixEncoder,
      {bool signed = true})
      : _encoder = radixEncoder,
        _sliceWidth = log2Ceil(radixEncoder.radix) + 1 {
    // Unsigned encoding wants to overlap past the multipler
    if (signed) {
      rows =
          ((multiplier.width + (signed ? 0 : 1)) / log2Ceil(radixEncoder.radix))
              .ceil();
    } else {
      rows = (((multiplier.width + 1) % (_sliceWidth - 1) == 0) ? 0 : 1) +
          ((multiplier.width + 1) ~/ log2Ceil(radixEncoder.radix));
    }
    // slices overlap by 1 and start at -1
    _extendedMultiplier = (signed
        ? multiplier.signExtend(rows * (_sliceWidth - 1))
        : multiplier.zeroExtend(rows * (_sliceWidth - 1)));
  }

  /// Retrieve the Booth encoding for the row
  RadixEncode getEncoding(int row) {
    assert(row < rows, 'row $row is not < number of encoding rows $rows');
    final base = row * (_sliceWidth - 1);
    final multiplierSlice = [
      if (row > 0)
        _extendedMultiplier.slice(base + _sliceWidth - 2, base - 1)
      else
        [_extendedMultiplier.slice(base + _sliceWidth - 2, base), Const(0)]
            .swizzle()
    ];
    return _encoder.encode(multiplierSlice.first);
  }
}

/// A class accessing the multiples of the multiplicand at a position
class MultiplicandSelector {
  /// radix of the selector
  int radix;

  /// The bit shift of the selector (typically overlaps 1)
  int shift;

  /// New width of partial products generated from the multiplicand
  int get width => multiplicand.width + shift - 1;

  /// Access the multiplicand
  Logic multiplicand = Logic();

  /// Place to store multiples of the multiplicand
  late LogicArray multiples;

  /// Generate required multiples of multiplicand
  MultiplicandSelector(this.radix, this.multiplicand, {bool signed = true})
      : shift = log2Ceil(radix),
        assert(radix <= 16, 'beyond radix 16 is not yet supported') {
    final width = multiplicand.width + shift;
    final numMultiples = radix ~/ 2;
    multiples = LogicArray([numMultiples], width);
    final extendedMultiplicand = signed
        ? multiplicand.signExtend(width)
        : multiplicand.zeroExtend(width);

    for (var pos = 0; pos < numMultiples; pos++) {
      final ratio = pos + 1;
      multiples.elements[pos] <=
          switch (ratio) {
            1 => extendedMultiplicand,
            2 => extendedMultiplicand << 1,
            3 => (extendedMultiplicand << 2) - extendedMultiplicand,
            4 => extendedMultiplicand << 2,
            5 => (extendedMultiplicand << 2) + extendedMultiplicand,
            6 => (extendedMultiplicand << 3) - (extendedMultiplicand << 1),
            7 => (extendedMultiplicand << 3) - extendedMultiplicand,
            8 => extendedMultiplicand << 3,
            _ => extendedMultiplicand
            // TODO(desmonddak): generalize to support higher radix than 16
          };
    }
  }

  /// Retrieve the multiples of the multiplicand at current bit position
  Logic getMultiples(int col) => [
        for (var i = 0; i < multiples.elements.length; i++)
          multiples.elements[i][col]
      ].swizzle().reversed;

  Logic _select(Logic multiples, RadixEncode encode) =>
      (encode.multiples & multiples).or() ^ encode.sign;

  /// Select the partial product term from the multiples using a RadixEncode
  Logic select(int col, RadixEncode encode) =>
      _select(getMultiples(col), encode);
}

/// A class that generates a set of partial products
class PartialProductGenerator {
  /// Get the shift increment between neighboring product rows
  int get shift => selector.shift;

  /// The actual shift in each row
  final rowShift = <int>[];

  /// rows of partial products
  int get rows => partialProducts.length;

  /// The multiplicand term (X)
  Logic get multiplicand => selector.multiplicand;

  /// The multiplier term (Y)
  Logic get multiplier => encoder.multiplier;

  /// Partial Products output
  late List<List<Logic>> partialProducts = [];

  /// Encoder for the full multiply operand
  late final MultiplierEncoder encoder;

  /// Selector for the multiplicand which uses the encoder to index into
  /// multiples of the multiplicand and generate partial products
  late final MultiplicandSelector selector;

  /// Operands are signed
  late bool signed = true;

  // Used to avoid sign extending more than once
  var _signExtended = false;

  /// Construct the partial product matrix
  PartialProductGenerator(
      Logic multiplicand, Logic multiplier, RadixEncoder radixEncoder,
      {this.signed = true}) {
    encoder = MultiplierEncoder(multiplier, radixEncoder, signed: signed);
    selector =
        MultiplicandSelector(radixEncoder.radix, multiplicand, signed: signed);
    _build();
  }

  /// Setup the partial products array (partialProducts and rowShift)
  void _build() {
    _signExtended = false;
    partialProducts.clear();
    rowShift.clear();
    for (var row = 0; row < encoder.rows; row++) {
      partialProducts.add(List.generate(
          selector.width, (i) => selector.select(i, encoder.getEncoding(row))));
    }
    for (var row = 0; row < rows; row++) {
      rowShift.add(row * shift);
    }
  }

  /// Fully sign extend the PP array: useful for reference only
  void bruteForceSignExtend() {
    assert(!_signExtended, 'Partial Product array already sign-extended');
    _signExtended = true;
    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];
    for (var row = 0; row < rows; row++) {
      final addend = partialProducts[row];
      final sign = signed ? addend.last : signs[row];
      addend.addAll(List.filled((rows - row) * shift, sign));
      if (row > 0) {
        addend
          ..insertAll(0, List.filled(shift - 1, Const(0)))
          ..insert(0, signs[row - 1]);
        rowShift[row] -= shift;
      }
    }
    // Insert carry bit in extra row
    partialProducts.add(List.generate(selector.width, (i) => Const(0)));
    partialProducts.last.insert(0, signs[rows - 2]);
    rowShift.add((rows - 2) * shift);
  }

  /// Sign extend the PP array using stop bits
  /// If possible, fold the final carry into another row (only when rectangular
  /// enough that carry bit lands outside another row).
  /// This technique can then be combined with a first-row extension technique
  /// for folding in the final carry.
  void signExtendWithStopBitsRect() {
    assert(!_signExtended, 'Partial Product array already sign-extended');
    _signExtended = true;

    final finalCarryPos = shift * (rows - 1);
    final finalCarryRelPos = finalCarryPos - selector.width - shift;
    final finalCarryRow =
        ((encoder.multiplier.width > selector.multiplicand.width) &&
                (finalCarryRelPos > 0))
            ? (finalCarryRelPos / shift).floor()
            : 0;

    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];
    for (var row = 0; row < rows; row++) {
      final addend = partialProducts[row];
      final sign = signed ? addend.last : signs[row];
      if (row == 0) {
        if (signed) {
          addend.addAll(List.filled(shift - 1, sign)); // signed only?
        } else {
          addend.addAll(List.filled(shift, sign));
        }
        addend.add(~sign);
      } else {
        if (signed) {
          addend.last = ~sign;
        } else {
          addend.add(~sign);
        }
        addend
          ..addAll(List.filled(shift - 1, Const(1)))
          ..insertAll(0, List.filled(shift - 1, Const(0)))
          ..insert(0, signs[row - 1]);
        rowShift[row] -= shift;
      }
    }

    if (finalCarryRow > 0) {
      final extensionRow = partialProducts[finalCarryRow];
      extensionRow
        ..addAll(List.filled(
            finalCarryPos - (extensionRow.length + rowShift[finalCarryRow]),
            Const(0)))
        ..add(signs[rows - 1]);
    } else if (signed) {
      // Create an extra row to hold the final carry bit
      partialProducts
          .add(List.filled(selector.width, Const(0), growable: true));
      partialProducts.last.insert(0, signs[rows - 2]);
      rowShift.add((rows - 2) * shift);

      // Hack for radix-2
      if (shift == 1) {
        partialProducts.last.last = ~partialProducts.last.last;
      }
    }
  }

  /// Sign extend the PP array using stop bits without adding a row
  void signExtendCompact() {
    assert(!_signExtended, 'Partial Product array already sign-extended');
    _signExtended = true;

    final lastRow = rows - 1;
    final firstAddend = partialProducts[0];
    final lastAddend = partialProducts[lastRow];
    var alignRow0Sign = selector.width -
        shift * lastRow -
        ((shift > 1)
            ? 1
            : signed
                ? 1
                : 0);
    if (alignRow0Sign < 0) {
      alignRow0Sign = 0;
    }

    // stdout.write('align is $alignRow0Sign, rows=$rows\n');

    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];

    final propagate =
        List.generate(rows, (i) => List.filled(0, Logic(), growable: true));
    for (var row = 0; row < rows; row++) {
      propagate[row].add(signs[row]);
      for (var col = 0; col < 2 * (shift - 1); col++) {
        propagate[row].add(partialProducts[row][col]);
      }
      for (var col = 1; col < propagate[row].length; col++) {
        propagate[row][col] = propagate[row][col] & propagate[row][col - 1];
      }
    }
    final m =
        List.generate(rows, (i) => List.filled(0, Logic(), growable: true));
    for (var row = 0; row < rows; row++) {
      for (var c = 0; c < shift - 1; c++) {
        m[row].add(partialProducts[row][c] ^ propagate[row][c]);
      }
      m[row].addAll(List.filled(shift - 1, Logic()));
    }

    for (var i = shift - 1; i < m[lastRow].length; i++) {
      m[lastRow][i] = lastAddend[i] ^
          (i < alignRow0Sign ? propagate[lastRow][i] : Const(0));
    }
    final remainders = List.filled(rows, Logic());
    for (var row = 0; row < lastRow; row++) {
      remainders[row] = propagate[row][shift - 1];
    }
    remainders[lastRow] <= propagate[lastRow][alignRow0Sign];
    // Hack for radix-2

    // stdout.write('remainders ${bitString(remainders[lastRow].value)}\n');

    // Compute Sign extension for row==0
    final firstSign = signed ? firstAddend.last : signs[0];
    final q = [
      firstSign ^ remainders[lastRow],
      ~(firstSign & ~remainders[lastRow]),
    ];
    q.insertAll(1, List.filled(shift - 1, ~q[1]));

    for (var row = 0; row < rows; row++) {
      final addend = partialProducts[row];
      if (row > 0) {
        final mLimit = (row == lastRow) ? 2 * (shift - 1) : shift - 1;
        for (var i = 0; i < mLimit; i++) {
          addend[i] = m[row][i];
        }
        // Stop bits
        if (signed) {
          addend.last = ~addend.last;
        } else {
          addend.add(~signs[row]);
        }
        addend
          ..insert(0, remainders[row - 1])
          ..addAll(List.filled(shift - 1, Const(1)));
        rowShift[row] -= 1;
      } else {
        for (var i = 0; i < shift - 1; i++) {
          firstAddend[i] = m[0][i];
        }
        if (signed) {
          firstAddend.last = q[0];
        } else {
          firstAddend.add(q[0]);
        }
        firstAddend.addAll(q.getRange(1, q.length));
      }
    }
    if (shift == 1) {
      lastAddend.add(Const(1));
    }
  }

  /// Return the actual largest width of all rows
  int maxWidth() {
    var maxW = 0;
    for (var row = 0; row < rows; row++) {
      final entry = partialProducts[row];
      if (entry.length + rowShift[row] > maxW) {
        maxW = entry.length + rowShift[row];
      }
    }
    return maxW;
  }

  /// Accumulate the partial products and return as BigInt
  BigInt evaluate({bool signed = false}) {
    final maxW = maxWidth();
    var accum = BigInt.from(0);
    for (var row = 0; row < rows; row++) {
      final pp = partialProducts[row].rswizzle().value;
      final value = pp.zeroExtend(maxW) << rowShift[row];
      if (pp.isValid) {
        accum += value.toBigInt();
      }
    }
    final sum = LogicValue.ofBigInt(accum, maxW).toBigInt();
    return signed ? sum.toSigned(maxW) : sum;
  }

  /// Print out the partial product matrix
  @override
  String toString() {
    final str = StringBuffer();

    final maxW = maxWidth();
    final nonSignExtendedPad = _signExtended
        ? 0
        : shift > 2
            ? shift - 1
            : 1;
    // We will print encoding(1-hot multiples and sign) before each row
    final shortPrefix =
        '99 ${'M='.padRight(2 + selector.radix ~/ 2)} S= : '.length +
            3 * nonSignExtendedPad;

    // print bit position header
    str.write(' ' * shortPrefix);
    for (var i = maxW - 1; i >= 0; i--) {
      final bits = i > 9 ? 2 : 1;
      str
        ..write('$i')
        ..write(' ' * (3 - bits));
    }
    str.write('\n');
    // Partial product matrix:  rows of multiplicand multiples shift by
    //    rowshift[row]
    for (var row = 0; row < rows; row++) {
      final rowStr = (row < 10) ? '0$row' : '$row';
      if (row < encoder.rows) {
        final encoding = encoder.getEncoding(row);
        if (encoding.multiples.value.isValid) {
          str.write('$rowStr M=${bitString(encoding.multiples.reversed.value)} '
              'S=${encoding.sign.value.toInt()}: ');
        } else {
          str.write(' ' * shortPrefix);
        }
      } else {
        str.write('$rowStr ${'M='.padRight(2 + selector.radix ~/ 2)} S= : ');
      }
      final entry = partialProducts[row].reversed.toList();
      final prefixCnt =
          maxW - (entry.length + rowShift[row]) + nonSignExtendedPad;
      str.write('   ' * prefixCnt);
      for (var col = 0; col < entry.length; col++) {
        str.write('${bitString(entry[col].value)}  ');
      }
      final suffixCnt = rowShift[row];
      final value = entry.swizzle().value.zeroExtend(maxW) << suffixCnt;
      final intValue = value.isValid ? value.toBigInt() : BigInt.from(-1);
      str
        ..write('   ' * suffixCnt)
        ..write(': ${bitString(value)}')
        ..write(' = ${value.isValid ? intValue : "<invalid>"}'
            ' (${value.isValid ? intValue.toSigned(maxW) : "<invalid>"})\n');
    }
    // Compute and print binary representation from accumulated value
    // Later: we will compare with a compression tree result
    str
      ..write('=' * (shortPrefix + 3 * maxW))
      ..write('\n')
      ..write(' ' * shortPrefix);

    final sum = LogicValue.ofBigInt(evaluate(), maxW);
    // print out the sum as a MSB-first bitvector
    for (final elem in [for (var i = 0; i < maxW; i++) sum[i]].reversed) {
      str.write('${elem.toInt()}  ');
    }
    str.write(': ${bitString(sum)} = '
        '${evaluate()} (${evaluate(signed: true)})\n\n');
    return str.toString();
  }
}
