// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// multiplier.dart
// Abstract class of of multiplier module implementation. All multiplier module
// need to inherit this module to ensure consistency.
//
// 2023 May 29
// Author: Yao Jing Quek <yao.jing.quek@intel.com>

import 'dart:io';

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/arithmetic/booth.dart';
import 'package:rohd_hcl/src/arithmetic/compressor.dart';

/// An abstract class for all multiplier implementations.
abstract class Multiplier extends Module {
  /// The input to the multiplier pin [a].
  @protected
  late final Logic a;

  /// The input to the multiplier pin [b].
  @protected
  late final Logic b;

  /// The multiplication results of the multiplier.
  Logic get product;

  /// Take input [a] and input [b] and return the
  /// [product] of the multiplication result.
  Multiplier(Logic a, Logic b, {super.name}) {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    this.a = addInput('a', a, width: a.width);
    this.b = addInput('b', b, width: b.width);
  }
}

/// An abstract class for all multiply accumulate implementations.
abstract class MultiplyAccumulate extends Module {
  /// The input to the multiplier pin [a].
  @protected
  late final Logic a;

  /// The input to the multiplier pin [b].
  @protected
  late final Logic b;

  /// The input to the addend pin [c].
  @protected
  late final Logic c;

  /// The multiplication results of the multiply-accumulate.
  Logic get accumulate;

  /// Take input [a] and input [b], compute their
  /// product, add input [c] to produce the [accumulate] result.
  MultiplyAccumulate(Logic a, Logic b, Logic c, {super.name}) {
    if (a.width != b.width) {
      throw RohdHclException('inputs of a and b should have same width.');
    }
    this.a = addInput('a', a, width: a.width);
    this.b = addInput('b', b, width: b.width);
    this.c = addInput('c', c, width: c.width);
  }
}

/// An implementation of an integer multiplier using compression trees
class CompressionTreeMultiplier extends Multiplier {
  /// The final product of the multiplier module.
  @override
  Logic get product => output('product');

  /// Construct a compression tree integer multipler with
  ///   a given radix and final adder functor
  CompressionTreeMultiplier(super.a, super.b, int radix,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppTree,
      {bool signed = false, super.name}) {
    final product = addOutput('product', width: a.width + b.width);

    final pp =
        PartialProductGenerator(a, b, RadixEncoder(radix), signed: signed);
    // ignore: cascade_invocations
    pp.signExtendCompact();
    final compressor = ColumnCompressor(pp);
    // ignore: cascade_invocations
    compressor.compress();
    final adder = ParallelPrefixAdder(
        compressor.extractRow(0), compressor.extractRow(1), ppTree);
    product <= adder.out.slice(a.width + b.width - 1, 0);
  }
}

/// An implementation of an integer multiplier using compression trees
class CompressionTreeMultiplyAccumulate extends MultiplyAccumulate {
  /// The final product of the multiplier module.
  @override
  Logic get accumulate => output('accumulate');

  /// Construct a compression tree integer multipler with
  ///   a given radix and final adder functor
  CompressionTreeMultiplyAccumulate(super.a, super.b, super.c, int radix,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppTree,
      {bool signed = false, super.name}) {
    final accumulate = addOutput('accumulate', width: a.width + b.width + 1);

    final pp =
        PartialProductGenerator(a, b, RadixEncoder(radix), signed: signed);
    // ignore: cascade_invocations
    pp.signExtendCompact();

    // Evaluate works only because the compressed rows have the same shape
    // So the rowshift is valid.
    // But this requires that we prefix the PP with the addend (not add) to
    // keep the evaluate routine working.

    final sign = signed ? c[c.width - 1] : Const(0);
    final l = [for (var i = 0; i < c.width; i++) c[i]];
    // ignore: cascade_invocations
    l
      ..add(~sign)
      ..add(Const(1));
    pp.partialProducts.insert(0, l);
    pp.rowShift.insert(0, 0);
    final compressor = ColumnCompressor(pp);
    // ignore: cascade_invocations
    compressor.compress();

    final adder = ParallelPrefixAdder(
        compressor.extractRow(0), compressor.extractRow(1), ppTree);
    accumulate <= adder.out.slice(a.width + b.width, 0);
  }
}
