// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compressor.dart
// Column compression of partial prodcuts
//
// 2024 June 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:io';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';
import './random_bigInt.dart';

void testMultiplierRandom(
    int width, int iterations, Multiplier Function(Logic a, Logic b) fn) {
  test('multiplier_$width', () async {
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final mod = fn(a, b);
    await mod.build();
    final signed = mod.signed;

    BigInt computeBigIntMultiplication(BigInt aa, BigInt bb) => aa * bb;

    for (var i = 0; i < iterations; i++) {
      final bA = randomBigInt(width, signed: signed);
      final bB = randomBigInt(width, signed: signed);
      final bigGolden = computeBigIntMultiplication(bA, bB);
      a.put(bA);
      b.put(bB);
      final bigResult = signed
          ? mod.product.value.toBigInt().toSigned(mod.product.width)
          : mod.product.value.toBigInt();
      expect(bigResult, equals(bigGolden));
    }
  });
}

void testMultiplierExhaustive(int n, Multiplier Function(Logic a, Logic b) fn) {
  test('multiplier_$n', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final mod = fn(a, b);
    await mod.build();
    final signed = mod.signed;

    // We use BigInts only to provide uniformity and template for testing
    // Clearly we can only use small integers for exhaustive tests

    BigInt computeBigIntMultiplication(BigInt aa, BigInt bb) => aa * bb;

    for (var bA = BigInt.zero; bA < (BigInt.one << n); bA += BigInt.one) {
      for (var bB = BigInt.zero; bB < (BigInt.one << n); bB += BigInt.one) {
        final opA = signed ? bA.toSigned(n) : bA;
        final opB = signed ? bB.toSigned(n) : bB;

        final bigGolden = computeBigIntMultiplication(opA, opB);
        a.put(opA);
        b.put(opB);
        final bigResult = signed
            ? mod.product.value.toBigInt().toSigned(mod.product.width)
            : mod.product.value.toBigInt();
        expect(bigResult, equals(bigGolden));
      }
    }
  });
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Multiplier curryCompressionTreeMultiplier(Logic a, Logic b) =>
      CompressionTreeMultiplier(a, b, 4, KoggeStone.new);

  Multiplier currySignedCompressionTreeMultiplier(Logic a, Logic b) =>
      CompressionTreeMultiplier(a, b, 4, KoggeStone.new, signed: true);

  group('test Compression Tree Multiplier Exhaustive', () {
    const width = 5;
    testMultiplierExhaustive(width, curryCompressionTreeMultiplier);
    testMultiplierExhaustive(width, currySignedCompressionTreeMultiplier);
  });

  group('test Compression Tree Multiplier Randomly', () {
    testMultiplierRandom(4, 500, currySignedCompressionTreeMultiplier);
    testMultiplierRandom(4, 500, curryCompressionTreeMultiplier);
  });

  test('exhaustive signed mac', () async {
    const n = 4;
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);
    final c = Logic(name: 'c', width: 2 * n);
    a.put(0);
    b.put(0);
    c.put(0);

    final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4, KoggeStone.new,
        signed: true);
    BigInt computeMultiplyAccumulate(BigInt aa, BigInt bb, BigInt cc) =>
        aa * bb + cc;

    for (var aa = 0; aa < (1 << n); ++aa) {
      for (var bb = 0; bb < (1 << n); ++bb) {
        for (var cc = 0; cc < (1 << 2 * n); ++cc) {
          final bA = BigInt.from(aa).toSigned(n);
          final bB = BigInt.from(bb).toSigned(n);
          final bC = BigInt.from(cc).toSigned(2 * n);

          final golden = computeMultiplyAccumulate(bA, bB, bC);
          a.put(bA);
          b.put(bB);
          c.put(bC);
          final result =
              mod.accumulate.value.toBigInt().toSigned(mod.accumulate.width);
          if (result != golden) {
            stdout.write(
                'Failed:  $bA * $bB + $bC = $result (expected: $golden)\n');
          }
          expect(result, equals(golden));
        }
      }
    }
  });

  test('single mac', () async {
    const n = 4;
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);
    final c = Logic(name: 'c', width: 2 * n);

    BigInt computeMultiplyAccumulate(BigInt aa, BigInt bb, BigInt cc) =>
        aa * bb + cc;

    final bA = BigInt.from(1).toSigned(n);
    final bB = BigInt.from(3).toSigned(n);
    final bC = BigInt.from(128).toSigned(2 * n);
    // when the sum is 128 it fails due to sign

    final golden = computeMultiplyAccumulate(bA, bB, bC);
    a.put(bA);
    b.put(bB);
    c.put(bC);
    final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4, KoggeStone.new,
        signed: true);
    final result =
        mod.accumulate.value.toBigInt().toSigned(mod.accumulate.width);
    expect(result, equals(golden));
  });
}
