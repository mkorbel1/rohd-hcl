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
import 'package:rohd_hcl/src/exceptions.dart';

/// A flexible representation of floating point values
class FloatingPointValue {
  /// The full floating point value bit storage
  final LogicValue value;

  /// The sign of the value:  1 means a negative value
  final LogicValue sign;

  /// The mantissa of the floating point
  final LogicValue mantissa;

  /// The exponent of the floating point: this is biased about a midpoint for
  /// positive and negative exponents
  final LogicValue exponent;

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
      required LogicValue mantissa,
      required LogicValue exponent}) {
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

  FloatingPointValue._(
      {required this.sign, required this.mantissa, required this.exponent})
      : value = [sign, exponent, mantissa].swizzle() {
    if (sign.width != 1) {
      throw RohdHclException('FloatingPointValue: sign width must be 1');
    }
  }

  /// Convert a floating point number into a [FloatingPointValue]
  /// representation.
  factory FloatingPointValue.fromDouble(double inDouble,
      {required int mantissaWidth, required int exponentWidth}) {
    var doubleVal = inDouble;
    LogicValue sign;
    if (inDouble < 0.0) {
      doubleVal = -doubleVal;
      sign = LogicValue.one;
    } else {
      sign = LogicValue.zero;
    }

    // If we are dealing with a really small number we need to scale it up
    final scaleToWhole = (-log(doubleVal) / log(2)).floor();
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
    var e = fullLength - mantissaWidth - scaleToWhole;

    if (e < -FloatingPointValue._bias(exponentWidth)) {
      fullValue = fullValue >>>
          (scaleToWhole - FloatingPointValue._bias(exponentWidth));
      e = -FloatingPointValue._bias(exponentWidth);
    } else {
      e -= 1;
      fullValue = fullValue << 1; // Chop the first '1'
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

    // print('${sign.toString(includeWidth: false)}'
    //     ' ${exponent.toString(includeWidth: false)}'
    //     ' ${mantissa.toString(includeWidth: false)} finished');

    return FloatingPointValue(
      exponent: exponent,
      mantissa: mantissa,
      sign: sign,
    );
  }

  // TODO(desmonddak): what about floating point representations >> 64 bits?
  // more BigInt stuff?

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

  FloatingPointValue operator *(FloatingPointValue multiplicand) =>
      _performOp(multiplicand, (a, b) => a * b);

  FloatingPointValue operator +(FloatingPointValue addend) =>
      _performOp(addend, (a, b) => a + b);

  FloatingPointValue operator /(FloatingPointValue divisor) =>
      _performOp(divisor, (a, b) => a / b);

  FloatingPointValue operator -(FloatingPointValue subend) =>
      _performOp(subend, (a, b) => a - b);
}

/// A representation of a single precision floating point value
class FloatingPoint32Value extends FloatingPointValue {
  static const int _exponentWidth = 8;
  static const int _mantissaWidth = 23;

  /// Constructor for a single precision floating point value
  FloatingPoint32Value(
      {required super.sign, required super.mantissa, required super.exponent})
      : super._() {
    // throw exceptions if widths don't match expectations
    if (mantissa.width != _mantissaWidth) {
      throw RohdHclException('FloatingPoint32Value: mantissa width must be 23');
    }
    if (exponent.width != _exponentWidth) {
      throw RohdHclException('FloatingPoint32Value: exponent width must be 8');
    }
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
        accum.slice(_mantissaWidth + _exponentWidth - 1, _mantissaWidth);
    final mantissa = accum.slice(_mantissaWidth - 1, 0);

    // print('${sign.toString(includeWidth: false)}'
    //     ' ${exponent.toString(includeWidth: false)}'
    //     ' ${mantissa.toString(includeWidth: false)} direct conversion');

    return FloatingPoint32Value(
        sign: sign, mantissa: mantissa, exponent: exponent);
  }
}

/// A representation of a double precision floating point value
class FloatingPoint64Value extends FloatingPointValue {
  static const int _exponentWidth = 11;
  static const int _mantissaWidth = 52;

  /// Constructor for a double precision floating point value
  FloatingPoint64Value(
      {required super.sign, required super.mantissa, required super.exponent})
      : super._() {
    // throw exceptions if widths don't match expectations
    if (mantissa.width != _mantissaWidth) {
      throw RohdHclException('FloatingPoint64Value: mantissa width must be 52');
    }
    if (exponent.width != _exponentWidth) {
      throw RohdHclException('FloatingPoint64Value: exponent width must be 11');
    }
  }

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
        accum.slice(_mantissaWidth + _exponentWidth - 1, _mantissaWidth);
    final mantissa = accum.slice(_mantissaWidth - 1, 0);

    // print('${sign.toString(includeWidth: false)}'
    //     ' ${exponent.toString(includeWidth: false)}'
    //     ' ${mantissa.toString(includeWidth: false)} direct conversion');

    return FloatingPoint64Value(
        sign: sign, mantissa: mantissa, exponent: exponent);
  }
}

/// Flexible floating point representation
class FloatingPoint extends LogicStructure {
  /// unsigned, biased binary [exponent]
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

  /// Return the [FloatingPointValue]
  FloatingPointValue get floatingPointValue => FloatingPointValue(
      sign: sign.value, mantissa: mantissa.value, exponent: exponent.value);
}

/// Single floating point representation
class FloatingPoint32 extends FloatingPoint {
  /// Construct a 32-bit (single-precision) floating point number
  FloatingPoint32()
      : super(
            exponentWidth: FloatingPoint32Value._exponentWidth,
            mantissaWidth: FloatingPoint32Value._mantissaWidth);
}

/// Double floating point representation
class FloatingPoint64 extends FloatingPoint {
  /// Construct a 64-bit (double-precision) floating point number
  FloatingPoint64()
      : super(
            exponentWidth: FloatingPoint64Value._exponentWidth,
            mantissaWidth: FloatingPoint64Value._mantissaWidth);
}
