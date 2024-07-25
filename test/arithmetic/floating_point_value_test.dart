// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_test.dart
// Tests of Floating Point value stuff
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com
//

// ignore_for_file: avoid_print, unnecessary_parenthesis

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/arithmetic/booth.dart';
import 'package:rohd_hcl/src/arithmetic/floating_point.dart';
import 'package:rohd_hcl/src/arithmetic/floating_point_value.dart';
import 'package:test/test.dart';

void main() {
  test('exhaustive round-trip', () {
    const signStr = '0';
    const exponentWidth = 4;
    const mantissaWidth = 4;
    var exponent = LogicValue.zero.zeroExtend(exponentWidth);
    var mantissa = LogicValue.zero.zeroExtend(mantissaWidth);
    for (var k = 0; k < pow(2.0, exponentWidth).toInt(); k++) {
      final expStr = bitString(exponent);
      for (var i = 0; i < pow(2.0, mantissaWidth).toInt(); i++) {
        final mantStr = bitString(mantissa);
        final fp = FloatingPointValue.ofStrings(signStr, expStr, mantStr);
        final dbl = fp.toDouble();
        final fp2 = FloatingPointValue.fromDouble(dbl,
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        if (fp != fp2) {
          if (fp.isNaN() != fp2.isNaN()) {
            print('$fp $fp2,  ${fp.toDouble()}  ${fp2.toDouble()}');
            expect(fp, equals(fp2));
          }
        }
        mantissa = mantissa + 1;
      }
      exponent = exponent + 1;
    }
  });
  test('direct subnormal conversion', () {
    const signStr = '0';
    for (final (exponentWidth, mantissaWidth) in [(8, 23), (11, 52)]) {
      final expStr = '0' * exponentWidth;
      final mantissa = LogicValue.one.zeroExtend(mantissaWidth);
      for (var i = 0; i < mantissaWidth; i++) {
        final mantStr = bitString(mantissa << i);
        final fp = FloatingPointValue.ofStrings(signStr, expStr, mantStr);
        expect(fp.toString(), '$signStr $expStr $mantStr');
        final fp2 = FloatingPointValue.fromDouble(fp.toDouble(),
            exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
        expect(fp2, equals(fp));
      }
    }
  });
  test('indirect subnormal conversion', () {
    const signStr = '0';
    for (var exponentWidth = 2; exponentWidth < 12; exponentWidth++) {
      for (var mantissaWidth = 2; mantissaWidth < 53; mantissaWidth++) {
        final expStr = '0' * exponentWidth;
        final mantissa = LogicValue.one.zeroExtend(mantissaWidth);
        for (var i = 0; i < mantissaWidth; i++) {
          final mantStr = bitString(mantissa << i);
          final fp = FloatingPointValue.ofStrings(signStr, expStr, mantStr);
          expect(fp.toString(), '$signStr $expStr $mantStr');
          final fp2 = FloatingPointValue.fromDouble(fp.toDouble(),
              exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);
          expect(fp2, equals(fp));
        }
      }
    }
  });
  test('round trip 32', () {
    final values = [
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.largestPositiveSubnormal),
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.smallestPositiveSubnormal),
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.smallestPositiveNormal),
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.largestLessThanOne),
      FloatingPoint32Value.getFloatingPointConstant(FloatingPointConstants.one),
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.smallestLargerThanOne),
      FloatingPoint32Value.getFloatingPointConstant(
          FloatingPointConstants.largestNormal)
    ];
    for (final fp in values) {
      final fp2 = FloatingPoint32Value.fromDouble(fp.toDouble());
      expect(fp2, equals(fp));
    }
  });
  test('round trip 64', () {
    final values = [
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.largestPositiveSubnormal),
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.smallestPositiveSubnormal),
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.smallestPositiveNormal),
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.largestLessThanOne),
      FloatingPoint64Value.getFloatingPointConstant(FloatingPointConstants.one),
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.smallestLargerThanOne),
      FloatingPoint64Value.getFloatingPointConstant(
          FloatingPointConstants.largestNormal)
    ];
    for (final fp in values) {
      final fp2 = FloatingPoint64Value.fromDouble(fp.toDouble());
      expect(fp2, equals(fp));
    }
  });
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

  test('setting and getting from a signal', () {
    final fp = FloatingPoint32()
      ..put(FloatingPoint32Value.fromDouble(1.5).value);
    expect(fp.floatingPointValue.toDouble(), 1.5);
    final fp2 = FloatingPoint64()
      ..put(FloatingPoint64Value.fromDouble(1.5).value);
    expect(fp2.floatingPointValue.toDouble(), 1.5);
  });
}
