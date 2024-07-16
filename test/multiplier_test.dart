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

void testUnsignedMultiplier(int n, Multiplier Function(Logic a, Logic b) fn) {
  test('multiplier_$n', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final mod = fn(a, b);
    await mod.build();

    int computeMultiplication(int aa, int bb) => aa * bb;

    // put/expect testing

    for (var aa = 0; aa < (1 << n); ++aa) {
      for (var bb = 0; bb < (1 << n); ++bb) {
        final golden = computeMultiplication(aa, bb);
        a.put(aa);
        b.put(bb);
        final result = mod.product.value.toInt();
        expect(result, equals(golden));
      }
    }
  });
}

void testSignedMultiplier(int n, Multiplier Function(Logic a, Logic b) fn) {
  test('multiplier_$n', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final mod = fn(a, b);
    BigInt computeMultiplication(BigInt aa, BigInt bb) => aa * bb;

    for (var aa = 0; aa < (1 << n); ++aa) {
      for (var bb = 0; bb < (1 << n); ++bb) {
        final bA = BigInt.from(aa).toSigned(n);
        final bB = BigInt.from(bb).toSigned(n);

        final golden = computeMultiplication(bA, bB);
        a.put(bA);
        b.put(bB);
        final result = mod.product.value.toBigInt().toSigned(mod.product.width);
        expect(result, equals(golden));
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

  group('test Compression Tree Multiplier', () {
    const width = 5;
    testUnsignedMultiplier(width, curryCompressionTreeMultiplier);
    testSignedMultiplier(width, currySignedCompressionTreeMultiplier);
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

    final bA = BigInt.from(0).toSigned(n);
    final bB = BigInt.from(0).toSigned(n);
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
    stdout.write('expecting $golden\n');
    expect(result, equals(golden));
  });
}
