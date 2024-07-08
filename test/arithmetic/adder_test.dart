// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// adder_test.dart
// Tests for the Adder interface.
//
// 2024 April 4
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

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
  test('ones_complement_adder2_$n', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final input = [(15, 1), (15, -1), (-1, -15), (-15, 1)];

    for (final i in input) {
      final lvA = i.$1;
      final lvB = i.$2;
      final aSign = Logic();
      final bSign = Logic();
      aSign.put((lvA < 0) ? LogicValue.one : LogicValue.zero);
      bSign.put((lvB < 0) ? LogicValue.one : LogicValue.zero);
      a.put(lvA.abs());
      b.put(lvB.abs());
      final onesComplementAdder = OnesComplementAdder(aSign, a, bSign, b, fn);
      await onesComplementAdder.build();
      final out = onesComplementAdder.out;
      final val = onesComplementAdder.sign.value.toBool()
          ? -out.value.toInt()
          : out.value.toInt();

      final expectedSign = (lvA + lvB).sign;
      // Special modular arithmetic for 1's complement negative numbers
      //   Remember that there are two zeros in 1's complement
      final expectedMag = (lvA + lvB).abs() %
          ((expectedSign == -1) ? pow(2, n) - 1 : pow(2, n));
      final expectedVal = expectedSign == -1 ? -expectedMag : expectedMag;
      expect(val, equals(expectedVal));
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

  final generators = [Ripple.new, Sklansky.new, KoggeStone.new, BrentKung.new];
  group('adder', () {
    for (final n in [3, 4, 5]) {
      testAdder(n, RippleCarryAdder.new);
      for (final ppGen in generators) {
        testAdder(n, (a, b) => ParallelPrefixAdder(a, b, ppGen));
      }
    }
  });

  group('adderRandom', () {
    for (final n in [127, 128, 129]) {
      testAdder(n, RippleCarryAdder.new);
      for (final ppGen in generators) {
        testAdderRandom(n, 10, (a, b) => ParallelPrefixAdder(a, b, ppGen));
      }
    }
  });

  group('onesComplement', () {
    testOnesComplementAdder(4, RippleCarryAdder.new);

    for (final ppGen in generators) {
      testOnesComplementAdder(4, (a, b) => ParallelPrefixAdder(a, b, ppGen));
    }
  });

  group('exhaustive', () {
    testExhaustive(4, RippleCarryAdder.new);
    for (final ppGen in generators) {
      testExhaustive(4, (a, b) => ParallelPrefixAdder(a, b, ppGen));
    }
  });
  // TODO(desmonddak): need exhaustive test of OnesComplement which requires
  // operand a be larger than operand b
  // TODO(desmonddak): need to document/fix the OnesComplement ordering issue
  //  as it leads to the overhead of a comparison
}
