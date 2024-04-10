// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// adder.dart
// Implementation of Adder Module.
//
// 2023 June 1
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An abstract class for all adder module.
abstract class Adder extends Module {
  /// The input to the adder pin [a].
  @protected
  late final Logic a;

  /// The input to the adder pin [b].
  @protected
  late final Logic b;

  /// The addition results [out].
  Logic get out => output('out');

  /// The carry results [carryOut].
  Logic get carryOut => output('carryOut');

  /// The addition results [sum].
  Logic get sum => output('sum');

  /// Takes in input [a] and input [b] and return the [sum] of the addition
  /// result. The width of input [a] and [b] must be the same.
  Adder(Logic a, Logic b, {super.name}) {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    this.a = addInput('a', a, width: a.width);
    this.b = addInput('b', b, width: b.width);
    addOutput('out', width: a.width);
    addOutput('carryOut');
    addOutput('sum', width: a.width + 1);
  }
}

/// A simple full-adder with inputs `a` and `b` to be added with a `carryIn`.
class FullAdder extends Module {
  /// The addition's result [sum].
  Logic get sum => output('sum');

  /// The carry bit's result [carryOut].
  Logic get carryOut => output('carry_out');

  /// Constructs a [FullAdder] with value [a], [b] and [carryIn] based on
  /// full adder truth table.
  FullAdder({
    required Logic a,
    required Logic b,
    required Logic carryIn,
    super.name = 'full_adder',
  }) {
    a = addInput('a', a, width: a.width);
    b = addInput('b', b, width: b.width);
    carryIn = addInput('carry_in', carryIn, width: carryIn.width);

    final carryOut = addOutput('carry_out');
    final sum = addOutput('sum');

    final and1 = carryIn & (a ^ b);
    final and2 = b & a;

    sum <= (a ^ b) ^ carryIn;
    carryOut <= and1 | and2;
  }
}

/// An Adder which performs one's complement arithmetic using an unsigned
/// adder that is passed in using a functor
///    -- Requires that if the larger magnitude number is negative it
///       must be the first 'a' argument
///       We cannot enforce because this may be a smaller mantissa in
///       a larger magnitude negative number (no asserts please)
class OnesComplementAdder extends Adder {
  /// The sign of the result
  Logic get sign => output('sign');

  /// [OnesComplementAdder] constructor with an unsigned adder functor
  OnesComplementAdder(Logic aSign, super.a, Logic bSign, super.b,
      Adder Function(Logic, Logic) adderGen)
      : super(name: 'Ones Complement Adder') {
    final aOnesComplement = Logic(width: a.width);
    final bOnesComplement = Logic(width: b.width);
    final sign = addOutput('sign');

    aOnesComplement <= mux(aSign, ~a, a);
    bOnesComplement <= mux(bSign, ~b, b);

    final adder = adderGen(aOnesComplement, bOnesComplement);
    // print('\tA  ${aOnesComplement.value.toString(includeWidth: false)}');
    // print('\tb  ${b.value.toString(includeWidth: false)}');
    // print('\tB  ${bOnesComplement.value.toString(includeWidth: false)}');
    // print('\to ${adder.sum.value.toString(includeWidth: false)}');

    final endAround = adder.carryOut & (aSign | bSign);
    // final endAround = adder.carryOut & aSign;
    final localOut = mux(endAround, adder.sum + 1, adder.sum);

    // print('\tl ${localOut.value.toString(includeWidth: false)}');
    // print('EndAround ${endAround.value.toString()}');

    sum <= (mux(aSign, ~localOut, localOut));
    out <= sum.slice(sum.width - 2, 0);
    carryOut <= sum.slice(sum.width - 1, sum.width - 1);
    sign <= aSign;
    // print('\tS ${sum.value.toString(includeWidth: false)}');
    //   print('\tO  ${out.value.toString(includeWidth: false)}');
    //   print('\tC  ${carryOut.value.toString(includeWidth: false)}');
    //   print('\ts  ${sign.value.toString(includeWidth: false)}');
  }
}
