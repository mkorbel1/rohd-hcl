// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point_test.dart
// Tests of Floating Point stuff
//
// 2024 April 1
// Authors:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com
//

import 'package:rohd_hcl/src/floating_point.dart';
import 'package:test/test.dart';

void main() {
  test('simple 32', () {
    final values = [0.15625, 12.375, -1.0, 0.25, 0.375];
    for (final val in values) {
      final fp = FloatingPoint32Value.fromDouble(val);
      assert(val == fp.toDouble(), 'mismatch');
      expect(fp.toDouble(), val);
    }
  });

  test('simple 64', () {
    final values = [0.15625, 12.375, -1.0, 0.25, 0.375];
    for (final val in values) {
      final fp = FloatingPoint64Value.fromDouble(val);
      assert(val == fp.toDouble(), 'mismatch');
      expect(fp.toDouble(), val);
    }
  });

  test('corner 32', () {
    const smallestPositiveNormal = 1.1754943508e-38;
    const largestPositiveSubnormal = 1.1754942107e-38;
    const smallestPositiveSubnormal = 1.4012984643e-45;
    const largestNormalNumber = 3.4028234664e38; // currently fails->0.0
    const largestNumberLessThanOne = 0.999999940395355225;
    const smallestNumberLargerThanOne = 1.00000011920928955;
    const oneThird = 0.333333343267440796;
    final values = [
      smallestPositiveNormal,
      largestPositiveSubnormal,
      smallestPositiveSubnormal,
      largestNormalNumber,
      largestNumberLessThanOne,
      smallestNumberLargerThanOne,
      oneThird
    ];
    for (final val in values) {
      final fp = FloatingPoint32Value.fromDouble(val);
      expect(fp.toDouble(), val);
    }
  });

  test('corner 64', () {
    const smallestPositiveNormal = 2.2250738585072014e-308;
    const largestPositiveSubnormal = 2.2250738585072009e-308;
    const smallestPositiveSubnormal = 4.9406564584124654e-324;
    const largestNormalNumber = 1.7976931348623157e308; // fails to 0.0
    // const largestNumberLessThanOne = 0.999999940395355225;
    const smallestNumberLargerThanOne = 1.0000000000000002;
    const oneThird = 0.33333333333333333;
    final values = [
      smallestPositiveNormal,
      largestPositiveSubnormal,
      smallestPositiveSubnormal,
      largestNormalNumber,
      // largestNumberLessThanOne,
      smallestNumberLargerThanOne,
      oneThird
    ];
    for (final val in values) {
      final fp = FloatingPoint64Value.fromDouble(val);
      expect(fp.toDouble(), val);
    }
  });

  test('putting values onto a signal', () {
    FloatingPoint32 fp = FloatingPoint32();

    fp.put(FloatingPoint32Value.fromDouble(1.5).value);

    expect(fp.floatingPointValue.toDouble(), 1.5);
  });
}
