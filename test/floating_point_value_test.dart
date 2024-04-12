// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_test.dart
// Tests of Floating Point stuff
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com
//

// ignore_for_file: avoid_print, unnecessary_parenthesis

import 'dart:math';
import 'package:rohd_hcl/src/floating_point.dart';
import 'package:rohd_hcl/src/floating_point_value.dart';
import 'package:test/test.dart';

void main() {
  test('FloatingPointValue string conversions', () {
    const str = '0 10000001 01000100000000000000000'; // 5.0625
    final fp = FloatingPoint32Value.ofString(str);
    expect(fp.toString(), str);
    expect(fp.toDouble(), 5.0625);
  });
  test('simple 32', () {
    final values = [0.15625, 12.375, -1.0, 0.25, 0.375];
    for (final val in values) {
      final fp = FloatingPoint32Value.fromDouble(val);
      assert(val == fp.toDouble(), 'mismatch');
      expect(fp.toDouble(), val);
      final fpSuper = FloatingPointValue.fromDouble(val,
          exponentWidth: 8, mantissaWidth: 23);
      assert(val == fpSuper.toDouble(), 'mismatch');
      expect(fpSuper.toDouble(), val);
    }
  });

  test('simple 64', () {
    final values = [0.15625, 12.375, -1.0, 0.25, 0.375];
    for (final val in values) {
      final fp = FloatingPoint64Value.fromDouble(val);
      assert(val == fp.toDouble(), 'mismatch');
      expect(fp.toDouble(), val);
      final fpSuper = FloatingPointValue.fromDouble(val,
          exponentWidth: 11, mantissaWidth: 52);
      assert(val == fpSuper.toDouble(), 'mismatch');
      expect(fpSuper.toDouble(), val);
    }
  });

  test('corner 32', () {
    final x = FloatingPoint32Value.getFloatingPointConstant(
        FloatingPointConstants.smallestPositiveSubnormal);
    print((x + x));
    const smallestPositiveSubnormal = 1.4012984643e-45; // now this one fails
    const smallestPositiveNormal = 1.1754943508e-38;
    const largestPositiveSubnormal = 1.1754942107e-38;
    const largestNormalNumber = 3.4028234664e38;
    const largestNumberLessThanOne = 0.999999940395355225;
    const smallestNumberLargerThanOne = 1.00000011920928955;
    const oneThird = 0.333333343267440796;
    final values = [
      smallestPositiveNormal,
      largestPositiveSubnormal,
      smallestPositiveSubnormal,
      largestNormalNumber,
      largestNumberLessThanOne,
      smallestNumberLargerThanOne,
      oneThird
    ];
    for (final val in values) {
      final fp = FloatingPoint32Value.fromDouble(val);
      var fpStr = fp.toDouble().toStringAsPrecision(11);
      var valStr = val.toStringAsPrecision(11);
      expect(fpStr, valStr);
      final fpSuper = FloatingPointValue.fromDouble(val,
          exponentWidth: 8, mantissaWidth: 23);
      fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      valStr = val.toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });

  test('corner 64', () {
    const smallestPositiveNormal = 2.2250738585072014e-308;
    const largestPositiveSubnormal = 2.2250738585072009e-308;
    const smallestPositiveSubnormal = 4.9406564584124654e-324;
    const largestNormalNumber = 1.7976931348623157e308;
    const largestNumberLessThanOne = 0.999999940395355225;
    const smallestNumberLargerThanOne = 1.0000000000000002;
    const oneThird = 0.33333333333333333;
    final values = [
      smallestPositiveSubnormal,
      smallestPositiveNormal,
      largestPositiveSubnormal,
      largestNormalNumber,
      largestNumberLessThanOne,
      smallestNumberLargerThanOne,
      oneThird
    ];
    for (final val in values) {
      final fp = FloatingPoint64Value.fromDouble(val);
      var fpStr = fp.toDouble().toStringAsPrecision(17);
      var valStr = val.toStringAsPrecision(17);
      expect(fpStr, valStr);
      final fpSuper = FloatingPointValue.fromDouble(val,
          exponentWidth: 11, mantissaWidth: 52);
      fpStr = fpSuper.toDouble().toStringAsPrecision(15);
      valStr = val.toStringAsPrecision(15);
      expect(fpStr, valStr);
    }
  });

  test('putting values onto a signal', () {
    final fp = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.5).value);
    expect(fp.floatingPointValue.toDouble(), 1.5);
  });

  test('basic adder test', () {
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(3.25).value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.5).value);
    final out = FloatingPoint32Value.fromDouble(3.25 + 1.5);

    print('Adding ${fp1.floatingPointValue.toDouble()}'
        ' to ${fp2.floatingPointValue.toDouble()}');

    print('${fp1.floatingPointValue}'
        ' ${fp1.floatingPointValue.toDouble()}');
    print('${fp2.floatingPointValue}'
        ' ${fp2.floatingPointValue.toDouble()}');

    final adder = FloatingPointAdder(fp1, fp2);
    print('$out'
        ' ${out.toDouble()} expected ');
    print('${adder.out.floatingPointValue}'
        ' ${adder.out.floatingPointValue.toDouble()} computed ');
    final fpSuper = adder.out.floatingPointValue;
    final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('small numbers adder test', () {
    final val = pow(2.0, -23).toDouble();
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.0, -23).toDouble()).value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.0, -23).toDouble()).value);
    final out = FloatingPoint32Value.fromDouble(val + val);

    print('Adding ${fp1.floatingPointValue.toDouble()}'
        ' to ${fp2.floatingPointValue.toDouble()}');

    print('${fp1.floatingPointValue}'
        ' ${fp1.floatingPointValue.toDouble()}');
    print('${fp2.floatingPointValue}'
        ' ${fp2.floatingPointValue.toDouble()}');

    final adder = FloatingPointAdder(fp1, fp2);
    print('$out'
        ' ${out.toDouble()} expected ');
    print('${adder.out.floatingPointValue}'
        ' ${adder.out.floatingPointValue.toDouble()} computed ');
    final fpSuper = adder.out.floatingPointValue;
    final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('carry numbers adder test', () {
    final val = pow(2.5, -12).toDouble();
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.5, -12).toDouble()).value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.0, -12).toDouble()).value);
    final out = FloatingPoint32Value.fromDouble(val + val);

    print('Adding ${fp1.floatingPointValue.toDouble()}'
        ' to ${fp2.floatingPointValue.toDouble()}');

    print('${fp1.floatingPointValue}'
        ' ${fp1.floatingPointValue.toDouble()}');
    print('${fp2.floatingPointValue}'
        ' ${fp2.floatingPointValue.toDouble()}');

    final adder = FloatingPointAdder(fp1, fp2);
    print('$out'
        ' ${out.toDouble()} expected ');
    print('${adder.out.floatingPointValue}'
        ' ${adder.out.floatingPointValue.toDouble()} computed ');

    // final fpSuper = adder.out.floatingPointValue;
    // final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
    // final valStr = out.toDouble().toStringAsPrecision(7);
    // expect(fpStr, valStr);
  });

  test('basic loop adder test', () {
    final input = [(3.25, 1.5), (4.5, 3.75)];

    for (final pair in input) {
      final fp1 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$1).value);
      final fp2 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$2).value);
      final out = FloatingPoint32Value.fromDouble(pair.$1 + pair.$2);

      print('Adding ${fp1.floatingPointValue.toDouble()}'
          ' to ${fp2.floatingPointValue.toDouble()}');

      print('${fp1.floatingPointValue}'
          ' ${fp1.floatingPointValue.toDouble()}');
      print('${fp2.floatingPointValue}'
          ' ${fp2.floatingPointValue.toDouble()}');

      final adder = FloatingPointAdder(fp1, fp2);
      print('$out'
          ' ${out.toDouble()} expected ');
      print('${adder.out.floatingPointValue}'
          ' ${adder.out.floatingPointValue.toDouble()} computed ');
      final fpSuper = adder.out.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });

  test('FloatingPointValue string conversions', () {
    const str = '0 10000001 01000100000000000000000'; // 5.0625
    final fp = FloatingPointValue.ofString(str);
    expect(fp.toString(), str);
    expect(fp.toDouble(), 5.0625);
  });
}
