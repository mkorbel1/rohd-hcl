// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point.dart
// Implementation of Floating Point stuff
//
// 2023 July 11
// Author:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com
//
import 'dart:math';

import 'package:rohd/rohd.dart';

/// Flexible floating point representation
class FloatingPoint extends LogicStructure {
  /// unsigned, biased binary [exponent] -- see [_bias]
  final Logic exponent;

  /// unsigned binary [mantissa]
  final Logic mantissa;

  /// [sign] bit with '1' representing a negative number
  final Logic sign;

  /// [FloatingPoint] Constructor for a variable size binary
  /// floating point number
  FloatingPoint({required int exponentWidth, required int mantissaWidth})
      : this._(
            Logic(name: 'sign'),
            Logic(width: exponentWidth, name: 'exponent'),
            Logic(width: mantissaWidth, name: 'mantissa'));

  FloatingPoint._(this.sign, this.exponent, this.mantissa, {String? name})
      : super([mantissa, exponent, sign], name: name ?? 'FloatingPoint');

  @override
  FloatingPoint clone({String? name}) => FloatingPoint(
        exponentWidth: exponent.width,
        mantissaWidth: mantissa.width,
      );

  /// Return the exponent value representing the true zero exponent 2^0 = 1
  ///   often termed [_bias] or the offset of the exponent
  int _bias() => pow(2, exponent.width - 1).toInt() - 1;

  /// Return the minimum exponent value
  int _eMin() => -pow(2, exponent.width - 1).toInt() + 2;

  /// Return the maximum exponent value
  int _eMax() => _bias();

  /// Return the value of the floating point number in a Dart double type
  double toDouble() {
    var doubleVal = double.nan;
    if (value.isValid) {
      if (exponent.value.toInt() == 0) {
        print('SubNormal');
        doubleVal = (sign.value.toBool() ? -1.0 : 1.0) *
            pow(2, _eMin()) *
            mantissa.value.toBigInt().toDouble() /
            pow(2, mantissa.width);
      } else if (exponent.value.toInt() != _eMax() + _bias() + 1) {
        doubleVal = (sign.value.toBool() ? -1.0 : 1.0) *
            (1.0 +
                mantissa.value.toBigInt().toDouble() / pow(2, mantissa.width)) *
            pow(2, exponent.value.toInt() - _bias());
      }
    }
    return doubleVal;
  }

  /// Convert a floating point number into a [FloatingPoint] representation
  void fromDouble(double inDouble) {
    print('Input: $inDouble');
    var doubleVal = inDouble;
    if (inDouble < 0.0) {
      doubleVal = -doubleVal;
      sign.put(LogicValue.one);
    } else {
      sign.put(LogicValue.zero);
    }
    // If we are dealing with a really small number we need to scale it up
    final scaleForSmall = (-log(doubleVal) / log(2)).ceil();
    var delta = scaleForSmall;
    var scale = mantissa.width + delta;

    final scaledValue = BigInt.from(doubleVal * pow(2.0, scale));
    print('$scaledValue scaledValue of $inDouble');
    final fullLength = scaledValue.bitLength;
    var fullValue = LogicValue.ofBigInt(scaledValue, fullLength);
    print('${fullValue.toString(includeWidth: false)} fullValue');

    var e = fullLength - mantissa.width - delta;

    if (e <= -127) {
      print('Warning: this number will be subnormal ${-e - 127}');
      final x = -(e + 127);
      fullValue = fullValue >>> x;
      e = -127;
    } else {
      e -= 1;
      fullValue = fullValue << 1; // Chop the first '1'
      print('${fullValue.toString(includeWidth: false)} fullValue chopped');
    }
    fullValue = fullValue.reversed;
    var mantissaVal = LogicValue.ofBigInt(fullValue.toBigInt(), mantissa.width);
    mantissaVal = mantissaVal.reversed;
    final exponentVal = LogicValue.ofInt(e + _bias(), exponent.width);
    print('${exponentVal.toString(includeWidth: false)} '
        '${mantissaVal.toString(includeWidth: false)} Full Floating Point Rep');
    mantissa.put(mantissaVal);
    exponent.put(exponentVal);
  }
}

/// Double floating point representation
class FloatingPoint64 extends FloatingPoint {
  /// Construct a 64-bit (double-precision) floating point number
  FloatingPoint64() : super(exponentWidth: 11, mantissaWidth: 52);
}

/// Single floating point representation
class FloatingPoint32 extends FloatingPoint {
  /// Construct a 32-bit (single-precision) floating point number
  FloatingPoint32() : super(exponentWidth: 8, mantissaWidth: 23);
}

void main() {
// Going through examples on Wikipedia
  // final values = [0.15625, 12.375, 1.0, 0.25, 0.375];
  const smallestPositiveSubnormal = 1.4012984643e-45;
  const largestPositiveSubnormal = 1.1754942107e-38;
  const smallestPositiveNormal = 1.1754943508e-38;
  final values = [
    smallestPositiveNormal,
    largestPositiveSubnormal,
    smallestPositiveSubnormal
  ];
  for (final val in values) {
    final fp = FloatingPoint32();
    fp.fromDouble(val);
    print('Converted $val to ${fp.toDouble()}');
    // assert(val == fp.toDouble(), 'mismatch');
  }
  return;
  for (var i = 0; i < 63; i++) {
    final x = pow(2.0, i).toDouble();
    final fp = FloatingPoint32();
    fp.fromDouble(x);
    print("converted $x to ${fp.toDouble()}");
  }
}
