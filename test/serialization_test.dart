// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// aggregator.dart
// A flexible aggregator implementation.
//
// 2024 August 27
// Author: desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>
//
// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/deserializer.dart';
import 'package:rohd_hcl/src/serializer.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  test('deserializer', () async {
    const len = 10;
    const width = 8;
    final dataIn = LogicArray([len], width);
    final clk = SimpleClockGenerator(10).clk;
    final start = Logic();
    final reset = Logic();
    final mod = Deserializer(clk, reset, start, dataIn);

    await mod.build();

    WaveDumper(mod);

    unawaited(Simulator.run());

    start.put(0);
    reset.put(0);
    var clkCount = 0;
    for (var i = 0; i < len; i++) {
      dataIn.elements[i].put(i);
    }
    print('dataIn[3]= ${dataIn.elements[3].value.bitString}');
    print('dataInFull ${dataIn.reversed.value.bitString}');
    await clk.nextPosedge;
    print('initial ${mod.count.value}');

    reset.put(1);

    await clk.nextPosedge;
    print('reset: ${mod.serialized.value.bitString} cnt=${mod.count.value}');

    reset.put(0);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;
    print('unreset: ${mod.serialized.value.bitString} cnt=${mod.count.value}');
    start.put(1);
    await clk.nextPosedge;
    print('start: ${mod.serialized.value.bitString} cnt=${mod.count.value}');

    clkCount++;
    print(
        '$clkCount: ${mod.serialized.value.bitString} cnt=${mod.count.value}');

    for (var i = 0; i < 16; i++) {
      await clk.nextPosedge;
      clkCount++;
      print(
          '$clkCount: ${mod.serialized.value.bitString} cnt=${mod.count.value}');
    }
    await Simulator.endSimulation();
  });

  test('serializer', () async {
    const len = 6;
    const width = 8;
    final dataIn = Logic(width: width);
    final clk = SimpleClockGenerator(10).clk;
    final start = Logic();
    final reset = Logic();
    final mod = Serializer(clk, reset, start, dataIn, len);
    await mod.build();
    unawaited(Simulator.run());
    WaveDumper(mod);

    start.put(0);
    reset.put(0);
    var clkCount = 0;
    await clk.nextPosedge;
    print('initial: ${mod.dataOut.value.bitString}, '
        'count: ${mod.count.value.bitString}');

    reset.put(1);

    await clk.nextPosedge;
    print('reset:   ${mod.dataOut.value.bitString}, '
        'count: ${mod.count.value.bitString}');

    reset.put(0);
    dataIn.put(255);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;
    print('unreset: ${mod.dataOut.value.bitString}, '
        'count: ${mod.count.value.bitString}');
    start.put(1);
    await clk.nextPosedge;
    clkCount++;
    print('$clkCount:\t${mod.dataOut.value.bitString}, '
        'count: ${mod.count.value.bitString}');

    // start.put(0);

    for (var i = 0; i < 11; i++) {
      if (i < 5) {
        dataIn.put(255);
      } else {
        dataIn.put(0);
      }
      await clk.nextPosedge;
      clkCount++;
      print('$clkCount:\t${mod.dataOut.value.bitString}, '
          'count: ${mod.count.value.bitString}');
    }

    await Simulator.endSimulation();
  });

  test('counter fixed test', () async {
    const len = 6;
    final clk = SimpleClockGenerator(10).clk;
    final start = Logic();
    final reset = Logic();
    final mod = Counter([SumInterface(fixedAmount: 1)],
        clk: clk, reset: reset, restart: start, maxValue: len);

    unawaited(Simulator.run());

    // final count = Logic(width: 3);
    // count <= flop(clk, reset: reset, en: start, count + 1);

    reset.inject(0);
    start.inject(0);
    await clk.nextPosedge;
    print(mod.value.value.bitString);
    reset.inject(1);
    await clk.nextPosedge;
    print('reset ${mod.value.value.bitString}');
    reset.inject(0);
    await clk.nextPosedge;
    print('unreset ${mod.value.value.bitString}');
    start.inject(1);
    await clk.nextPosedge;
    print('reset ${mod.value.value.bitString}');
    start.inject(0);
    await clk.nextPosedge;
    print('unreset ${mod.value.value.bitString}');
    await clk.nextPosedge;
    print('unreset ${mod.value.value.bitString}');
    await clk.nextPosedge;
    print('unreset ${mod.value.value.bitString}');

    await Simulator.endSimulation();
  });
}
