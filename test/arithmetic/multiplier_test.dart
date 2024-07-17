// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compressor.dart
// Column compression of partial prodcuts
//
// 2024 June 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';
import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void runSingleMultiply(Multiplier mod, BigInt bA, BigInt bB) {
  final golden = bA * bB;
  // ignore: invalid_use_of_protected_member
  mod.a.put(bA);
  // ignore: invalid_use_of_protected_member
  mod.b.put(bB);
  final result = mod.signed
      ? mod.product.value.toBigInt().toSigned(mod.product.width)
      : mod.product.value.toBigInt();
  expect(result, equals(golden));
}

void testMultiplierRandom(
    int width, int iterations, Multiplier Function(Logic a, Logic b) fn) {
  final a = Logic(name: 'a', width: width);
  final b = Logic(name: 'b', width: width);
  final mod = fn(a, b);
  test('random_${mod.definitionName}_S${mod.signed}_W${width}_I$iterations',
      () async {
    // final mod = fn(a, b);
    await mod.build();
    final signed = mod.signed;

    for (var i = 0; i < iterations; i++) {
      // final bA = randomBigInt(width, signed: signed);
      final bA = signed
          ? Random().nextLogicValue(width: width).toBigInt().toSigned(width)
          : Random().nextLogicValue(width: width).toBigInt().toUnsigned(width);
      // final bB = randomBigInt(width, signed: signed);
      final bB = signed
          ? Random().nextLogicValue(width: width).toBigInt().toSigned(width)
          : Random().nextLogicValue(width: width).toBigInt().toUnsigned(width);
      runSingleMultiply(mod, bA, bB);
    }
  });
}

void testMultiplierExhaustive(
    int width, Multiplier Function(Logic a, Logic b) fn) {
  final a = Logic(name: 'a', width: width);
  final b = Logic(name: 'b', width: width);
  final mod = fn(a, b);
  test('exhaustive_${mod.definitionName}_S${mod.signed}_W$width', () async {
    await mod.build();
    final signed = mod.signed;

    // We use BigInts only to provide uniformity and template for testing
    // Clearly we can only use small integers for exhaustive tests
    for (var bA = BigInt.zero; bA < (BigInt.one << width); bA += BigInt.one) {
      for (var bB = BigInt.zero; bB < (BigInt.one << width); bB += BigInt.one) {
        final opA = signed ? bA.toSigned(width) : bA;
        final opB = signed ? bB.toSigned(width) : bB;
        runSingleMultiply(mod, opA, opB);
      }
    }
  });
}

void runSingleMultiplyAccumulate(
    MultiplyAccumulate mod, BigInt bA, BigInt bB, BigInt bC) {
  final golden = bA * bB + bC;
  // ignore: invalid_use_of_protected_member
  mod.a.put(bA);
  // ignore: invalid_use_of_protected_member
  mod.b.put(bB);
  // ignore: invalid_use_of_protected_member
  mod.c.put(bC);
  // print('$bA, $bB, $bC');

  final result = mod.signed
      ? mod.accumulate.value.toBigInt().toSigned(mod.accumulate.width)
      : mod.accumulate.value.toBigInt().toUnsigned(mod.accumulate.width);
  expect(result, equals(golden));
}

void testMultiplyAccumulateRandom(int width, int iterations,
    MultiplyAccumulate Function(Logic a, Logic b, Logic c) fn) {
  final a = Logic(name: 'a', width: width);
  final b = Logic(name: 'b', width: width);
  final c = Logic(name: 'c', width: width * 2);
  final mod = fn(a, b, c);
  test('random_${mod.definitionName}_S${mod.signed}_W${width}_I$iterations',
      () async {
    await mod.build();
    final signed = mod.signed;
    for (var i = 0; i < iterations; i++) {
      // final bA = randomBigInt(width, signed: signed);
      // final bB = randomBigInt(width, signed: signed);
      // final bC = randomBigInt(width * 2, signed: signed);
      final bA = signed
          ? Random().nextLogicValue(width: width).toBigInt().toSigned(width)
          : Random().nextLogicValue(width: width).toBigInt().toUnsigned(width);
      // final bB = randomBigInt(width, signed: signed);
      final bB = signed
          ? Random().nextLogicValue(width: width).toBigInt().toSigned(width)
          : Random().nextLogicValue(width: width).toBigInt().toUnsigned(width);
      final bC = signed
          ? Random().nextLogicValue(width: width).toBigInt().toSigned(width)
          : Random().nextLogicValue(width: width).toBigInt().toUnsigned(width);

      runSingleMultiplyAccumulate(mod, bA, bB, bC);
    }
  });
}

void testMultiplyAccumulateExhaustive(
    int width, MultiplyAccumulate Function(Logic a, Logic b, Logic c) fn) {
  final a = Logic(name: 'a', width: width);
  final b = Logic(name: 'b', width: width);
  final c = Logic(name: 'c', width: 2 * width);
  final mod = fn(a, b, c);
  test('exhaustive_${mod.definitionName}_S${mod.signed}_W$width', () async {
    await mod.build();
    final signed = mod.signed;

    for (var aa = 0; aa < (1 << width); ++aa) {
      for (var bb = 0; bb < (1 << width); ++bb) {
        for (var cc = 0; cc < (1 << (2 * width)); ++cc) {
          final bA = signed
              ? BigInt.from(aa).toSigned(width)
              : BigInt.from(aa).toUnsigned(width);
          final bB = signed
              ? BigInt.from(bb).toSigned(width)
              : BigInt.from(bb).toUnsigned(width);
          final bC = signed
              ? BigInt.from(cc).toSigned(2 * width)
              : BigInt.from(cc).toUnsigned(2 * width);

          runSingleMultiplyAccumulate(mod, bA, bB, bC);
        }
      }
    }
  });
}

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Multiplier curryUnsignedCompressionTreeMultiplier(Logic a, Logic b) =>
      CompressionTreeMultiplier(a, b, 4, KoggeStone.new);

  Multiplier currySignedCompressionTreeMultiplier(Logic a, Logic b) =>
      CompressionTreeMultiplier(a, b, 4, KoggeStone.new, signed: true);

  group('test Compression Tree Multiplier Randomly', () {
    for (final width in [4, 5, 6, 11]) {
      testMultiplierRandom(width, 100, currySignedCompressionTreeMultiplier);
      testMultiplierRandom(width, 100, curryUnsignedCompressionTreeMultiplier);
    }
  });
  group('test Compression Tree Multiplier Exhaustive', () {
    for (final width in [4, 5]) {
      testMultiplierExhaustive(width, currySignedCompressionTreeMultiplier);
      testMultiplierExhaustive(width, curryUnsignedCompressionTreeMultiplier);
    }
  });

  MultiplyAccumulate curryUnsignedCompressionTreeMultiplyAccumulate(
          Logic a, Logic b, Logic c) =>
      CompressionTreeMultiplyAccumulate(a, b, c, 4, KoggeStone.new);

  MultiplyAccumulate currySignedCompressionTreeMultiplyAccumulate(
          Logic a, Logic b, Logic c) =>
      CompressionTreeMultiplyAccumulate(a, b, c, 4, KoggeStone.new,
          signed: true);

  group('test Multiply Accumulate Random', () {
    for (final width in [4, 5, 6, 11]) {
      testMultiplyAccumulateRandom(
          width, 100, curryUnsignedCompressionTreeMultiplyAccumulate);
      testMultiplyAccumulateRandom(
          width, 100, currySignedCompressionTreeMultiplyAccumulate);
    }
  });
  group('test Multiply Accumulate Exhaustive', () {
    for (final width in [3, 4]) {
      testMultiplyAccumulateExhaustive(
          width, curryUnsignedCompressionTreeMultiplyAccumulate);
      testMultiplyAccumulateExhaustive(
          width, currySignedCompressionTreeMultiplyAccumulate);
    }
  });

  test('single mac', () async {
    const width = 6;
    final a = Logic(name: 'a', width: width);
    final b = Logic(name: 'b', width: width);
    final c = Logic(name: 'c', width: 2 * width);

    const av = 0;
    const bv = 0;
    const cv = -512;
    for (final signed in [true, false]) {
      final bA = signed
          ? BigInt.from(av).toSigned(width)
          : BigInt.from(av).toUnsigned(width);
      final bB = signed
          ? BigInt.from(bv).toSigned(width)
          : BigInt.from(bv).toUnsigned(width);
      final bC = signed
          ? BigInt.from(cv).toSigned(2 * width)
          : BigInt.from(cv).toUnsigned(width * 2);

      // Set these so that printing inside module build will have Logic values
      a.put(bA);
      b.put(bB);
      c.put(bC);

      final mod = CompressionTreeMultiplyAccumulate(a, b, c, 4, KoggeStone.new,
          signed: signed);
      runSingleMultiplyAccumulate(mod, bA, bB, bC);
    }
  });
}
