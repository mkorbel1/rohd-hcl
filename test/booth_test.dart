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
import 'package:test/test.dart';

// TODO(desmonddak): extend compact to radix4
// TODO(desmonddak): test compact for square radix2,4,8,16
// TODO(desmonddak): cleanup and check in
// TODO(desmonddak): combine rectangular with compact
void main() {
  test('single partial product test', () async {
    final encoder = Radix4Encoder();
    const widthX = 10; // 4/7:  64   4/10: 512
    const widthY = 10;
// 3,4 ;   4,8, 5,16  6,32  7,64 8,128  9,256  10, 512
    const i = 16;
    var j = pow(2, widthY - 1).toInt();
    // j = 128; // r=16,N=8
    j = 16; // r=16,N=9?
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
  test('exhaustive partial product evaluate test', () async {
    final encoder = Radix8Encoder();
    for (var width = 4; width < 5; width++) {
      final widthX = width;
      final widthY = width;
      final logicX = Logic(name: 'X', width: widthX);
      final logicY = Logic(name: 'Y', width: widthY);
      final pp = PartialProductGenerator(logicX, logicY, encoder);
      // ignore: cascade_invocations
      pp
        // ..bruteForceSignExtend()
        // .signExtendWithStopBits();
        // .signExtendWithStopBitsRect();
        ..signExtendCompact();

      final limitX = pow(2, widthX);
      final limitY = pow(2, widthY);
      for (var i = 0; i < limitX; i++) {
        for (var j = 0; j < limitY; j++) {
          final X = BigInt.from(i).toSigned(widthX);
          final Y = BigInt.from(j).toSigned(widthY);
          final product = X * Y;

          logicX.put(X);
          logicY.put(Y);
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
  });

  /// This slower test elaborates the multiplier each time, but any output
  ///  during each elaboration will have valid logic values which can provide
  /// valuable debug information.
  test('slow exhaustive partial product evaluate test', () async {
    final encoder = Radix16Encoder();
    for (var width = 7; width < 8; width++) {
      final widthX = width;
      final widthY = width + 16;
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
          pp
            // ..bruteForceSignExtend()
            // .signExtendWithStopBits();
            // ..signExtendWithStopBitsRect();
            ..signExtendCompact();
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
  test('radix16 extract', () async {
    for (var i = 0; i < pow(2, 5); i++) {
      final m = (i < 16 ? 1 : -1) *
          ((i < 16 ? 0 : 16) + ((i / 2).ceil() % 16) * (i < 16 ? 1 : -1));
      final x = LogicValue.ofInt(i, 5);
      final xor = x ^ (x >>> 1);
      //             1        0       0      0
      final m8 = xor[3] & ~xor[2] & ~xor[1] & ~xor[0]; // 8M
      //             1       0       -      1
      final m7 = xor[3] & ~xor[2] & xor[0]; // 7M
      //             1       -       1       0
      final m6 = xor[3] & xor[1] & ~xor[0]; // 6M
      //             1       1       -       1
      final m5 = xor[3] & xor[2] & xor[0]; // 5M
      //             -       1       0       0
      final m4 = xor[2] & ~xor[1] & ~xor[0]; // 4M
      //              0       1      -       1
      final m3 = ~xor[3] & xor[2] & xor[0]; // 3M
      //             0       -       1      0
      final m2 = ~xor[3] & xor[1] & ~xor[0]; // 2M
      //             0       0      -     1
      final m1 = ~xor[3] & ~xor[2] & xor[0]; // M

      // Let's try to predict:
      // final myM = i &&
      stdout.write('$i: ${(i >>> 1) + i % 2} x=${bitString(x)} '
          'm=$m xor=${bitString(xor)}(${xor.toInt()}) '
          '$m1 $m2 $m3 $m4 $m5 $m6 $m7 $m8\n');
    }
  });
}
// TODO(desmonddak): Generalize radix recoding using xor equations
// TODO(desmonddak): Calculate the folding method for sign extension
//    using m() and q() vectors
// TODO(desmonddak): Create the PP->PP logic change for sign extension
//     rather than modifying in-situ:   PP function (PP);
