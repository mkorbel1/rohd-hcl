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

  /// Allow serialization onto the output stream when [readyIn] is true
  @protected
  Logic get readyIn => input('readyIn');

  /// Return the count as an output
  Logic get count => output('count');

  /// Return [done] = true when we have processed [deserialized] completely
  Logic get done => output('done');

  /// Aggregated data to serialize out
  LogicArray get deserialized => input('deserialized') as LogicArray;

  /// Serialized output, one data item per clock
  Logic get serialized => output('serialized');

  /// Build a Serializer that takes the array [dataIn] and sequences it
  /// out one element at a time on [serialized] output, one element
  /// per clock while [readyIn]
  Serializer(
    LogicArray dataIn, {
    required Logic clk,
    required Logic reset,
    Logic? readyIn, 
    {super.name = 'Serializer'}
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    if (readyIn != null) {
      readyIn = addInput('readyIn', readyIn);
    } else {
      readyIn = Const(1);
    }
    dataIn = addInputArray('dataIn', dataIn,
        dimensions: dataIn.dimensions, elementWidth: dataIn.elementWidth);
    addOutput('serialized', width: dataIn.elementWidth);

    addOutput('count', width: log2Ceil(dataIn.dimensions[0]));
    addOutput('done');
    final length = dataIn.elements.length;

    final cnt = Counter(
        [SumInterface(fixedAmount: 1, hasEnable: true)..enable!.gets(readyIn)],
        clk: clk, reset: reset, maxValue: length - 1);
    count <= cnt.count;
    final dataInFlopped = LogicArray(dataIn.dimensions, dataIn.elementWidth);
    done <= cnt.overflowed;

    for (var i = 0; i < length; i++) {
      dataInFlopped.elements[i] <=
          flop(clk, reset: reset, en: readyIn, dataIn.elements[i]);
    }
    serialized <= dataInFlopped.elements.selectIndex(count);
  }
}
