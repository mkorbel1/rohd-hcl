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
        doubleVal = (sign.value.toBool() ? -1.0 : 1.0) *
            pow(2, _eMin()) *
            mantissa.value.toInt().toDouble() /
            pow(2, mantissa.width - 1);
      } else if (exponent.value.toInt() != _eMax() + _bias() + 1) {
        doubleVal = (sign.value.toBool() ? -1.0 : 1.0) *
            (1.0 + mantissa.value.toInt().toDouble() / pow(2, mantissa.width)) *
            pow(2, exponent.value.toInt() - _bias());
      }
    }
    return doubleVal;
  }

  /// Convert a floating point number into a [FloatingPoint] representation
  void fromDouble(double inDouble) {
    var doubleVal = inDouble;
    if (inDouble < 0.0) {
      doubleVal = -doubleVal;
      sign.put(LogicValue.one);
    } else {
      sign.put(LogicValue.zero);
    }
    final scaledValue = BigInt.from(doubleVal * pow(2, mantissa.width - 1));
    final binaryRepresentation = scaledValue.toRadixString(2);

    final e = binaryRepresentation.length - mantissa.width;

    // TODO(desmonddak): will this work for very large floats.
    var fractionVal = doubleVal - doubleVal.toInt();

    var mantissaVal = LogicValue.ofInt(0, mantissa.width);
    for (var i = mantissa.width - 1; i > 0; --i) {
      fractionVal *= 2.0;
      final bitVal = fractionVal.toInt();
      if (bitVal != 0) {
        mantissaVal = mantissaVal | LogicValue.ofInt(1 << i, mantissa.width);
      }
      fractionVal -= bitVal;
    }
    // TODO(desmonddak): When to chop the first bit, we do it on both parts.
    if (e > 0) {
      mantissaVal = mantissaVal >> e;
    } else {
      mantissaVal = mantissaVal << -e;
    }
    final wholeVal = (doubleVal - fractionVal).toInt();
    final l = wholeVal.toRadixString(2).length;
    // This chops off the leading bit
    var wholeBinary =
        LogicValue.ofInt(wholeVal << mantissa.width - l + 1, mantissa.width);
    final mergedMantissa = wholeBinary | mantissaVal;
    final exponentVal = LogicValue.ofInt(e + _bias(), exponent.width);
    mantissa.put(mergedMantissa);
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
  final values = [12.375, 1.0, 0.25, 0.375];
  for (final val in values) {
    final fp = FloatingPoint32();
    fp.fromDouble(val);
    print('Converted $val to ${fp.toDouble()}');
  }
}
