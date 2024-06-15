// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// compressor.dart
// Column compression of partial prodcuts
//
// 2024 June 15
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:test/test.dart';

void testUnsignedMultiplier(int n, Multiplier Function(Logic a, Logic b) fn) {
  test('multiplier_$n', () async {
    final a = Logic(name: 'a', width: n);
    final b = Logic(name: 'b', width: n);

    final mod = fn(a, b);
    // TODO(desmonddak): understand why this doesn't work with build()
    //  idiom, but works without -- something about my module constructor
    // await mod.build();

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

void main() {
  tearDown(() async {
    await Simulator.reset();
  });

  Multiplier curryCompressionTreeMultiplier(Logic a, Logic b) =>
      CompressionTreeMultiplier(a, b, 4, KoggeStone.new);

  group('test Compression Tree Multiplier', () {
    const width = 5;
    testUnsignedMultiplier(width, curryCompressionTreeMultiplier);
  });
}
