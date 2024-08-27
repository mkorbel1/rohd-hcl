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

/// Deserializes aggregated data onto a narrower serialization stream
class Deserializer extends Module {
  /// Clk input
  @protected
  Logic get clk => input('clk');

  /// Reset input
  @protected
  Logic get reset => input('reset');

  /// Start the count when [start] is 1, only needs to be held for 1 cycle
  @protected
  Logic get start => input('start');

  /// Return the count as an output (for debug)
  @protected
  Logic get count => output('count');

  /// Aggregated data to serialize out
  LogicArray get dataIn => input('dataIn') as LogicArray;

  /// Serialized output, one data item per clock
  Logic get serialized => output('serialized');

  /// Build a Sequencer that takes the array [dataIn] and sequences it
  /// out one element at a time on [serialized], one per clock after [enable]
  Deserializer(Logic clk, Logic reset, Logic enable, LogicArray dataIn) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    enable = addInput('start', enable);
    dataIn = addInputArray('dataIn', dataIn,
        dimensions: dataIn.dimensions, elementWidth: dataIn.elementWidth);
    addOutput('serialized', width: dataIn.elementWidth);

    final addressWidth = log2Ceil(dataIn.dimensions[0]);

    addOutput('count', width: addressWidth); // for debug
    final length = dataIn.elements.length;

    count <=
        flop(
            clk,
            reset: reset | count.eq(length),
            en: enable,
            (count + 1) % length);

    final dataInFlopped = LogicArray(dataIn.dimensions, dataIn.elementWidth);

    for (var i = 0; i < length; i++) {
      dataInFlopped.elements[i] <=
          flop(clk, reset: reset, en: enable, dataIn.elements[i]);
    }
    serialized <= dataInFlopped.elements.selectIndex(count);
  }
}
