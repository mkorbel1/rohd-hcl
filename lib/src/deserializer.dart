// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// deserializer.dart
// A deserialization block, deserializing wide input data onto a narrow channel.
//
// 2024 August 27
// Author: desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Aggregates data from a serialized stream
class Deserializer extends Module {
  /// Clk input
  @protected
  Logic get clk => input('clk');

  /// Reset input
  @protected
  Logic get reset => input('reset');

  /// Run deserialization whenever [enable] is true
  @protected
  Logic get enable => input('enable');

  /// Serialized input, one data item per clock
  Logic get serialized => input('serialized');

  /// Aggregated data output
  LogicArray get deserialized => output('deserialized') as LogicArray;

  /// Valid out when data is reached
  Logic get validOut => output('validOut');

  /// Return the count as an output
  @protected
  Logic get count => output('count');

  /// Build a Deserializer that takes serialized input [serialized] of size
  /// [length] and aggregates it into one wide output [deserialized],
  /// emitting [validOut] when complete
  Deserializer(Logic serialized, int length,
      {required Logic clk, required Logic reset, Logic? validIn}) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    if (validIn != null) {
      validIn = addInput('enable', validIn);
    } else {
      validIn = Const(1);
    }
    serialized = addInput('serialized', serialized, width: serialized.width);
    addOutputArray('deserialized',
        dimensions: [length], elementWidth: serialized.width);

    final cnt = Counter(
        [SumInterface(fixedAmount: 1, hasEnable: true)..enable!.gets(validIn)],
        clk: clk, reset: reset, maxValue: length - 1);
    addOutput('count', width: cnt.width);
    addOutput('validOut') <= cnt.equalsMax;
    final dataOutList = [
      for (var i = 0; i < length; i++)
        flop(clk, reset: reset, en: validIn & count.eq(i), serialized)
    ];
    deserialized <= dataOutList.swizzle();
    count <= cnt.count;
  }
}
