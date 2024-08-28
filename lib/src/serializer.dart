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

/// Serializes wide aggregated data onto a narrower serialization stream
class Serializer extends Module {
  /// Clk input
  @protected
  Logic get clk => input('clk');

  /// Reset input
  @protected
  Logic get reset => input('reset');

  /// Allow serialization ont the output stream when [readyIn] is true
  @protected
  Logic get readyIn => input('readyIn');

  /// Return the count as an output
  @protected
  Logic get count => output('count');

  /// Aggregated data to serialize out
  LogicArray get deserialized => input('deserialized') as LogicArray;

  /// Serialized output, one data item per clock
  Logic get serialized => output('serialized');

  /// Build a Serializer that takes the array [dataIn] and sequences it
  /// out one element at a time on [serialized] output, one element
  /// per clock while [readyIn]
  Serializer(Logic clk, Logic reset, Logic readyIn, LogicArray dataIn) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    readyIn = addInput('readyIn', readyIn);
    dataIn = addInputArray('dataIn', dataIn,
        dimensions: dataIn.dimensions, elementWidth: dataIn.elementWidth);
    addOutput('serialized', width: dataIn.elementWidth);

    addOutput('count', width: log2Ceil(dataIn.dimensions[0])); // for debug
    final length = dataIn.elements.length;

    final cnt = Counter(
        [SumInterface(fixedAmount: 1, hasEnable: true)..enable!.gets(readyIn)],
        clk: clk, reset: reset, maxValue: length - 1);
    count <= cnt.value;
    final dataInFlopped = LogicArray(dataIn.dimensions, dataIn.elementWidth);

    for (var i = 0; i < length; i++) {
      dataInFlopped.elements[i] <=
          flop(clk, reset: reset, en: readyIn, dataIn.elements[i]);
    }
    serialized <= dataInFlopped.elements.selectIndex(count);
  }
}
