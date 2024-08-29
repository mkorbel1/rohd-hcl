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
import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_hcl/src/deserializer.dart';
import 'package:rohd_hcl/src/serializer.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  test('serializer', () async {
    const len = 10;
    const width = 8;
    final dataIn = LogicArray([len], width);
    final clk = SimpleClockGenerator(10).clk;
    final start = Logic();
    final reset = Logic();
    final mod = Serializer(dataIn, clk: clk, reset: reset, readyIn: start);

    await mod.build();

    WaveDumper(mod);

    unawaited(Simulator.run());

    start.inject(0);
    reset.inject(0);
    var clkCount = 0;
    for (var i = 0; i < len; i++) {
      dataIn.elements[i].inject(i);
    }
    print('dataIn[3]= ${dataIn.elements[3].value.bitString}');
    print('dataInFull ${dataIn.reversed.value.bitString}');
    await clk.nextPosedge;
    print('initial ${mod.count.value}');

    reset.inject(1);

    await clk.nextPosedge;
    print('reset: ${mod.serialized.value.bitString} cnt=${mod.count.value}');

    reset.inject(0);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;
    print('unreset: ${mod.serialized.value.bitString} cnt=${mod.count.value}');
    start.inject(1);
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

  test('deserializer', () async {
    const len = 6;
    const width = 8;
    final dataIn = Logic(width: width);
    final clk = SimpleClockGenerator(10).clk;
    final start = Logic();
    final reset = Logic();
    final mod =
        Deserializer(dataIn, len, clk: clk, reset: reset, validIn: start);
    await mod.build();
    unawaited(Simulator.run());
    WaveDumper(mod);

    start.inject(0);
    reset.inject(0);
    var clkCount = 0;
    await clk.nextPosedge;
    print('initial: ${mod.deserialized.value.bitString}, '
        'count: ${mod.count.value.bitString}');

    reset.inject(1);

    await clk.nextPosedge;
    print('reset:   ${mod.deserialized.value.bitString}, '
        'count: ${mod.count.value.bitString}');

    reset.inject(0);
    dataIn.inject(255);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;
    print('unreset: ${mod.deserialized.value.bitString}, '
        'count: ${mod.count.value.bitString}');
    start.inject(1);
    await clk.nextPosedge;
    clkCount++;
    print('$clkCount:\t${mod.deserialized.value.bitString}, '
        'count: ${mod.count.value.bitString}');

    // start.inject(0);

    for (var i = 0; i < 11; i++) {
      if (i < 5) {
        dataIn.inject(255);
      } else {
        dataIn.inject(0);
      }
      await clk.nextPosedge;
      clkCount++;
      print('$clkCount:\t${mod.deserialized.value.bitString}, '
          'count: ${mod.count.value.bitString}');
    }

    await Simulator.endSimulation();
  });

  test('deserializer rollover', () async {
    const len = 6;
    const width = 4;
    final dataIn = Logic(width: width);
    final clk = SimpleClockGenerator(10).clk;
    final enable = Logic();
    final reset = Logic();
    final mod =
        Deserializer(dataIn, len, clk: clk, reset: reset, validIn: enable);

    await mod.build();
    unawaited(Simulator.run());

    enable.inject(0);
    reset.inject(0);
    await clk.nextPosedge;
    reset.inject(1);

    var clkCount = 0;
    await clk.nextPosedge;
    reset.inject(0);
    dataIn.inject(255);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;
    enable.inject(1);
    await clk.nextPosedge;
    clkCount++;
    // print('$clkCount:\tcount: ${mod.count.value.bitString}'
    //     '\t${mod.deserialized.value.bitString} '
    //     '(${mod.deserialized.value.toBigInt()})');
    var value = BigInt.from(15) << ((len - 1) * width);
    expect(mod.count.value.toInt(), equals(clkCount));
    expect(mod.deserialized.value.toBigInt(), equals(value));
    for (var i = 0; i < len * 2 - 2; i++) {
      BigInt nxtValue;
      if (i < len - 1) {
        dataIn.inject(15);
        nxtValue = (value >> width) | value;
        if (i == len - 2) {
          clkCount = -1;
        }
      } else {
        dataIn.inject(0);
        nxtValue = value >> width;
      }
      await clk.nextPosedge;
      clkCount++;
      expect(mod.count.value.toInt(), equals(clkCount));
      expect(mod.deserialized.value.toBigInt(), equals(nxtValue));
      // print('$clkCount:\tcount: ${mod.count.value.bitString}'
      //     '\t${mod.deserialized.value.bitString} '
      //     '(${mod.deserialized.value.toBigInt()})=$nxtValue');
      value = nxtValue;
    }

    await Simulator.endSimulation();
  });

  test('deserializer enable', () async {
    //TODO(desmonddak): this test is not working yet active is off
    const len = 6;
    const width = 4;
    final dataIn = Logic(width: width);
    final clk = SimpleClockGenerator(10).clk;
    final enable = Logic();
    final reset = Logic();
    final mod =
        Deserializer(dataIn, len, clk: clk, reset: reset, validIn: enable);
    await mod.build();
    unawaited(Simulator.run());

    enable.inject(0);
    reset.inject(0);
    await clk.nextPosedge;
    reset.inject(1);

    await clk.nextPosedge;
    reset.inject(0);
    dataIn.inject(255);
    await clk.nextPosedge;
    await clk.nextPosedge;
    await clk.nextPosedge;

    enable.inject(1);
    var counting = true;
    for (var disablePos = 0; disablePos < len * 2 - 3; disablePos++) {
      var activeClkCount = 0;
      var clkCount = 0;
      if (clkCount == disablePos) {
        counting = false;
        enable.inject(0);
      } else {
        counting = true;
      }
      await clk.nextPosedge;
      clkCount++;
      activeClkCount = counting ? activeClkCount + 1 : activeClkCount;

      print('$activeClkCount:\tcount: ${mod.count.value.bitString}'
          '\t${mod.deserialized.value.bitString} '
          '(${mod.deserialized.value.toBigInt()})');
      var value = BigInt.from(15) << ((len - 1) * width);
      // expect(mod.count.value.toInt(), equals(activeClkCount));
      // expect(mod.deserialized.value.toBigInt(), equals(value));
      for (var i = 0; i < len * 2; i++) {
        if (clkCount == disablePos) {
          counting = false;
          enable.inject(0);
        } else {
          counting = true;
        }
        BigInt nxtValue;
        if (i < len - 1) {
          dataIn.inject(15);
          nxtValue = (value >> width) | value;
          if (i == len - 2) {
            clkCount = -1;
            activeClkCount = -1;
          }
        } else {
          dataIn.inject(0);
          nxtValue = value >> width;
        }
        await clk.nextPosedge;
        clkCount++;
        activeClkCount = counting ? activeClkCount + 1 : activeClkCount;
        // expect(mod.count.value.toInt(), equals(activeClkCount));
        // expect(mod.deserialized.value.toBigInt(), equals(nxtValue));
        print('$activeClkCount:\tcount: ${mod.count.value.bitString}'
            '\t${mod.deserialized.value.bitString} '
            '(${mod.deserialized.value.toBigInt()})=$nxtValue');
        value = nxtValue;
        enable.inject(1);
      }
    }

    await Simulator.endSimulation();
  });
}
