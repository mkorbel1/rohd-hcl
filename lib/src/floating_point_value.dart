// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point.dart
// Implementation of Floating Point stuff
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com
//

import 'dart:math';
import 'dart:typed_data';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/exceptions.dart';

// TODO(desmonddak): create an abstract class extending Comparable to create a
//    base floating point type and add these
// @override
// int get hashCode => _hashCode;
// int get _hashCode;

// /// Returns true iff the width and all bits of `this` are equal to [other].
// @override
// bool operator ==(Object other) {
//   if (other is! FloatingPointValue) {
//     return false;
//   }

//   if ((exponent.width != other.exponent.width) ||
//       (mantissa.width != other.mantissa.width)) {
//     return false;
//   }

//   return (sign == other.sign) &&
//       (exponent == other.exponent) &&
//       (mantissa == other.mantissa);
// }
/// A flexible representation of floating point values
class FloatingPointValue {
  /// The full floating point value bit storage
  final LogicValue value;

  /// The sign of the value:  1 means a negative value
  final LogicValue sign;

  /// The exponent of the floating point: this is biased about a midpoint for
  /// positive and negative exponents
  final LogicValue exponent;

  /// The mantissa of the floating point
  final LogicValue mantissa;

  /// Return the exponent value representing the true zero exponent 2^0 = 1
  ///   often termed [_bias] or the offset of the exponent
  static int _bias(int exponentWidth) => pow(2, exponentWidth - 1).toInt() - 1;

  /// Return the minimum exponent value
  static int _eMin(int exponentWidth) => -pow(2, exponentWidth - 1).toInt() + 2;

  /// Return the maximum exponent value
  static int _eMax(int exponentWidth) => _bias(exponentWidth);

  /// Factory (static) constructor of a [FloatingPointValue] from
  /// sign, mantissa and exponent
  factory FloatingPointValue(
      {required LogicValue sign,
      required LogicValue exponent,
      required LogicValue mantissa}) {
    if (exponent.width == FloatingPoint32Value._exponentWidth &&
        mantissa.width == FloatingPoint32Value._mantissaWidth) {
      return FloatingPoint32Value(
          sign: sign, mantissa: mantissa, exponent: exponent);
    } else if (exponent.width == FloatingPoint64Value._exponentWidth &&
        mantissa.width == FloatingPoint64Value._mantissaWidth) {
      return FloatingPoint64Value(
          sign: sign, mantissa: mantissa, exponent: exponent);
    } else {
      return FloatingPointValue._(
          sign: sign, mantissa: mantissa, exponent: exponent);
    }
  }

  /// [FloatingPointValue] constructor from string representation of
  /// individual bitfields
  factory FloatingPointValue.ofStrings(
          String sign, String exponent, String mantissa) =>
      FloatingPointValue(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPointValue] constructor from a single string representing
  /// space-separated bitfields
  factory FloatingPointValue.ofString(String fp) {
    final s = fp.split(' ');
    assert(s.length == 3, 'Wrong FloatingPointValue string length ${s.length}');
    return FloatingPointValue.ofStrings(s[0], s[1], s[2]);
  }

  FloatingPointValue._(
      {required this.sign, required this.exponent, required this.mantissa})
      : value = [sign, exponent, mantissa].swizzle() {
    if (sign.width != 1) {
      throw RohdHclException('FloatingPointValue: sign width must be 1');
    }
  }

  /// Return the [FloatingPointValue] representing the smallest positive
  /// subnormal number
  factory FloatingPointValue.smallestPositiveSubnormal(
          int exponentWidth, int mantissaWidth) =>
      FloatingPointValue.ofStrings(
          '0', '0' * exponentWidth, '${'0' * (mantissaWidth - 1)}1');

  /// Return the [FloatingPointValue] representing the largest normal number
  factory FloatingPointValue.largestSubnormal(
          int exponentWidth, int mantissaWidth) =>
      FloatingPointValue.ofStrings(
          '0', '0' * exponentWidth, '1' * mantissaWidth);

  /// Return the [FloatingPointValue] representing the smallest
  /// positive normal number
  factory FloatingPointValue.smallestPositiveNormal(
          int exponentWidth, int mantissaWidth) =>
      FloatingPointValue.ofStrings(
          '0', '${'0' * (exponentWidth - 1)}1', '0' * mantissaWidth);

  /// Return the [FloatingPointValue] representing the largest normal number
  factory FloatingPointValue.largestNormal(
          int exponentWidth, int mantissaWidth) =>
      FloatingPointValue.ofStrings(
          '0', '${'1' * (exponentWidth - 1)}0', '1' * mantissaWidth);

  /// Return the [FloatingPointValue] representing one
  factory FloatingPointValue.one(int exponentWidth, int mantissaWidth) =>
      FloatingPointValue.ofStrings(
          '0', '0${'1' * (exponentWidth - 1)}', '0' * mantissaWidth);

  /// Return the [FloatingPointValue] representing positive zero
  factory FloatingPointValue.positiveZero(
          int exponentWidth, int mantissaWidth) =>
      FloatingPointValue.ofStrings(
          '0', '0' * exponentWidth, '0' * mantissaWidth);

  /// Return the [FloatingPointValue] representing negative zero
  factory FloatingPointValue.negativeZero(
          int exponentWidth, int mantissaWidth) =>
      FloatingPointValue.ofStrings(
          '1', '0' * exponentWidth, '0' * mantissaWidth);

  /// Return the [FloatingPointValue] representing the largest number
  /// less than one
  factory FloatingPointValue.largestLessThanOne(
          int exponentWidth, int mantissaWidth) =>
      FloatingPointValue.ofStrings(
          '0', '0${'1' * (exponentWidth - 2)}0', '1' * mantissaWidth);

  /// Return the [FloatingPointValue] representing the smallest number
  /// greater than one
  factory FloatingPointValue.smallestGreaterThanOne(
          int exponentWidth, int mantissaWidth) =>
      FloatingPointValue.ofStrings(
          '0', '0${'1' * (exponentWidth - 2)}0', '${'0' * mantissaWidth}1');

  /// Return the [FloatingPointValue] representing infinity
  factory FloatingPointValue.infinity(int exponentWidth, int mantissaWidth) =>
      FloatingPointValue.ofStrings(
          '0', '1' * exponentWidth, '0' * mantissaWidth);

  /// Return the [FloatingPointValue] representing negative infinity
  factory FloatingPointValue.negativeInfinity(
          int exponentWidth, int mantissaWidth) =>
      FloatingPointValue.ofStrings(
          '1', '1' * exponentWidth, '0' * mantissaWidth);

  /// Convert a floating point number into a [FloatingPointValue]
  /// representation.
  factory FloatingPointValue.fromDouble(double inDouble,
      {required int exponentWidth, required int mantissaWidth}) {
    var doubleVal = inDouble;
    LogicValue sign;
    if (inDouble < 0.0) {
      doubleVal = -doubleVal;
      sign = LogicValue.one;
    } else {
      sign = LogicValue.zero;
    }

    // If we are dealing with a really small number we need to scale it up
    final scaleToWhole =
        (doubleVal != 0) ? (-log(doubleVal) / log(2)).floor() : 0;
    final scale = mantissaWidth + scaleToWhole;
    var s = scale;

    var sVal = doubleVal;
    if (s > 0) {
      while (s > 0) {
        sVal *= 2.0;
        s = s - 1;
      }
    } else {
      sVal = doubleVal * pow(2.0, scale);
    }

    final scaledValue = BigInt.from(sVal);
    final fullLength = scaledValue.bitLength;
    var fullValue = LogicValue.ofBigInt(scaledValue, fullLength);
    var e = (fullLength > 0)
        ? fullLength - mantissaWidth - scaleToWhole
        : FloatingPointValue._eMin(exponentWidth);

    if (e < -FloatingPointValue._bias(exponentWidth)) {
      fullValue = fullValue >>>
          (scaleToWhole - FloatingPointValue._bias(exponentWidth));
      e = -FloatingPointValue._bias(exponentWidth);
    } else {
      // Could be just one away from subnormal
      e -= 1;
      if (e > -FloatingPointValue._bias(exponentWidth)) {
        fullValue = fullValue << 1; // Chop the first '1'
      }
    }
    // We reverse so that we fit into a shorter BigInt, we keep the MSB.
    // The conversion fills leftward.
    // We reverse again after conversion.
    fullValue = fullValue.reversed;
    final exponentVal = LogicValue.ofInt(
        e + FloatingPointValue._bias(exponentWidth), exponentWidth);
    var mantissaVal = LogicValue.ofBigInt(fullValue.toBigInt(), mantissaWidth);
    mantissaVal = mantissaVal.reversed;

    final exponent = exponentVal;
    final mantissa = mantissaVal;

    return FloatingPointValue(
      exponent: exponent,
      mantissa: mantissa,
      sign: sign,
    );
  }

  // TODO(desmonddak): what about floating point representations >> 64 bits?
  // more BigInt stuff?
  /// Future compareTo function for floating point comparisons
  int compareTo(Object other) {
    if (other is! FloatingPointValue) {
      throw Exception('Input must be of type FloatingPointValue ');
    }
    if ((exponent.width != other.exponent.width) |
        (mantissa.width != other.mantissa.width)) {
      throw Exception('FloatingPointValue widths must match for comparison');
    }
    final signCompare = sign.compareTo(other.sign);
    if (signCompare != 0) {
      return signCompare;
    } else {
      final expCompare = exponent.compareTo(other.exponent);
      if (expCompare != 0) {
        return expCompare;
      } else {
        return mantissa.compareTo(other.mantissa);
      }
    }
  }

  /// Return the value of the floating point number in a Dart [double] type.
  double toDouble() {
    var doubleVal = double.nan;
    if (value.isValid) {
      if (exponent.toInt() == 0) {
        doubleVal = (sign.toBool() ? -1.0 : 1.0) *
            pow(2.0, _eMin(exponent.width)) *
            mantissa.toBigInt().toDouble() /
            pow(2.0, mantissa.width);
      } else if (exponent.toInt() !=
          _eMax(exponent.width) + _bias(exponent.width) + 1) {
        doubleVal = (sign.toBool() ? -1.0 : 1.0) *
            (1.0 + mantissa.toBigInt().toDouble() / pow(2.0, mantissa.width)) *
            pow(2.0, exponent.toInt() - _bias(exponent.width));
      }
    }
    return doubleVal;
  }

  @override
  String toString() => '${sign.toString(includeWidth: false)}'
      ' ${exponent.toString(includeWidth: false)}'
      ' ${mantissa.toString(includeWidth: false)}';

  FloatingPointValue _performOp(
      FloatingPointValue other, double Function(double a, double b) op) {
    // make sure multiplicand has the same sizes as this
    if (mantissa.width != other.mantissa.width ||
        exponent.width != other.exponent.width) {
      throw RohdHclException('FloatingPointValue: '
          'multiplicand must have the same mantissa and exponent widths');
    }

    return FloatingPointValue.fromDouble(op(toDouble(), other.toDouble()),
        mantissaWidth: mantissa.width, exponentWidth: exponent.width);
  }

  /// Multiply operation for [FloatingPointValue]
  FloatingPointValue operator *(FloatingPointValue multiplicand) =>
      _performOp(multiplicand, (a, b) => a * b);

  /// Addition operation for [FloatingPointValue]
  FloatingPointValue operator +(FloatingPointValue addend) =>
      _performOp(addend, (a, b) => a + b);

  /// Divide operation for [FloatingPointValue]
  FloatingPointValue operator /(FloatingPointValue divisor) =>
      _performOp(divisor, (a, b) => a / b);

  /// Subtract operation for [FloatingPointValue]
  FloatingPointValue operator -(FloatingPointValue subend) =>
      _performOp(subend, (a, b) => a - b);

  /// Negate operation for [FloatingPointValue]
  FloatingPointValue negate() => FloatingPointValue(
      sign: sign.isZero ? LogicValue.one : LogicValue.zero,
      exponent: exponent,
      mantissa: mantissa);
}

/// A representation of a single precision floating point value
class FloatingPoint32Value extends FloatingPointValue {
  static const int _exponentWidth = 8;
  static const int _mantissaWidth = 23;

  /// return the exponent width
  static int get exponentWidth => _exponentWidth;

  /// return the mantissa width
  static int get mantissaWidth => _mantissaWidth;

  /// Constructor for a single precision floating point value
  FloatingPoint32Value(
      {required super.sign, required super.exponent, required super.mantissa})
      : super._() {
    // throw exceptions if widths don't match expectations
    if (exponent.width != _exponentWidth) {
      throw RohdHclException(
          'FloatingPoint32Value: exponent width must be $_exponentWidth');
    }
    if (mantissa.width != _mantissaWidth) {
      throw RohdHclException(
          'FloatingPoint32Value: mantissa width must be $_mantissaWidth');
    }
  }

  /// Return the [FloatingPoint32Value] representing the smallest positive
  /// subnormal number
  factory FloatingPoint32Value.smallestPositiveSubnormal() =>
      FloatingPointValue.smallestPositiveSubnormal(
          _exponentWidth, _mantissaWidth) as FloatingPoint32Value;

  /// Return the [FloatingPoint32Value] representing the largest
  /// subnormal number
  factory FloatingPoint32Value.largestSubnormal() =>
      FloatingPointValue.largestSubnormal(_exponentWidth, _mantissaWidth)
          as FloatingPoint32Value;

  /// Return the [FloatingPoint32Value] representing the smallest
  /// positive normal number
  factory FloatingPoint32Value.smallestPositiveNormal() =>
      FloatingPointValue.smallestPositiveNormal(_exponentWidth, _mantissaWidth)
          as FloatingPoint32Value;

  /// Return the [FloatingPoint32Value] representing the largest normal number
  factory FloatingPoint32Value.largestNormal() =>
      FloatingPointValue.largestNormal(_exponentWidth, _mantissaWidth)
          as FloatingPoint32Value;

  /// Return the [FloatingPoint32Value] representing one
  factory FloatingPoint32Value.one() =>
      FloatingPointValue.one(_exponentWidth, _mantissaWidth)
          as FloatingPoint32Value;

  /// Return the [FloatingPoint32Value] representing positive zero
  factory FloatingPoint32Value.positiveZero() =>
      FloatingPointValue.positiveZero(_exponentWidth, _mantissaWidth)
          as FloatingPoint32Value;

  /// Return the [FloatingPoint32Value] representing negative zero
  factory FloatingPoint32Value.negativeZero() =>
      FloatingPointValue.negativeZero(_exponentWidth, _mantissaWidth)
          as FloatingPoint32Value;

  /// Return the [FloatingPoint32Value] representing the largest number
  /// less than one
  factory FloatingPoint32Value.largestLessThanOne() =>
      FloatingPointValue.largestLessThanOne(_exponentWidth, _mantissaWidth)
          as FloatingPoint32Value;

  /// Return the [FloatingPoint32Value] representing the smallest number
  /// greater than one
  factory FloatingPoint32Value.smallestGreaterThanOne() =>
      FloatingPointValue.smallestGreaterThanOne(_exponentWidth, _mantissaWidth)
          as FloatingPoint32Value;

  /// Return the [FloatingPoint32Value] representing infinity
  factory FloatingPoint32Value.infinity() =>
      FloatingPointValue.infinity(_exponentWidth, _mantissaWidth)
          as FloatingPoint32Value;

  /// Return the [FloatingPoint32Value] representing negative infinity
  factory FloatingPoint32Value.negativeInfinity() =>
      FloatingPointValue.negativeInfinity(_exponentWidth, _mantissaWidth)
          as FloatingPoint32Value;

  /// [FloatingPointValue] constructor from string representation of
  /// individual bitfields
  factory FloatingPoint32Value.ofStrings(
          String sign, String exponent, String mantissa) =>
      FloatingPoint32Value(
          sign: LogicValue.of(sign),
          exponent: LogicValue.of(exponent),
          mantissa: LogicValue.of(mantissa));

  /// [FloatingPointValue] constructor from a single string representing
  /// space-separated bitfields
  factory FloatingPoint32Value.ofString(String fp) {
    final s = fp.split(' ');
    assert(s.length == 3, 'Wrong FloatingPointValue string length ${s.length}');
    return FloatingPoint32Value.ofStrings(s[0], s[1], s[2]);
  }

  /// Numeric conversion of a [FloatingPoint32Value] from a host double
  factory FloatingPoint32Value.fromDouble(double inDouble) {
    final byteData = ByteData(4)
      ..setFloat32(0, inDouble)
      ..buffer.asUint8List();
    final bytes = byteData.buffer.asUint8List();
    final lv = bytes.map((b) => LogicValue.ofInt(b, 32));

    final accum = lv.reduce((accum, v) => (accum << 8) | v);

    final sign = accum[-1];
    final exponent =
        accum.slice(_exponentWidth + _mantissaWidth - 1, _mantissaWidth);
    final mantissa = accum.slice(_mantissaWidth - 1, 0);

    return FloatingPoint32Value(
        sign: sign, exponent: exponent, mantissa: mantissa);
  }
}

/// A representation of a double precision floating point value
class FloatingPoint64Value extends FloatingPointValue {
  static const int _exponentWidth = 11;
  static const int _mantissaWidth = 52;

  /// return the exponent width
  static int get exponentWidth => _exponentWidth;

  /// return the mantissa width
  static int get mantissaWidth => _mantissaWidth;

  /// Constructor for a double precision floating point value
  FloatingPoint64Value(
      {required super.sign, required super.mantissa, required super.exponent})
      : super._() {
    // throw exceptions if widths don't match expectations
    if (exponent.width != _exponentWidth) {
      throw RohdHclException(
          'FloatingPoint64Value: exponent width must be $_exponentWidth');
    }
    if (mantissa.width != _mantissaWidth) {
      throw RohdHclException(
          'FloatingPoint64Value: mantissa width must be $_mantissaWidth');
    }
  }

  /// Return the [FloatingPoint64Value] representing the smallest positive
  /// subnormal number
  factory FloatingPoint64Value.smallestPositiveSubnormal() =>
      FloatingPointValue.smallestPositiveSubnormal(
          _exponentWidth, _mantissaWidth) as FloatingPoint64Value;

  /// Return the [FloatingPoint64Value] representing the largest
  /// subnormal number
  factory FloatingPoint64Value.largestSubnormal() =>
      FloatingPointValue.largestSubnormal(_exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// Return the [FloatingPoint64Value] representing the smallest
  /// positive normal number
  factory FloatingPoint64Value.smallestPositiveNormal() =>
      FloatingPointValue.smallestPositiveNormal(_exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// Return the [FloatingPoint64Value] representing the largest normal number
  factory FloatingPoint64Value.largestNormal() =>
      FloatingPointValue.largestNormal(_exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// Return the [FloatingPoint64Value] representing one
  factory FloatingPoint64Value.one() =>
      FloatingPointValue.one(_exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// Return the [FloatingPoint64Value] representing positive zero
  factory FloatingPoint64Value.positiveZero() =>
      FloatingPointValue.positiveZero(_exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// Return the [FloatingPoint64Value] representing negative zero
  factory FloatingPoint64Value.negativeZero() =>
      FloatingPointValue.negativeZero(_exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// Return the [FloatingPoint64Value] representing the largest number
  /// less than one
  factory FloatingPoint64Value.largestLessThanOne() =>
      FloatingPointValue.largestLessThanOne(_exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// Return the [FloatingPoint64Value] representing the smallest number
  /// greater than one
  factory FloatingPoint64Value.smallestGreaterThanOne() =>
      FloatingPointValue.smallestGreaterThanOne(_exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// Return the [FloatingPoint64Value] representing infinity
  factory FloatingPoint64Value.infinity() =>
      FloatingPointValue.infinity(_exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// Return the [FloatingPoint64Value] representing negative infinity
  factory FloatingPoint64Value.negativeInfinity() =>
      FloatingPointValue.negativeInfinity(_exponentWidth, _mantissaWidth)
          as FloatingPoint64Value;

  /// Numeric conversion of a [FloatingPoint64Value] from a host double
  factory FloatingPoint64Value.fromDouble(double inDouble) {
    final byteData = ByteData(8)
      ..setFloat64(0, inDouble)
      ..buffer.asUint8List();
    final bytes = byteData.buffer.asUint8List();
    final lv = bytes.map((b) => LogicValue.ofInt(b, 64));

    final accum = lv.reduce((accum, v) => (accum << 8) | v);

    final sign = accum[-1];
    final exponent =
        accum.slice(_exponentWidth + _mantissaWidth - 1, _mantissaWidth);
    final mantissa = accum.slice(_mantissaWidth - 1, 0);

    return FloatingPoint64Value(
        sign: sign, mantissa: mantissa, exponent: exponent);
  }
}
