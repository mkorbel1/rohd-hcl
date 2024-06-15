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

import 'dart:io';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/booth.dart';
import 'package:rohd_hcl/src/arithmetic/compressor.dart';

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

  /// Return a Logic true if this FloatingPoint contains a normal number
  Logic isNormal() => exponent.neq(LogicValue.zero.zeroExtend(exponent.width));

  /// Return the zero exponent representation for this type of FloatingPoint
  Logic zeroExponent() => Const(LogicValue.zero).zeroExtend(exponent.width);

  /// Return the one  exponent representation for this type of FloatingPoint
  Logic oneExponent() => Const(LogicValue.one).zeroExtend(exponent.width);
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
  @protected
  late final FloatingPoint _out =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Swapping two FloatingPoint structures based on a conditional
  static (FloatingPoint, FloatingPoint) _swap(
          Logic swap, (FloatingPoint, FloatingPoint) toSwap) =>
      (
        toSwap.$1.clone()..gets(mux(swap, toSwap.$2, toSwap.$1)),
        toSwap.$2.clone()..gets(mux(swap, toSwap.$1, toSwap.$2))
      );

  /// Add two floating point numbers [a] and [b], returning result in [out]
  FloatingPointAdder(FloatingPoint a, FloatingPoint b,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppGen,
      {super.name})
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

    (a, b) = _swap(doSwap, (a, b));

    final aExp =
        a.exponent + mux(a.isNormal(), a.zeroExponent(), a.oneExponent());
    final bExp =
        b.exponent + mux(b.isNormal(), b.zeroExponent(), b.oneExponent());

    // Align and add mantissas
    final expDiff = aExp - bExp;
    // print('${expDiff.value.toInt()} exponent diff');
    final adder = OnesComplementAdder(
        a.sign,
        [a.isNormal(), a.mantissa].swizzle(),
        b.sign,
        [b.isNormal(), b.mantissa].swizzle() >>> expDiff,
        (a, b) => ParallelPrefixAdder(a, b, ppGen));

    final leadOneE =
        ParallelPrefixPriorityEncoder(adder.out.reversed, ppGen).out;
    final leadOne = leadOneE.zeroExtend(exponentWidth);

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
          _out.exponent < _out.zeroExponent()
        ])
      ])
    ]);
  }
}

/// An multiplier module for FloatingPoint values
class FloatingPointMultiplier extends Module {
  /// Must be greater than 0.
  final int exponentWidth;

  /// Must be greater than 0.
  final int mantissaWidth;

  /// Output [FloatingPoint] computed
  late final FloatingPoint out =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth)
        ..gets(output('out'));

  /// The result of [FloatingPoint] multiplication
  @protected
  late final FloatingPoint _out =
      FloatingPoint(exponentWidth: exponentWidth, mantissaWidth: mantissaWidth);

  /// Multiply two floating point numbers [a] and [b], returning result in [out]
  FloatingPointMultiplier(FloatingPoint a, FloatingPoint b, int radix,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppGen,
      {super.name})
      : exponentWidth = a.exponent.width,
        mantissaWidth = a.mantissa.width {
    if (b.exponent.width != exponentWidth ||
        b.mantissa.width != mantissaWidth) {
      throw RohdHclException('FloatingPoint widths must match');
    }
    a = a.clone()..gets(addInput('a', a, width: a.width));
    b = b.clone()..gets(addInput('b', b, width: b.width));
    addOutput('out', width: _out.width) <= _out;
    final aExp =
        a.exponent + mux(a.isNormal(), a.zeroExponent(), a.oneExponent());
    final bExp =
        b.exponent + mux(b.isNormal(), b.zeroExponent(), b.oneExponent());

    final aMantissa = [a.isNormal(), a.mantissa].swizzle();
    final bMantissa = [b.isNormal(), b.mantissa].swizzle();

    final pp = PartialProductGenerator(
        aMantissa, bMantissa, RadixEncoder(radix),
        signed: false);
    // ignore: cascade_invocations
    pp.signExtendCompact();
    final compressor = ColumnCompressor(pp);
    // ignore: cascade_invocations
    compressor.compress();
    final r0 = compressor.extractRow(0);
    final r1 = compressor.extractRow(1);
    final adder = ParallelPrefixAdder(r0, r1, ppGen);

    final rawMantissa = adder.out.slice((exponentWidth + 1) * 2 - 1, 0);
    // Find the leading '1' in the mantissa
    final pos =
        ParallelPrefixPriorityEncoder(rawMantissa.reversed, KoggeStone.new)
            .out
            .zeroExtend(exponentWidth);

    final expAdd = aExp - FloatingPointValue.bias(aExp.width) + bExp - pos + 1;

    // stdout.write('aExp=${aExp.value}, bExp=${bExp.value}, '
    //     'pos=${pos.value}, bias=${FloatingPointValue.bias(aExp.width)} '
    //     'expAdd=${expAdd.value}\n');

    final mantissa = rawMantissa << (pos + 1);
    final normMantissa = mantissa.reversed.slice(mantissaWidth - 1, 0).reversed;

    // stdout
    //   ..write('aMant:  ${bitString(aMantissa.value)}\n')
    //   ..write('bMant:  ${bitString(bMantissa.value)}\n')
    //   ..write('out:  ${bitString(adder.out.value)}\n')
    //   ..write('lenOut:  ${adder.out.width} ')
    //   ..write('rawMantissa:  ${bitString(rawMantissa.value)} ')
    //   ..write('normMantissa: ${bitString(normMantissa.value)}')
    //   ..write('\n');

    // stdout.write(
    //     'e=${bitString(expAdd.value)} m=${bitString(normMantissa.value)}\n');

    _out.sign <= a.sign ^ b.sign;
    _out.exponent <= expAdd;
    // _out.exponent <= Const(8, width: exponentWidth);
    _out.mantissa <= normMantissa;
  }
}
