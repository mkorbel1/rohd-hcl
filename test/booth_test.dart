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

void main() {
  test('single partial product test', () async {
    final encoder = Radix16Encoder();
    const widthX = 5;
    const widthY = 5;

    const i = 0;
    const j = 8;
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
      ..bruteForceSignExtend()
      // ..signExtendWithStopBits()
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
    final encoder = Radix2Encoder();
    for (var width = 5; width < 6; width++) {
      final widthX = width;
      final widthY = width;
      final logicX = Logic(name: 'X', width: widthX);
      final logicY = Logic(name: 'Y', width: widthY);
      final pp = PartialProductGenerator(logicX, logicY, encoder);
      // ignore: cascade_invocations
      pp
          // ..bruteForceSignExtend();
          .signExtendWithStopBits();

      final limitX = pow(2, widthX);
      final limitY = pow(2, widthY);
      for (var j = 0; j < limitY; j++) {
        for (var i = 0; i < limitX; i++) {
          final X = BigInt.from(i).toSigned(widthX);
          final Y = BigInt.from(j).toSigned(widthY);
          final product = X * Y;

          logicX.put(X);
          logicY.put(Y);

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
