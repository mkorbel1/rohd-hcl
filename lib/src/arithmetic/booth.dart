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
    final xor = Logic(width: multiplierSlice.width) - 1;
    xor <=
        (multiplierSlice ^ (multiplierSlice >>> 1))
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
    final xor = Logic(width: multiplierSlice.width) - 1;
    xor <=
        (multiplierSlice ^ (multiplierSlice >>> 1))
            .slice(multiplierSlice.width - 1, 0);

    final enc = RadixEncode._([~xor[0] & xor[1], xor[0]].swizzle(),
        multiplierSlice[multiplierSlice.width - 1]);
    return enc;
  }
}

/// A Radix-8 encoder
class Radix8Encoder extends RadixEncoder {
  /// Create a Radix-8 encoder
  Radix8Encoder() : super.initRadix(8);

  @override
  RadixEncode encode(Logic multiplierSlice) {
    final xor = Logic(width: multiplierSlice.width) - 1;
    xor <=
        (multiplierSlice ^ (multiplierSlice >>> 1))
            .slice(multiplierSlice.width - 1, 0);

    final enc = RadixEncode._(
        [
          xor[2] & ~xor[1] & ~xor[0], // 4M
          xor[2] & xor[0], // 3M
          xor[1] & ~xor[0], // 2M
          ~xor[2] & xor[0], // M
        ].swizzle(),
        multiplierSlice[multiplierSlice.width - 1]);
    // stdout
    //   ..write('X =${bitString(xor.value)}\n')
    //   ..write('M =${bitString(enc.multiples.value)}\n')
    //   ..write('S=${bitString(enc.sign.value)}\n');
    return enc;
  }
}

/// A Radix-16 encoder
class Radix16Encoder extends RadixEncoder {
  /// Create a Radix-16 encoder
  Radix16Encoder() : super.initRadix(16);

  @override
  RadixEncode encode(Logic multiplierSlice) {
    final xor = Logic(width: multiplierSlice.width) - 1;
    xor <=
        (multiplierSlice ^ (multiplierSlice >>> 1))
            .slice(multiplierSlice.width - 1, 0);

    final enc = RadixEncode._(
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
    // stdout
    //   ..write('X =${bitString(xor.value)}\n')
    //   ..write('M =${bitString(enc.multiples.value)}\n')
    //   ..write('S=${bitString(enc.sign.value)}\n');
    return enc;
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
    // stdout
    //   ..write('Y =${bitString(multiplier.value)}\n')
    //   ..write('EY=${bitString(_extendedMultiplier.value)}\n');
  }

  /// Retrieve the Booth encoding for the row
  RadixEncode getEncoding(int row) {
    assert(row < rows, 'row $row is not < number of encoding rows $rows');
    final base = row * (_sliceWidth - 1);
    final multiplierSlice = [
      if (row > 0)
        {_extendedMultiplier.slice(base + _sliceWidth - 2, base - 1)}
      else
        {
          [_extendedMultiplier.slice(base + _sliceWidth - 2, base), Const(0)]
              .swizzle()
        }
    ];
    return _encoder.encode(multiplierSlice.first.first);
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
    // stdout
    // ..write('X =${bitString(multiplicand.value)}\n')
    // ..write('EX =${bitString(extendedMultiplicand.value)}\n');
    for (var pos = 0; pos < numMultiples; pos++) {
      final ratio = pos + 1;
      switch (ratio) {
        case 1:
          multiples.elements[pos] <= extendedMultiplicand;
        case 2:
          multiples.elements[pos] <= extendedMultiplicand << 1;
        case 3:
          multiples.elements[pos] <=
              (extendedMultiplicand << 2) - extendedMultiplicand;
        case 4:
          multiples.elements[pos] <= extendedMultiplicand << 2;
        case 5:
          multiples.elements[pos] <=
              (extendedMultiplicand << 2) + extendedMultiplicand;
        case 6:
          multiples.elements[pos] <=
              (extendedMultiplicand << 3) - (extendedMultiplicand << 1);
        case 7:
          multiples.elements[pos] <=
              (extendedMultiplicand << 3) - extendedMultiplicand;
        case 8:
          multiples.elements[pos] <= extendedMultiplicand << 3;
      }
      // stdout.write(
      //     'M$pos(${ratio}X)=${bitString(multiples.elements[pos].value)}\n');
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
      final sign = partialProducts[row].last;
      for (var col = 0; col < (rows - row) * shift; col++) {
        partialProducts[row].add(sign);
      }
      if (row > 0) {
        // Insert the carry from previous row
        rowShift[row] -= shift;
        for (var i = 0; i < shift - 1; i++) {
          partialProducts[row].insert(0, Const(0));
        }
        partialProducts[row].insert(0, signs[row - 1]);
      }
    }
    // If last row has a carry insert carry bit in extra row
    partialProducts.add(List.generate(selector.width, (i) => Const(0)));
    partialProducts[rows - 1].insert(0, signs[rows - 2]);
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
      final sign = partialProducts[row].last;
      if (row == 0) {
        for (var col = 0; col < shift - 1; col++) {
          partialProducts[row].add(sign);
        }
        partialProducts[row].add(~sign);
      } else {
        partialProducts[row].last = ~sign;
        for (var col = 0; col < shift - 1; col++) {
          partialProducts[row].add(Const(1));
        }

        // Insert the carry from previous row
        rowShift[row] -= shift;
        for (var i = 0; i < shift - 1; i++) {
          partialProducts[row].insert(0, Const(0));
        }
        partialProducts[row].insert(0, signs[row - 1]);
      }
    }
    // If last row has a carry, insert carry bit into extra row
    partialProducts.add(List.generate(selector.width, (i) => Const(0)));
    partialProducts[rows - 1].insert(0, signs[rows - 2]);
    rowShift.add((rows - 2) * shift);

    // Hack for radix-2
    if (shift == 1) {
      partialProducts[rows - 1].last = ~partialProducts[rows - 1].last;
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
    stdout.write(
        'pos=$finalCarryPos, $finalCarryRelPos, predict row=$finalCarryRow\n');

    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];
    for (var row = 0; row < rows; row++) {
      // Perform single sign extension:
      //    first row uses sign * #shift-1, stopped with ~sign
      //    other rows filp the MSB (sign) followed by #shift-1 stop bits (1)
      final sign = partialProducts[row].last;
      if (row == 0) {
        for (var col = 0; col < shift - 1; col++) {
          partialProducts[row].add(sign);
        }
        partialProducts[row].add(~sign);
      } else {
        partialProducts[row].last = ~sign;
        for (var col = 0; col < shift - 1; col++) {
          stdout.write('adding 1 to row $row\n');
          partialProducts[row].add(Const(1));
        }
        // Insert the carry from previous row
        rowShift[row] -= shift;
        for (var i = 0; i < shift - 1; i++) {
          partialProducts[row].insert(0, Const(0));
        }
        partialProducts[row].insert(0, signs[row - 1]);
      }
    }

    if (finalCarryRow > 0) {
      final extensionRow = partialProducts[finalCarryRow];
      // stdout.write('we have a final carry row $finalCarryRow > 0\n');

      while (finalCarryPos > extensionRow.length + rowShift[finalCarryRow]) {
        extensionRow.add(Const(0));
      }
      extensionRow.add(signs[rows - 1]);
    } else {
      // stdout.write('we added a new row\n');
      // Create an extra row to hold the final carry bit
      partialProducts.add(List.generate(selector.width, (i) => Const(0)));
      // New last row
      partialProducts[rows - 1].insert(0, signs[rows - 2]);
      rowShift.add((rows - 2) * shift);

      // Hack for radix-2
      if (shift == 1) {
        partialProducts[rows - 1].last = ~partialProducts[rows - 1].last;
      }
    }
  }

  /// Sign extend the PP array using stop bits without adding a row
  void signExtendCompact() {
    assert(!_signExtended, 'Partial Product array already sign-extended');
    _signExtended = true;
    final lastRow = rows - 1;
    final signs = [for (var r = 0; r < rows; r++) encoder.getEncoding(r).sign];

    final propagate = <List<Logic>>[];
    for (var r = 0; r < rows; r++) {
      propagate.add(<Logic>[]);
      propagate[r].add(signs[r]);
      // last row uses 4 propagate, but first rows use only 3?
      for (var c = 0; c < 2 * (shift - 1); c++) {
        propagate[r].add(partialProducts[r][c]);
      }
      for (var c = 1; c < propagate[r].length; c++) {
        propagate[r][c] = propagate[r][c] & propagate[r][c - 1];
      }
    }

    final remainders = [for (var i = 0; i < rows; i++) Logic()];
    for (var r = 0; r < lastRow; r++) {
      remainders[r] = propagate[r][shift - 1];
    }
    final m = <List<Logic>>[];
    for (var r = 0; r < rows; r++) {
      m.add(<Logic>[]);
      for (var c = 0; c < shift - 1; c++) {
        m[r].add(partialProducts[r][c] ^ propagate[r][c]);
      }
      for (var c = 0; c < shift - 1; c++) {
        m[r].add(Logic());
      }
      stdout.write('mlen=${m[r].length} because 2 * ${shift - 1}\n');
    }
    // Compute new LSBs for each row
    final carryProp = Logic();
    final locShift = shift - (selector.width - shift + 1) % shift;
    // final locShift = shift - encoder.multiplier.width % shift;
    carryProp <= propagate[lastRow][shift - 1];
    // stdout
    //     .write('carryProp=${bitString(carryProp.value)\n');

    // print out m
    for (var i = 0; i < m.length; i++) {
      stdout.write('mb($i)=${bitString(m[i].rswizzle().value)}\n');
    }
    stdout.write('\n');

    if (shift == 4) {
      switch (locShift) {
        // radix-16
        case 1: // N=7
          remainders[lastRow] <= propagate[lastRow][5];
        case 2: // N=6 PASS @4
          remainders[lastRow] <= propagate[lastRow][4];
        case 3: // N=5 pass
          remainders[lastRow] <= propagate[lastRow][3];
        case 4: // N=8
          remainders[lastRow] <= propagate[lastRow][6];
      }
    } else if (shift == 3) {
      // radix-8 validated 3, 2, 4
      switch (locShift) {
        case 1: // W=5
          remainders[lastRow] <= propagate[lastRow][3];
        case 2: // W=4
          remainders[lastRow] <= propagate[lastRow][2];
        case 3: // W=6
          remainders[lastRow] <= propagate[lastRow][4];
      }
    } else if (shift == 2) {
      // radix-4 validated 1, 2
      switch (locShift) {
        case 1: // W=5
          remainders[lastRow] <= propagate[lastRow][1];
        case 2: // W=4
          remainders[lastRow] <= propagate[lastRow][2];
      }
    } else if (shift == 1) {
      // fails 16*16@5
      switch (locShift) {
        case 1: // All
          remainders[lastRow] <= propagate[lastRow][0];
      }
    }
    stdout.write('LOCSHIFT is $locShift, '
        'carryProp=${bitString(carryProp.value)}\n');
    // ignore: cascade_invocations
    stdout.write('check:  N=${selector.width - shift + 1} lastRow=$lastRow\n');
    // Where does the sign carry of the last row land?
    // ignore: cascade_invocations
    stdout.write(
        'last sign @pos ${lastRow * shift} vs ${selector.width - shift + 1}'
        ' vs ${encoder.multiplier.width}\n');

    final row0SignPos = selector.width - 1;
    final matchingPPos = row0SignPos - shift * lastRow;
    final lastMPos = matchingPPos;
    // stdout.write('row0SignPos=$row0SignPos  matchingMPos=$matchingPPos'
    //     ' lastMMpos=$lastMPos\n');

    // New style of fixing m:
    stdout.write('lastMPos - 1= ${lastMPos - 1}\n');
    for (var i = shift - 1; i < m[lastRow].length; i++) {
      if (i < lastMPos) {
        stdout.write(
            'm[$i]: pp[$i]=${bitString(partialProducts[lastRow][i].value)} '
            'c=${bitString(carryProp.value)}\n');
        m[lastRow][i] = partialProducts[lastRow][i] ^ propagate[lastRow][i];
        stdout.write('set m[lastRow[$i]= ${bitString(m[lastRow][i].value)}\n');
      } else {
        stdout.write(
            'cp pp ${bitString(partialProducts[lastRow][i].value)} to m[$i]\n');
        m[lastRow][i] = partialProducts[lastRow][i];
      }
    }
    // Hack for radix-2
    if (shift == 1) {
      partialProducts[rows - 1].last = ~partialProducts[rows - 1].last;
      partialProducts[rows - 1].add(Const(0));
    }

    stdout.write('p=');
    for (final elem in propagate[lastRow].reversed) {
      stdout.write('${bitString(elem.value)}  ');
    }
    stdout.write('\nr=');
    for (final elem in remainders.reversed) {
      stdout.write('${elem.value.toString(includeWidth: false)}  ');
    }
    stdout.write('\n');
    // Compute Sign extension for row==0
    final q = [
      partialProducts[0].last ^ remainders[lastRow],
      ~(partialProducts[0].last & ~remainders[lastRow]),
    ];
    final qLast = q[1];
    for (var i = 0; i < shift - 1; i++) {
      q.insert(1, ~qLast);
    }

    stdout.write('q=');
    for (final elem in q.reversed) {
      stdout.write('${elem.value.toString(includeWidth: false)}  ');
    }
    stdout.write('\n');

    // print out m
    for (var i = 0; i < m.length; i++) {
      stdout.write('m($i)=${bitString(m[i].rswizzle().value)}\n');
    }
    stdout.write('\n');

    for (var row = 0; row < rows; row++) {
      if (row > 0) {
        partialProducts[row].insert(0, remainders[row - 1]);
        rowShift[row] -= 1;
        final mLimit = (row == lastRow) ? 2 * (shift - 1) : shift - 1;
        for (var i = 0; i < mLimit; i++) {
          partialProducts[row][i + 1] = m[row][i];
        }
        // Stop bits
        partialProducts[row].last = ~partialProducts[row].last;
        for (var i = 0; i < shift - 1; i++) {
          partialProducts[row].add(Const(1));
        }
      } else {
        for (var i = 0; i < shift - 1; i++) {
          partialProducts[0][i] = m[0][i];
        }
        for (var i = 0; i < q.length; i++) {
          if (i == 0) {
            partialProducts[0].last = q[i];
          } else {
            partialProducts[0].add(q[i]);
          }
        }
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
      final value = partialProducts[row].rswizzle().value.zeroExtend(maxW) <<
          rowShift[row];
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
