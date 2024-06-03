// Copxorright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// booth_test.dart
// Tests for the select interface of Booth encoding
//
// 2024 May 21
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';
import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/booth.dart';
import 'package:rohd_hcl/src/utils.dart';
import 'package:test/test.dart';

// TODO(desmonddak): combine rectangular with compact

enum SignExtension { brute, stop, stopRect, compact }

void testPartialProductExhaustive(PartialProductGenerator pp) {
  final widthX = pp.selector.multiplicand.width;
  final widthY = pp.encoder.multiplier.width;

  final limitX = pow(2, widthX);
  final limitY = pow(2, widthY);
  for (var i = 0; i < limitX; i++) {
    for (var j = 0; j < limitY; j++) {
      final X = BigInt.from(i).toSigned(widthX);
      final Y = BigInt.from(j).toSigned(widthY);
      final product = X * Y;

      pp.multiplicand.put(X);
      pp.multiplier.put(Y);
      // stdout.write('$i($X) * $j($Y): should be $product\n');
      if (pp.evaluate(signed: true) != product) {
        stdout.write('Fail: $i($X) * $j($Y): ${pp.evaluate(signed: true)} '
            'vs expected $product\n');
        pp.print();
      }
      expect(pp.evaluate(signed: true), equals(product));
    }
  }
}

void main() {
  test('single partial product test', () async {
    final encoder = RadixEncoder(16);
    const widthX = 10; // 4/7:  64   4/10: 512
    const widthY = 10;
// 3,4 ;   4,8, 5,16  6,32  7,64 8,128  9,256  10, 512
    const i = 1;
    var j = pow(2, widthY - 1).toInt();
    // j = 128; // r=16,N=8
    j = 11; // r=16,N=9?
    // j = 64; // r=8,N=7
    final X = BigInt.from(i).toSigned(widthX);
    final Y = BigInt.from(j).toSigned(widthY);
    final product = X * Y;

    final logicX = Logic(name: 'X', width: widthX);
    final logicY = Logic(name: 'Y', width: widthY);
    logicX.put(X);
    logicY.put(Y);
    final pp = PartialProductGenerator(logicX, logicY, encoder);
    // ignore: cascade_invocations

    logicX.put(X);
    logicY.put(Y);

    pp
      ..print()
      // ..bruteForceSignExtend()
      // ..signExtendWithStopBits()
      // ..signExtendWithStopBitsRect()
      ..signExtendCompact()
      ..print();
    stdout.write(
        'Test: $i($X) * $j($Y) = $product vs ${pp.evaluate(signed: true)}\n');
    if (pp.evaluate(signed: true) != product) {
      stdout.write(
          'Fail: $X * $Y: ${pp.evaluate(signed: true)} vs expected $product\n');
      pp.print();
    }
    expect(pp.evaluate(signed: true), equals(product));
  });

  // TODO(dakdesmond): Why cannot radix8 handle Y width 3
  test('exhaustive rectangular partial product evaluate test', () async {
    final encoder = RadixEncoder(8);
    for (var width = 5; width < 6; width++) {
      final widthX = width;
      stdout.write('Testing widthX=$widthX\n');
      for (var skew = -1; skew < 2; skew++) {
        final widthY = width + skew;
        stdout.write('\tTesting widthY=$widthY\n');

        final pp = PartialProductGenerator(Logic(name: 'X', width: widthX),
            Logic(name: 'Y', width: widthY), encoder);
        // ignore: cascade_invocations
        pp.signExtendWithStopBitsRect();

        testPartialProductExhaustive(pp);
      }
    }
  });

  test('exhaustive partial product evaluate single test', () async {
    final encoder = RadixEncoder(16);
    for (var width = 5; width < 6; width++) {
      final pp = PartialProductGenerator(Logic(name: 'X', width: width),
          Logic(name: 'Y', width: width), encoder);
      // ignore: cascade_invocations
      // pp..bruteForceSignExtend();
      // pp.signExtendWithStopBits();
      // pp.signExtendWithStopBitsRect();
      // ignore: cascade_invocations
      pp.signExtendCompact();

      testPartialProductExhaustive(pp);
    }
  });

  // This is a two-minute exhaustive but quick test
  test(
      'exhaustive partial product evaluate: square all radix, all SignExtension',
      () async {
    for (var radix = 2; radix < 32; radix *= 2) {
      final encoder = RadixEncoder(radix);
      stdout.write('encoding with $encoder\n');
      final shift = log2Ceil(encoder.radix);
      for (var width = shift + 1; width < shift + 2; width++) {
        stdout.write('\tTesting width=$width\n');
        for (final signExtension in SignExtension.values) {
          final pp = PartialProductGenerator(Logic(name: 'X', width: width),
              Logic(name: 'Y', width: width), encoder);
          switch (signExtension) {
            case SignExtension.brute:
              pp.bruteForceSignExtend();
            case SignExtension.stop:
              pp.signExtendWithStopBits();
            case SignExtension.stopRect:
              pp.signExtendWithStopBitsRect();
            case SignExtension.compact:
              pp.signExtendCompact();
          }
          stdout.write('\tTesting extension=$signExtension\n');
          testPartialProductExhaustive(pp);
        }
      }
    }
  });
  // radix16 takes a long time to complete
  test('exhaustive partial product evaluate: rectangular all radix,', () async {
    for (var radix = 2; radix < 32; radix *= 2) {
      final encoder = RadixEncoder(radix);
      stdout.write('encoding with $encoder\n');
      final shift = log2Ceil(encoder.radix);
      for (var width = shift + 1; width < shift + 2; width++) {
        for (var skew = 0; skew < shift + 1; skew++) {
          stdout.write('\tTesting width=$width skew=$skew\n');
          for (final signExtension in [SignExtension.brute]) {
            final pp = PartialProductGenerator(Logic(name: 'X', width: width),
                Logic(name: 'Y', width: width + skew), encoder);
            switch (signExtension) {
              case SignExtension.brute:
                pp.bruteForceSignExtend();
              case SignExtension.stop:
                pp.signExtendWithStopBits();
              case SignExtension.stopRect:
                pp.signExtendWithStopBitsRect();
              case SignExtension.compact:
                pp.signExtendCompact();
            }
            stdout.write('\tTesting extension=$signExtension\n');
            testPartialProductExhaustive(pp);
          }
        }
      }
    }
  });

  /// This slower test elaborates the multiplier each time, but any output
  ///  during each elaboration will have valid logic values which can provide
  /// valuable debug information.
  test('slow exhaustive partial product evaluate test', () async {
    final encoder = RadixEncoder(16);
    const signExtension = SignExtension.brute;
    for (var width = 5; width < 6; width++) {
      final widthX = width;
      final widthY = width + 1;
      final logicX = Logic(name: 'X', width: widthX);
      final logicY = Logic(name: 'Y', width: widthY);
      // ignore: cascade_invocationskjkjkkkkk

      final limitX = pow(2, widthX);
      final limitY = pow(2, widthY);
      for (var j = 0; j < limitY; j++) {
        for (var i = 0; i < limitX; i++) {
          final X = BigInt.from(i).toSigned(widthX);
          final Y = BigInt.from(j).toSigned(widthY);
          final product = X * Y;

          logicX.put(X);
          logicY.put(Y);

          final pp = PartialProductGenerator(logicX, logicY, encoder);
          switch (signExtension) {
            case SignExtension.brute:
              pp.bruteForceSignExtend();
            case SignExtension.stop:
              pp.signExtendWithStopBits();
            case SignExtension.stopRect:
              pp.signExtendWithStopBitsRect();
            case SignExtension.compact:
              pp.signExtendCompact();
          }
          if (pp.evaluate(signed: true) != product) {
            stdout.write('Fail: $i($X) * $j($Y): ${pp.evaluate(signed: true)} '
                'vs expected $product\n');
            pp.print();
          }
          expect(pp.evaluate(signed: true), equals(product));
        }
      }
    }
  });

  // This routine is to reverse-engineer how to create booth encoders from
  //  XOR computations on the multiplier bits
  // It is used to validate the RadixNEncode
  test('radix extract', () async {
    // for (var radix = 2; radix < 32; radix *= 2) {
    for (var radix = 2; radix < 32; radix *= 2) {
      stdout.write('Radix-$radix\n');
      final encoder = RadixEncoder(radix);

      final width = log2Ceil(radix) + 1;
      final inputXor = Logic(width: width);
      final multiples = <Logic>[];
      for (var i = 2; i < radix + 1; i += 2) {
        final pastX = LogicValue.ofInt(i - 1, width);
        final x = LogicValue.ofInt(i, width);
        final pastXor = pastX ^ (pastX >>> 1);
        final xor = x ^ (x >>> 1);
        // Multiples don't agree on a bit position so we will skip
        final multiplesDisagree = xor ^ pastXor;
        // Where multiples agree, we need the sense or direction (1 or 0)
        final senseMultiples = xor & pastXor;

        final andOutput = [
          for (var j = 0; j < width - 1; j++)
            if (multiplesDisagree[j].isZero)
              if (senseMultiples[j].isZero) ~inputXor[j] else inputXor[j]
        ].swizzle().and();
        final multPos = (i >>> 1) + i % 2;
        stdout
          ..write('\tM${(i >>> 1) + i % 2} x=${bitString(x)} '
              'lx=${bitString(pastX)} '
              // 'm=$m xor=${bitString(xor)}(${xor.toInt()}) '
              'dontcare=${bitString(multiplesDisagree)}'
              ' agree=${bitString(senseMultiples)}')
          ..write(':    ');
        for (var j = 0; j < width - 1; j++) {
          if (multiplesDisagree[j].isZero) {
            if (senseMultiples[j].isZero) {
              stdout.write('~');
            }
            stdout.write('xor[$j] ');
          }
        }
        multiples.add(andOutput);
        stdout.write('\n');
        final inLogic = Logic(width: width);
        for (var k = 0; k < radix; k++) {
          final inValue = LogicValue.ofInt(k, width);
          inLogic.put(inValue);
          final code = encoder.encode(inLogic).multiples[multPos - 1];
          final newCode =
              RadixEncoder(radix).encode(inLogic).multiples[multPos - 1];
          inputXor.put(inValue ^ (inValue >>> 1));
          stdout
            ..write('in=${bitString(inValue)} ')
            ..write('xor=${bitString(inputXor.value)} ')
            ..write('out=${bitString(andOutput.value)} ')
            ..write('code=${bitString(code.value)} ')
            ..write('ncode=${bitString(newCode.value)}')
            ..write('')
            ..write('\n');
          expect(andOutput.value, equals(code.value));
          expect(newCode.value, equals(code.value));
          expect(newCode.value, equals(andOutput.value));
        }
      }
    }
  });
}
