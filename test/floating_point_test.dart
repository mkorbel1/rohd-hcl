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

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:rohd_hcl/src/arithmetic/floating_point.dart';
import 'package:rohd_hcl/src/arithmetic/floating_point_value.dart';
import 'package:rohd_hcl/src/parallel_prefix_operations.dart';
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

    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);
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
    final val = FloatingPoint32Value.getFloatingPointConstant(
            FloatingPointConstants.smallestPositiveSubnormal)
        .toDouble();
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal)
          .value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal)
          .negate()
          .value);
    final out = FloatingPoint32Value.fromDouble(val - val);

    print('Adding ${fp1.floatingPointValue.toDouble()}'
        ' to ${fp2.floatingPointValue.toDouble()}');

    print('${fp1.floatingPointValue}'
        ' ${fp1.floatingPointValue.toDouble()}');
    print('${fp2.floatingPointValue}'
        ' ${fp2.floatingPointValue.toDouble()}');

    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);
    print('$out'
        ' ${out.toDouble()} expected ');
    print('${adder.out.floatingPointValue}'
        ' ${adder.out.floatingPointValue.toDouble()} computed ');
    final fpSuper = adder.out.floatingPointValue;
    final fpStr = fpSuper.toDouble().abs().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('carry numbers adder test', () {
    final val = pow(2.5, -12).toDouble();
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.5, -12).toDouble()).value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(pow(2.5, -12).toDouble()).value);
    final out = FloatingPoint32Value.fromDouble(val + val);

    print('Adding ${fp1.floatingPointValue.toDouble()}'
        ' to ${fp2.floatingPointValue.toDouble()}');

    print('${fp1.floatingPointValue}'
        ' ${fp1.floatingPointValue.toDouble()}');
    print('${fp2.floatingPointValue}'
        ' ${fp2.floatingPointValue.toDouble()}');

    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);
    print('$out'
        ' ${out.toDouble()} expected ');
    print('${adder.out.floatingPointValue}'
        ' ${adder.out.floatingPointValue.toDouble()} computed ');

    final fpSuper = adder.out.floatingPointValue;
    final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
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

      final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);
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

// if you name two tests the same they get run together
// RippleCarryAdder: cannot access inputs from outside -- super.a issue
  test('basic loop adder test - negative numbers', () {
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

      final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);
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

  test('basic subnormal test', () {
    final fp1 = FloatingPoint32()
      ..put(FloatingPoint32Value.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveNormal)
          .value);
    final fp2 = FloatingPoint32()
      ..put(FloatingPoint32Value.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal)
          .negate()
          .value);
    print('adding');
    print('${fp1.floatingPointValue}');
    print('${fp2.floatingPointValue}');
    final out = FloatingPoint32Value.fromDouble(
        fp1.floatingPointValue.toDouble() + fp2.floatingPointValue.toDouble());
    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);
    print('$out'
        ' ${out.toDouble()} expected ');
    print('${adder.out.floatingPointValue}'
        ' ${adder.out.floatingPointValue.toDouble()} computed ');
    final fpSuper = adder.out.floatingPointValue;
    final fpStr = fpSuper.toDouble().toStringAsPrecision(7);
    final valStr = out.toDouble().toStringAsPrecision(7);
    expect(fpStr, valStr);
  });

  test('tiny subnormal test', () {
    const ew = 4;
    const mw = 4;
    final fp1 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveNormal, ew, mw)
          .value);
    final fp2 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal, ew, mw)
          .negate()
          .value);
    print('adding');
    print('\t${fp1.floatingPointValue} ${fp1.floatingPointValue.toDouble()}');
    print('\t${fp2.floatingPointValue} ${fp2.floatingPointValue.toDouble()}');
    final outDouble =
        fp1.floatingPointValue.toDouble() + fp2.floatingPointValue.toDouble();
    print('\t Computed separately $outDouble');
    final out = FloatingPointValue.fromDouble(outDouble,
        exponentWidth: ew, mantissaWidth: mw);
    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);
    print('$out'
        ' ${out.toDouble()} expected ');
    print('${adder.out.floatingPointValue}'
        ' ${adder.out.floatingPointValue.toDouble()} computed ');
    if (adder.out.floatingPointValue == out) {
      print('match');
    }
    expect(adder.out.floatingPointValue.compareTo(out), 0);
  });

  test('negative number requiring a carryOut', () {
    const pair = (9.0, -3.75);
    const ew = 3;
    const mw = 5;

    final fp1 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.fromDouble(pair.$1,
              exponentWidth: ew, mantissaWidth: mw)
          .value);
    final fp2 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.fromDouble(pair.$2,
              exponentWidth: ew, mantissaWidth: mw)
          .value);
    print('adding');
    print('\t${fp1.floatingPointValue} ${fp1.floatingPointValue.toDouble()}');
    print('\t${fp2.floatingPointValue} ${fp2.floatingPointValue.toDouble()}');
    final out = FloatingPointValue.fromDouble(pair.$1 + pair.$2,
        exponentWidth: ew, mantissaWidth: mw);
    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);
    print('$out'
        ' ${out.toDouble()} expected from ${pair.$1 + pair.$2}');
    print('${adder.out.floatingPointValue}'
        ' ${adder.out.floatingPointValue.toDouble()} computed ');
    expect(adder.out.floatingPointValue.compareTo(out), 0);
  });

  test('subnormal cancellation', () {
    const ew = 4;
    const mw = 4;
    final fp1 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal, ew, mw)
          .negate()
          .value);
    final fp2 = FloatingPoint(exponentWidth: ew, mantissaWidth: mw)
      ..put(FloatingPointValue.getFloatingPointConstant(
              FloatingPointConstants.smallestPositiveSubnormal, ew, mw)
          .value);
    print('adding');
    print('\t${fp1.floatingPointValue} ${fp1.floatingPointValue.toDouble()}');
    print('\t${fp2.floatingPointValue} ${fp2.floatingPointValue.toDouble()}');
    final out = fp2.floatingPointValue + fp1.floatingPointValue;

    final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);
    print('$out'
        ' ${out.toDouble()} expected ');
    print('${adder.out.floatingPointValue}'
        ' ${adder.out.floatingPointValue.toDouble()} computed ');
    // expect(adder.out.floatingPointValue.compareTo(out), 0);
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

      final adder = FloatingPointAdder(fp1, fp2, KoggeStone.new);
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

  group('multiplication', () {
    test('exhaustive zero exponent', () {
      const radix = 4;

      final fp1 = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
      final fv1 = FloatingPointValue.ofStrings('0', '0110', '0000');
      final fp2 = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
      final fv2 = FloatingPointValue.ofStrings('0', '0110', '0000');
      fp1.put(fv1.value);
      fp2.put(fv2.value);
      final multiply = FloatingPointMultiplier(fp1, fp2, radix, KoggeStone.new);
      final fpOut = multiply.out;

      const widthX = 4;
      const widthY = 4;
      // return;
      final limitX = pow(2, widthX);
      final limitY = pow(2, widthY);
      for (var j = 0; j < limitY; j++) {
        for (var i = 0; i < limitX; i++) {
          final X = BigInt.from(i).toUnsigned(widthX);
          final Y = BigInt.from(j).toUnsigned(widthY);
          final strX = X.toRadixString(2).padLeft(widthX, '0');
          final strY = Y.toRadixString(2).padLeft(widthY, '0');
          final fv1 = FloatingPointValue.ofStrings('0', '0111', strX);
          final fv2 = FloatingPointValue.ofStrings('0', '0111', strY);

          final doubleProduct = fv1.toDouble() * fv2.toDouble();
          final partway = FloatingPointValue.fromDouble(doubleProduct,
              exponentWidth: widthX, mantissaWidth: widthY);
          final roundTrip = partway.toDouble();

          fp1.put(fv1.value);
          fp2.put(fv2.value);
          // final multiply =
          //     FloatingPointMultiplier(fp1, fp2, radix, KoggeStone.new);
          // final fpOut = multiply.out;

          assert(
              fpOut.floatingPointValue.toDouble() == roundTrip,
              'multiply $fv1($X)*$fv2($Y)='
              '${fpOut.floatingPointValue}'
              '(${fpOut.floatingPointValue.toDouble()}) mismatch '
              ' $roundTrip-->$partway\n');
        }
      }
    });

    // TODO(desmonddak): This is a failing case for overflow we need
    // to generalize and handle all cases
    // uncomment the fv1 below to expose the failure
    test('single example', () {
      const radix = 4;

      const expWidth = 4;
      const mantWidth = 4;
      final fp1 =
          FloatingPoint(exponentWidth: expWidth, mantissaWidth: mantWidth);
      // final fv1 = FloatingPointValue.ofStrings('0', '1111', '1111');
      final fv1 = FloatingPointValue.ofStrings('0', '1110', '1111');
      final fp2 = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
      final fv2 = FloatingPointValue.ofStrings('0', '0111', '0001');
      fp1.put(fv1.value);
      fp2.put(fv2.value);

      final multiply = FloatingPointMultiplier(fp1, fp2, radix, KoggeStone.new);
      final fpOut = multiply.out;

      final doubleProduct = fv1.toDouble() * fv2.toDouble();
      final partWay = FloatingPointValue.fromDouble(doubleProduct,
          exponentWidth: 4, mantissaWidth: 4);
      final roundTrip = partWay.toDouble();

      fp1.put(fv1.value);
      fp2.put(fv2.value);

      stdout.write('$fv1(${fv1.toDouble()}) * $fv2(${fv2.toDouble()})\n');

      assert(
          (fpOut.floatingPointValue.isNaN() && roundTrip.isNaN) |
              (fpOut.floatingPointValue.toDouble() == roundTrip),
          'multiply result ${fpOut.floatingPointValue}'
          '(${fpOut.floatingPointValue.toDouble()}) mismatch '
          ' $partWay($roundTrip)\n');
    });

    test('normals', () {
      const radix = 4;

      const expWidth = 4;
      const mantWidth = 4;
      final fp1 =
          FloatingPoint(exponentWidth: expWidth, mantissaWidth: mantWidth);
      final fv1 = FloatingPointValue.ofStrings('0', '0110', '0000');
      final fp2 = FloatingPoint(exponentWidth: 4, mantissaWidth: 4);
      final fv2 = FloatingPointValue.ofStrings('0', '0110', '0000');
      fp1.put(fv1.value);
      fp2.put(fv2.value);

      const widthX = mantWidth;
      const widthY = mantWidth;
      final expLimit = pow(2, expWidth);
      final limitX = pow(2, widthX);
      final limitY = pow(2, widthY);
      // TODO(desmonddak): Push to the exponent limit: implement
      //   Infinity and NaN properly in both floating_point_value
      //   and the operations
      for (var k = 1; k < expLimit - 1; k++) {
        stdout.write('k=$k\n');
        for (var j = 0; j < limitY; j++) {
          for (var i = 0; i < limitX; i++) {
            final E = BigInt.from(k).toUnsigned(expWidth);
            final X = BigInt.from(i).toUnsigned(widthX);
            final Y = BigInt.from(j).toUnsigned(widthY);
            var expStr = E.toRadixString(2).padLeft(expWidth, '0');
            // expStr = '0110';  this will pass, but all else fails
            final strX = X.toRadixString(2).padLeft(widthX, '0');
            final strY = Y.toRadixString(2).padLeft(widthY, '0');
            final fv1 = FloatingPointValue.ofStrings('0', expStr, strX);
            // This will force it to be normal
            final fv2 = FloatingPointValue.ofStrings('0', '0111', strY);

            final multiply =
                FloatingPointMultiplier(fp1, fp2, radix, KoggeStone.new);
            final fpOut = multiply.out;
            final doubleProduct = fv1.toDouble() * fv2.toDouble();
            final roundTrip = FloatingPointValue.fromDouble(doubleProduct,
                    exponentWidth: 4, mantissaWidth: 4)
                .toDouble();

            fp1.put(fv1.value);
            fp2.put(fv2.value);

            // stdout
            //   ..write('testing e= $E')
            //   ..write('a=$fv1 ')
            //   ..write('b=$fv2 ')
            //   ..write('expect=$roundTrip ')
            //   ..write('result=${fpOut.floatingPointValue.toDouble()}')
            //   ..write('${fpOut.floatingPointValue.toDouble() == roundTrip}\n');

            assert(
                (fpOut.floatingPointValue.isNaN() && roundTrip.isNaN) |
                    (fpOut.floatingPointValue.toDouble() == roundTrip),
                'multiply result ${fpOut.floatingPointValue.toDouble()} mismatch '
                ' $roundTrip\n'
                'a=$fv1\n'
                'b=$fv2\n');
          }
        }
      }
    });
  });
}

  // TODO(desmonddak):  we need floating point comparison tests
