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

import 'dart:math';
import 'package:rohd_hcl/src/floating_point.dart';
import 'package:rohd_hcl/src/floating_point_value.dart';
import 'package:test/test.dart';

void main() {
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
    print('${out}'
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

    print('${fp1.floatingPointValue.toString()}'
        ' ${fp1.floatingPointValue.toDouble()}');
    print('${fp2.floatingPointValue.toString()}'
        ' ${fp2.floatingPointValue.toDouble()}');

    final adder = FloatingPointAdder(fp1, fp2);
    print('${out}'
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

    print('${fp1.floatingPointValue.toString()}'
        ' ${fp1.floatingPointValue.toDouble()}');
    print('${fp2.floatingPointValue.toString()}'
        ' ${fp2.floatingPointValue.toDouble()}');

    final adder = FloatingPointAdder(fp1, fp2);
    print('${out}'
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
      print('${out}'
          ' ${out.toDouble()} expected ');
      print('${adder.out.floatingPointValue}'
          ' ${adder.out.floatingPointValue.toDouble()} computed ');
      final fpSuper = adder.out.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });

// if you name two tests the same they get run together
// RippleCarryAdder: cannot access inputs from outside -- super.a issue
  test('basic loop adder test2', () {
    final input = [(4.5, 3.75), (9.0, -3.75), (-9.0, 3.9375), (-3.9375, 9.0)];

    for (final pair in input) {
      final fp1 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$1).value);
      final fp2 = FloatingPoint32()
        ..put(FloatingPoint32Value.fromDouble(pair.$2).value);
      final out = FloatingPoint32Value.fromDouble(pair.$1 + pair.$2);
      print('Adding ${fp1.floatingPointValue.toDouble()}'
          ' and ${fp2.floatingPointValue.toDouble()}:');
      print('${fp1.floatingPointValue}'
          ' ${fp1.floatingPointValue.toDouble()}');
      print('${fp2.floatingPointValue}'
          ' ${fp2.floatingPointValue.toDouble()}');

      final adder = FloatingPointAdder(fp1, fp2);
      print('${out}'
          ' ${out.toDouble()} expected ');
      print('${adder.out.floatingPointValue}'
          ' ${adder.out.floatingPointValue.toDouble()} computed ');

      final fpSuper = adder.out.floatingPointValue;
      final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
      final valStr = out.toDouble().toStringAsPrecision(7);
      expect(fpStr, valStr);
    }
  });
}
