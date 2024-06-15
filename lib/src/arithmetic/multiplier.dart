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

/// An abstract class for all multiplier implementation.
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

/// An implementation of an integer multiplier using compression trees
class CompressionTreeMultiplier extends Multiplier {
  /// The final product of the multiplier module.
  @override
  Logic get product => output('product');

  /// Construct a compression tree integer multipler with
  ///   a given radix and final adder functor
  CompressionTreeMultiplier(super.a, super.b, int radix,
      ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic)) ppTree,
      {super.name}) {
    const signed = false; // We need to move this into a parameter
    final product = addOutput('product', width: a.width + b.width + 1);

    final pp =
        PartialProductGenerator(a, b, RadixEncoder(radix), signed: signed);
    // ignore: cascade_invocations
    pp.signExtendCompact();
    final compressor = ColumnCompressor(pp);
    // ignore: cascade_invocations
    compressor.compress();
    final adder = ParallelPrefixAdder(
        compressor.extractRow(0), compressor.extractRow(1), ppTree);
    product <= adder.out.slice(a.width + b.width, 0);
  }
}
