// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// serializer.dart
// A serialization block, serializing narrow input data onto a wide channel.
//
// 2024 August 27
// Author: desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// Aggregates data from a serialized stream
class Serializer extends Module {
  /// Clk input
  @protected
  Logic get clk => input('clk');

  /// Reset input
  @protected
  Logic get reset => input('reset');

  /// Start the serialization when [start] is 1,
  @protected
  Logic get start => input('start');

  /// Return the count as an output (for help in debug)
  @protected
  Logic get count => output('count');

  /// Serialized input, one data item per clock
  LogicArray get serialized => input('serialized') as LogicArray;

  /// Aggregated data output
  LogicArray get dataOut => output('dataOut') as LogicArray;

  /// Build a Aggregator that takes serialized input [serialized] and aggregates
  /// it into one wide output [dataOut]
  Serializer(
      Logic clk, Logic reset, Logic enable, Logic serialized, int length) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    enable = addInput('start', enable);
    final addresses = length;
    final addressWidth = log2Ceil(length);
    serialized = addInput('serialized', serialized, width: serialized.width);
    addOutputArray('dataOut',
        dimensions: [length], elementWidth: serialized.width);

    addOutput('count', width: addressWidth); // for debug
    // final intf = SumInterface(fixedAmount: 1);
    // final cnt = Counter([intf],
    //     clk: clk, reset: reset, restart: start, maxValue: length);
    // count <= cnt.value;
    count <=
        flop(
            clk,
            reset: reset | count.eq(length),
            en: enable,
            (count + 1) % length);
    final dataOutList = [
      for (var i = 0; i < addresses; i++)
        flop(
            clk,
            reset: reset | count.eq(length),
            en: enable & count.eq(Const(i, width: addressWidth)),
            serialized)
    ];
    dataOut <= dataOutList.swizzle();
  }
}
