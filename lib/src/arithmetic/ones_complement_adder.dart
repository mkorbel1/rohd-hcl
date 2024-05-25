// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// ones_complement_adder
// Implementation of a One's Complement Adder
//
// 2024 April 12
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// An Adder which performs one's complement arithmetic using an unsigned
/// adder that is passed in using a functor
///    -- Requires that if the larger magnitude number is negative it
///       must be the first 'a' argument
///       We cannot enforce because this may be a smaller mantissa in
///       a larger magnitude negative number (no asserts please)
class OnesComplementAdder extends Adder {
  /// The sign of the result
  Logic get sign => output('sign');

  late final Logic _out;
  late final Logic _carry = Logic();

  /// [OnesComplementAdder] constructor with an unsigned adder functor
  OnesComplementAdder(Logic aSign, super.a, Logic bSign, super.b,
      Adder Function(Logic, Logic) adderGen)
      : _out = Logic(width: a.width),
        super(name: 'Ones Complement Adder') {
    aSign = addInput('aSign', aSign);
    bSign = addInput('bSign', bSign);
    final sign = addOutput('sign');

    final aOnesComplement = mux(aSign, ~a, a);
    final bOnesComplement = mux(bSign, ~b, b);

    final adder = adderGen(aOnesComplement, bOnesComplement);
    final endAround = adder.carryOut & (aSign | bSign);
    final localOut = mux(endAround, adder.sum + 1, adder.sum);

    _out <= mux(aSign, ~localOut, localOut).slice(_out.width - 1, 0);
    _carry <= localOut.slice(localOut.width - 1, localOut.width - 1);
    sign <= aSign;
  }

  @override
  @protected
  Logic calculateOut() => _out;

  @override
  @protected
  Logic calculateCarry() => _carry;

  @override
  @protected
  Logic calculateSum() => [_carry, _out].swizzle();
}
