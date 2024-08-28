// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// counter_test.dart
// Tests for the counter.
//
// 2024 August 26
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  test('basic 1-bit rolling counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();

    final counter = Counter.ofLogics([Const(1)], clk: clk, reset: reset);

    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    // check initial value
    expect(counter.count.value.toInt(), 0);

    // wait a cycle, see 1
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 1);

    // wait a cycle, should overflow (1-bit counter), back to 0
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 0);

    // wait a cycle, see 1
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 1);

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

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

  test('simple counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final counter = Counter.simple(clk: clk, reset: reset, maxValue: 5);

    await counter.build();

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    expect(counter.reachedMin.value.toBool(), true);

    for (var i = 0; i < 20; i++) {
      expect(counter.count.value.toInt(), i % 6);

      if (i > 0) {
        expect(counter.reachedMin.value.toBool(), false);
      }

      if (i % 6 == 5) {
        expect(counter.reachedMax.value.toBool(), true);
      } else if (i % 6 == 0 && i > 0) {
        expect(counter.reachedMax.value.toBool(), true);
      } else {
        expect(counter.reachedMax.value.toBool(), false);
      }

      await clk.nextNegedge;
    }

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });

  test('reset and restart counter', () async {
    final clk = SimpleClockGenerator(10).clk;
    final reset = Logic();
    final restart = Logic();

    final counter = Counter(
      [
        SumInterface(fixedAmount: 4),
        SumInterface(fixedAmount: 2, increments: false),
      ],
      clk: clk,
      reset: reset,
      restart: restart,
      resetValue: 10,
      maxValue: 15,
      saturates: true,
      width: 8,
    );

    await counter.build();
    WaveDumper(counter);

    Simulator.setMaxSimTime(1000);
    unawaited(Simulator.run());

    // little reset routine
    reset.inject(0);
    restart.inject(0);
    await clk.nextNegedge;
    reset.inject(1);
    await clk.nextNegedge;
    await clk.nextNegedge;
    reset.inject(0);

    // check initial value after reset drops
    expect(counter.count.value.toInt(), 10);

    // increment each cycle
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 12);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 14);
    expect(counter.reachedMax.value.toBool(), false);

    // saturate
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 15);
    expect(counter.reachedMax.value.toBool(), true);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 15);
    expect(counter.reachedMax.value.toBool(), true);

    // restart (not reset!)
    restart.inject(1);

    // now we should catch the next +2 still, not miss it
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 12);

    // and hold there
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 12);

    // drop it and should continue
    restart.inject(0);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 14);

    // now back to reset
    reset.inject(1);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 10);
    await clk.nextNegedge;
    expect(counter.count.value.toInt(), 10);

    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;
    await clk.nextNegedge;

    await Simulator.endSimulation();
  });
}
