// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// booth.dart
// Implementation of compression trees for multipliers
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
  RadixEncoder() : radix = 0;

  /// Structure style of radix radixEncoder
  RadixEncoder.initRadix(this.radix);

  /// Encode a multiplier slice into the Booth encoded value
  RadixEncode encode(Logic multiplierSlice) {
    assert(
        multiplierSlice.width == log2Ceil(radix) + 1,
        'multiplier slice width ${multiplierSlice.width}'
        'must be same length as log(radix)+1=${log2Ceil(radix) + 1}');
    return RadixEncode(numMultiples: 0);
  }
}

/// A Radix-2 encoder
class Radix2Encoder extends RadixEncoder {
  /// Create a Radix-2 encoder
  Radix2Encoder() : super.initRadix(2);

  // multiple is in [0,1]  followed by sign
  @override
  RadixEncode encode(Logic multiplierSlice) {
    final xor = (multiplierSlice ^ (multiplierSlice >>> 1))
        .slice(multiplierSlice.width - 1, 0);
    return RadixEncode._(xor[0], multiplierSlice[multiplierSlice.width - 1]);
  }
}

/// A Radix-4 encoder
class Radix4Encoder extends RadixEncoder {
  /// Create a Radix-4 encoder
  Radix4Encoder() : super.initRadix(4);

  @override
  RadixEncode encode(Logic multiplierSlice) {
    final xor = (multiplierSlice ^ (multiplierSlice >>> 1))
        .slice(multiplierSlice.width - 1, 0);

    return RadixEncode._([~xor[0] & xor[1], xor[0]].swizzle(),
        multiplierSlice[multiplierSlice.width - 1]);
  }
}

/// A Radix-8 encoder
class Radix8Encoder extends RadixEncoder {
  /// Create a Radix-8 encoder
  Radix8Encoder() : super.initRadix(8);

  @override
  RadixEncode encode(Logic multiplierSlice) {
    final xor = (multiplierSlice ^ (multiplierSlice >>> 1))
        .slice(multiplierSlice.width - 1, 0);

    return RadixEncode._(
        [
          xor[2] & ~xor[1] & ~xor[0], // 4M
          xor[2] & xor[0], // 3M
          xor[1] & ~xor[0], // 2M
          ~xor[2] & xor[0], // M
        ].swizzle(),
        multiplierSlice[multiplierSlice.width - 1]);
  }
}

/// A Radix-16 encoder
class Radix16Encoder extends RadixEncoder {
  /// Create a Radix-16 encoder
  Radix16Encoder() : super.initRadix(16);

  @override
  RadixEncode encode(Logic multiplierSlice) {
    final xor = (multiplierSlice ^ (multiplierSlice >>> 1))
        .slice(multiplierSlice.width - 1, 0);

    return RadixEncode._(
        [
          xor[3] & ~xor[2] & ~xor[1] & ~xor[0], // 8M
          xor[3] & ~xor[2] & xor[0], // 7M
          xor[3] & xor[1] & ~xor[0], // 6M
          xor[3] & xor[2] & xor[0], // 5M
          xor[2] & ~xor[1] & ~xor[0], // 4M
          ~xor[3] & xor[2] & xor[0], // 3M
          ~xor[3] & xor[1] & ~xor[0], // 2M
          ~xor[3] & ~xor[2] & xor[0] // M
        ].swizzle(),
        multiplierSlice[multiplierSlice.width - 1]);
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
  MultiplierEncoder(this.multiplier, RadixEncoder radixEncoder)
      : _encoder = radixEncoder,
        _sliceWidth = log2Ceil(radixEncoder.radix) + 1 {
    rows = (multiplier.width / log2Ceil(radixEncoder.radix)).ceil();
    // slices overlap by 1 and start at -1
    _extendedMultiplier = multiplier.signExtend(rows * (_sliceWidth - 1));
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
    // final multiplierSlice = [
    //   if (row > 0)
    //     {_extendedMultiplier.slice(base + _sliceWidth - 2, base - 1)}
    //   else
    //     {
    //       [_extendedMultiplier.slice(base + _sliceWidth - 2, base), Const(0)]
    //           .swizzle()
    //     }
    // ];
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
  MultiplicandSelector(this.radix, this.multiplicand)
      : shift = log2Ceil(radix) {
    final width = multiplicand.width + shift;
    final numMultiples = radix ~/ 2;
    multiples = LogicArray([numMultiples], width);
    final extendedMultiplicand = multiplicand.signExtend(width);

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

  // Used to avoid sign extending more than once
  var _signExtended = false;

  /// Construct the partial product matrix
  PartialProductGenerator(
      Logic multiplicand, Logic multiplier, RadixEncoder radixEncoder) {
    encoder = MultiplierEncoder(multiplier, radixEncoder);
    selector = MultiplicandSelector(radixEncoder.radix, multiplicand);
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
      // Perform full sign extension
      final addend = partialProducts[row];
      final sign = addend.last;
      addend.addAll(List.filled((rows - row) * shift, sign));
      if (row > 0) {
        // Insert the carry from previous row
        addend
          ..insertAll(0, List.filled(shift - 1, Const(0)))
          ..insert(0, signs[row - 1]);
        rowShift[row] -= shift;
      }
    }
    // If last row has a carry insert carry bit in extra row
    partialProducts.add(List.generate(selector.width, (i) => Const(0)));
    partialProducts.last.insert(0, signs[rows - 2]);
    rowShift.add((rows - 2) * shift);
  }

  /// Sign extend the PP array using stop bits: useful for reference only
  void signExtendWithStopBits() {
    assert(!_signExtended, 'Partial Product array already sign-extended');
    _signExtended = true;
    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];
    for (var row = 0; row < rows; row++) {
      // Perform single sign extension:
      //    first row uses sign * #shift-1, stopped with ~sign
      //    other rows filp the MSB (sign) followed by #shift-1 stop bits (1)
      final addend = partialProducts[row];
      final sign = addend.last;
      if (row == 0) {
        addend
          ..addAll(List.filled(shift - 1, sign))
          ..add(~sign);
      } else {
        addend
          ..last = ~sign
          ..addAll(List.filled(shift - 1, Const(1)))
          ..insertAll(0, List.filled(shift - 1, Const(0)))
          ..insert(0, signs[row - 1]);
        rowShift[row] -= shift;
      }
    }
    // Insert carry bit into extra row
    partialProducts.add(List.generate(selector.width, (i) => Const(0)));
    partialProducts.last.insert(0, signs[rows - 2]);
    rowShift.add((rows - 2) * shift);

    // Hack for radix-2
    if (shift == 1) {
      partialProducts.last.last = ~partialProducts.last.last;
    }
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
      // Perform single sign extension:
      //    first row uses sign * #shift-1, stopped with ~sign
      //    other rows filp the MSB (sign) followed by #shift-1 stop bits (1)
      final sign = addend.last;
      if (row == 0) {
        addend
          ..addAll(List.filled(shift - 1, sign))
          ..add(~sign);
      } else {
        // sign extend and insert the carry from previous row
        addend
          ..last = ~sign
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
      // while (finalCarryPos > extensionRow.length + rowShift[finalCarryRow]) {
      //   extensionRow.add(Const(0));
      // }
    } else {
      // Create an extra row to hold the final carry bit
      partialProducts
          .add(List.filled(selector.width, Const(0), growable: true));
      // New last row
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
    final alignRow0Sign = selector.width - 1 - shift * lastRow;

    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];

    final propagate =
        List.generate(rows, (i) => List.filled(0, Logic(), growable: true));
    for (var row = 0; row < rows; row++) {
      // propagate.add(<Logic>[]);
      propagate[row].add(signs[row]);
      for (var col = 0; col < 2 * (shift - 1); col++) {
        propagate[row].add(partialProducts[row][col]);
      }
      for (var col = 1; col < propagate[row].length; col++) {
        propagate[row][col] = propagate[row][col] & propagate[row][col - 1];
      }
    }
    // final m = <List<Logic>>[];
    final m =
        List.generate(rows, (i) => List.filled(0, Logic(), growable: true));
    for (var row = 0; row < rows; row++) {
      // m.add(<Logic>[]);
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
    if (shift == 1) {
      lastAddend
        ..last = ~lastAddend.last
        ..add(Const(0));
    }

    // Compute Sign extension for row==0
    final q = [
      firstAddend.last ^ remainders[lastRow],
      ~(firstAddend.last & ~remainders[lastRow]),
    ];
    q.insertAll(1, List.filled(shift - 1, ~q[1]));
    // final qLast = q[1];
    // for (var i = 0; i < shift - 1; i++) {
    //   q.insert(1, ~qLast);
    // }

    for (var row = 0; row < rows; row++) {
      final addend = partialProducts[row];
      if (row > 0) {
        final mLimit = (row == lastRow) ? 2 * (shift - 1) : shift - 1;
        for (var i = 0; i < mLimit; i++) {
          addend[i] = m[row][i];
        }
        // Stop bits
        addend
          ..insert(0, remainders[row - 1])
          ..last = ~partialProducts[row].last
          ..addAll(List.filled(shift - 1, Const(1)));
        rowShift[row] -= 1;
      } else {
        for (var i = 0; i < shift - 1; i++) {
          firstAddend[i] = m[0][i];
        }
        firstAddend
          ..last = q[0]
          ..addAll(q.getRange(1, q.length));

        // for (var i = 0; i < q.length; i++) {
        //   if (i == 0) {
        //     firstAddend.last = q[i];
        //   } else {
        //     firstAddend.add(q[i]);
        //   }
        // }
      }
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
  void print() {
    final maxW = maxWidth();
    final nonSignExtendedPad = _signExtended ? 0 : shift - 1;
    // We will print encoding(1-hot multiples and sign) before each row
    final shortPrefix =
        '${'M='.padRight(2 + selector.radix ~/ 2)} S= : '.length +
            3 * nonSignExtendedPad;

    // print bit position header
    stdout.write(' ' * shortPrefix);
    for (var i = maxW - 1; i >= 0; i--) {
      final bits = i > 9 ? 2 : 1;
      stdout
        ..write('$i')
        ..write(' ' * (3 - bits));
    }
    stdout.write('\n');
    // Partial product matrix:  rows of multiplicand multiples shift by
    //    rowshift[row]
    for (var row = 0; row < rows; row++) {
      if (row < encoder.rows) {
        final encoding = encoder.getEncoding(row);
        stdout.write('M=${bitString(encoding.multiples.reversed.value)} '
            'S=${encoding.sign.value.toInt()}: ');
      } else {
        stdout.write('${'M='.padRight(2 + selector.radix ~/ 2)} S= : ');
      }
      final entry = partialProducts[row].reversed.toList();
      final prefixCnt =
          maxW - (entry.length + rowShift[row]) + nonSignExtendedPad;
      stdout.write('   ' * prefixCnt);
      for (var col = 0; col < entry.length; col++) {
        stdout.write('${bitString(entry[col].value)}  ');
      }
      final suffixCnt = rowShift[row];
      final value = entry.swizzle().value.zeroExtend(maxW) << suffixCnt;
      final intValue = value.toBigInt();
      stdout
        ..write('   ' * suffixCnt)
        ..write(': ${bitString(value)}')
        ..write(' = ${value.isValid ? intValue : "<invalid>"}'
            ' (${value.isValid ? intValue.toSigned(maxW) : "<invalid>"})\n');
    }
    // Compute and print binary representation from accumulated value
    // Later: we will compare with a compression tree result
    stdout
      ..write('=' * (shortPrefix + 3 * maxW))
      ..write('\n')
      ..write(' ' * shortPrefix);

    final sum = LogicValue.ofBigInt(evaluate(), maxW);
    // print out the sum as a MSB-first bitvector
    for (final elem in [for (var i = 0; i < maxW; i++) sum[i]].reversed) {
      stdout.write('${elem.toInt()}  ');
    }
    stdout.write(': ${bitString(sum)} = '
        '${evaluate()} (${evaluate(signed: true)})\n\n');
  }
}
