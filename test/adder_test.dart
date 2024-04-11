// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// adder_test.dart
// Tests for the Adder interface.
//
// 2024 April 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

// ignore_for_file: avoid_print, unnecessary_parenthesis

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void testAdder(int n, Adder Function(Logic a, Logic b) fn) {
  test('adder_$n', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final mod = fn(a, b);
    await mod.build();

    int computeAdder(int aa, int bb) => (aa + bb) & ((1 << n) - 1);
    // LogicValue computeAdderSum(LogicValue aa, LogicValue bb) =>
    //     LogicValue.ofBigInt(aa.toBigInt() + bb.toBigInt(), n + 1);
    int computeAdderSum(int aa, int bb) => aa + bb;

    // put/expect testing

    for (var aa = 0; aa < (1 << n); ++aa) {
      for (var bb = 0; bb < (1 << n); ++bb) {
        final golden = computeAdder(aa, bb);
        final goldenSum = computeAdderSum(aa, bb);
        a.put(aa);
        b.put(bb);
        final result = mod.out.value.toInt();
        final resultSum = mod.sum.value.toInt();
        //print("adder: $aa $bb $result $golden");
        expect(result, equals(golden));
        expect(resultSum, equals(goldenSum));
      }
    }
  });
}

void testAdderRandom(int n, int nSamples, Adder Function(Logic a, Logic b) fn) {
  test('adder_$n', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final mod = fn(a, b);
    await mod.build();

    LogicValue computeAdder(LogicValue aa, LogicValue bb) =>
        (aa + bb) & LogicValue.ofBigInt(BigInt.from((1 << n) - 1), n);
    LogicValue computeAdderSum(LogicValue aa, LogicValue bb) =>
        LogicValue.ofBigInt(aa.toBigInt() + bb.toBigInt(), n + 1);
    // put/expect testing

    for (var i = 0; i < nSamples; ++i) {
      final aa = Random().nextLogicValue(width: n);
      final bb = Random().nextLogicValue(width: n);
      final golden = computeAdder(aa, bb);
      final goldenSum = computeAdderSum(aa, bb);
      a.put(aa);
      b.put(bb);
      final result = mod.out.value;
      final sum = mod.sum.value;
      expect(result, equals(golden));
      expect(sum, equals(goldenSum));
    }
  });
}

void testOnesComplementAdder(int n, Adder Function(Logic a, Logic b) fn) {
  test('ones_complement_adder_$n', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final aSign = Logic();
    final bSign = Logic();
    final onesComplementAdder = OnesComplementAdder(aSign, a, bSign, b, fn);
    await onesComplementAdder.build();
    final carryOut = onesComplementAdder.sign;
    final out = onesComplementAdder.out;

    final input = [(-10, -5), (-10, 5), (10, -5), (10, 5), (4, -2)];

    for (final i in input) {
      final lvA = i.$1;
      final lvB = i.$2;

      aSign.put((lvA < 0) ? LogicValue.one : LogicValue.zero);
      bSign.put((lvB < 0) ? LogicValue.one : LogicValue.zero);
      a.put(lvA.abs());
      b.put(lvB.abs());

      final carryVal = carryOut.value.toBool();
      final val = carryVal ? -out.value.toInt() : out.value.toInt();
      print('$val versus ${lvA + lvB}  $carryVal');
      expect(val, equals(lvA + lvB));
    }
  });
}

void testOnesComplementAdder2(int n, Adder Function(Logic a, Logic b) fn) {
  test('ones_complement_adder2_$n', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final input = [(15, 1), (15, -1), (-15, -1), (-15, 1)];

    for (final i in input) {
      final lvA = i.$1;
      final lvB = i.$2;
      print('testing $lvA + $lvB');
      final aSign = Logic();
      final bSign = Logic();
      aSign.put((lvA < 0) ? LogicValue.one : LogicValue.zero);
      bSign.put((lvB < 0) ? LogicValue.one : LogicValue.zero);
      a.put(lvA.abs());
      b.put(lvB.abs());
      final onesComplementAdder = OnesComplementAdder(aSign, a, bSign, b, fn);
      await onesComplementAdder.build();
      final carryOut = onesComplementAdder.carryOut;
      final out = onesComplementAdder.out;

      final carryVal = carryOut.value.toBool();
      final val = onesComplementAdder.sign.value.toBool()
          ? -out.value.toInt()
          : out.value.toInt();
      print('h $val versus ${(lvA + lvB)}  $carryVal');
      // expect(val, equals(lvA + lvB));
    }
  });
}

void testExhaustive(int n, Adder Function(Logic a, Logic b) fn) {
  test('exhaustive adder($n)_$fn', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final adder = fn(a, b);
    await adder.build();
    final out = adder.out;

    for (var i = 0; i < pow(2, n); i += 1) {
      for (var j = 0; j < pow(2, n); j += 1) {
        a.put(i);
        b.put(j);
        final val = out.value.toInt();
        expect(val, equals((i + j) % pow(2, n)));
      }
    }
  });
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });
  // test('9 - 3', () async {
  //   final a = Logic(name: 'a', width: 5);
  //   final b = Logic(name: 'b', width: 5);

  //   a.put(3);
  //   b.put(9);
  //   final adder = OnesComplementAdder(Const(LogicValue.zero), a,
  //       Const(LogicValue.one), b, RippleCarryAdder.new);
  //   await adder.build();
  //   final out = adder.out;
  //   final val = out.value.toInt();
  //   print(val);
  // });
//
  testOnesComplementAdder2(4, RippleCarryAdder.new);
  // testExhaustive(4, RippleCarryAdder.new);
  // testExhaustive(
  //     4,
  //     (a, b) => OnesComplementAdder(Const(LogicValue.zero), a,
  //         Const(LogicValue.zero), b, RippleCarryAdder.new));
}
