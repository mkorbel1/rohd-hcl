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

// ignore_for_file: avoid_print

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/floating_point_value.dart';

/// Flexible floating point logic representation
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
      sign: sign.value, exponent: exponent.value, mantissa: mantissa.value);
}

/// Single floating point representation
class FloatingPoint32 extends FloatingPoint {
  /// Construct a 32-bit (single-precision) floating point number
  FloatingPoint32()
      : super(
            exponentWidth: FloatingPoint32Value.exponentWidth,
            mantissaWidth: FloatingPoint32Value.mantissaWidth);
}

/// Double floating point representation
class FloatingPoint64 extends FloatingPoint {
  /// Construct a 64-bit (double-precision) floating point number
  FloatingPoint64()
      : super(
            exponentWidth: FloatingPoint64Value.exponentWidth,
            mantissaWidth: FloatingPoint64Value.mantissaWidth);
}

/// An adder module for FloatingPoint values
class FloatingPointAdder extends Module {
  /// Must be greater than 0.
  final int exponentWidth;

  /// Must be greater than 0.
  final int mantissaWidth;

  /// Output [FloatingPoint] computed
  late final FloatingPoint out =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        ..gets(output('out'));

  /// The result of [FloatingPoint] addition
  // FloatingPoint get out => output('out');
  @protected
  late final FloatingPoint _out =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Swapping two FloatingPoint structures based on a conditional
  static (FloatingPoint, FloatingPoint) swap(
          Logic swap, (FloatingPoint, FloatingPoint) toSwap) =>
      (
        toSwap.$1.clone()..gets(mux(swap, toSwap.$2, toSwap.$1)),
        toSwap.$2.clone()..gets(mux(swap, toSwap.$1, toSwap.$2))
      );

  /// Add two floating point numbers [a] and [b], returning result in [out]
  FloatingPointAdder(FloatingPoint a, FloatingPoint b, {super.name})
      : exponentWidth = a.exponent.width,
        mantissaWidth = a.mantissa.width {
    if (b.exponent.width != exponentWidth ||
        b.mantissa.width != mantissaWidth) {
      throw RohdHclException('FloatingPoint widths must match');
    }
    a = a.clone()..gets(addInput('a', a, width: a.width));
    b = b.clone()..gets(addInput('b', b, width: b.width));
    addOutput('out', width: _out.width) <= _out;

    // Ensure that the larger number is wired as 'a'
    final doSwap = a.exponent.lt(b.exponent) |
        (a.exponent.eq(b.exponent) & a.mantissa.lt(b.mantissa)) |
        ((a.exponent.eq(b.exponent) & a.mantissa.eq(b.mantissa)) & b.sign);

    (a, b) = swap(doSwap, (a, b));

    final aNormal = a.exponent.neq(LogicValue.zero.zeroExtend(exponentWidth));
    final bNormal = b.exponent.neq(LogicValue.zero.zeroExtend(exponentWidth));

    final aExp = a.exponent +
        mux(aNormal, Const(LogicValue.zero).zeroExtend(exponentWidth),
            Const(LogicValue.one).zeroExtend(exponentWidth));
    final bExp = b.exponent +
        mux(bNormal, Const(LogicValue.zero).zeroExtend(exponentWidth),
            Const(LogicValue.one).zeroExtend(exponentWidth));

    // Align and add mantissas
    final expDiff = aExp - bExp;
    // print('${expDiff.value.toInt()} exponent diff');
    final adder = OnesComplementAdder(
        a.sign,
        [aNormal, a.mantissa].swizzle(),
        b.sign,
        [bNormal, b.mantissa].swizzle() >>> expDiff,
        (a, b) => ParallelPrefixAdder(a, b, KoggeStone.new));

    final leadOneE =
        ParallelPrefixPriorityEncoder(adder.out.reversed, KoggeStone.new).out;
    final leadOne = leadOneE.zeroExtend(exponentWidth);

    // print('${adder.out.value.toString(includeWidth: false)} out');
    // print(
    //     '${leadOne.value.toInt()} lead one vs ${a.exponent.value.toInt()}');
    // print('${a.exponent.value.toInt()} a exp');
    // print('${adder.carryOut.value.toInt()} a carry');
    // Assemble the output FloatingPoint
    _out.sign <= adder.sign;
    Combinational([
      If.block([
        Iff(adder.carryOut & a.sign.eq(b.sign), [
          _out.mantissa < (adder.out >> 1).slice(mantissaWidth - 1, 0),
          _out.exponent < a.exponent + 1
        ]),
        ElseIf(a.exponent.gt(leadOne), [
          _out.mantissa < (adder.out << leadOne).slice(mantissaWidth - 1, 0),
          _out.exponent < a.exponent - leadOne
        ]),
        Else([
          // subnormal result
          _out.mantissa < adder.out.slice(mantissaWidth - 1, 0),
          _out.exponent < Const(LogicValue.zero).zeroExtend(exponentWidth)
        ])
      ])
    ]);
  }
}
