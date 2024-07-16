// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// random_bigint.dart
// Generator for random BigInts
//
// 2024 July 8
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:math';
import 'dart:typed_data';

// Copy a single utility 'decodeBigInt' taken from
//// https://github.com/bcgit/pc-dart/blob/master/lib/src/utils.dart#L19
//
// LICENSE:
// Copyright (c) 2000 - 2019 The Legion of the Bouncy Castle Inc. (https://www.bouncycastle.org)

// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

/// Decode a BigInt from bytes in big-endian encoding.
/// Twos compliment.
/// DAK:  Modified for signed/unsigned decoding
BigInt decodeBigInt(List<int> bytes, {bool signed = false}) {
  final negative = signed & bytes.isNotEmpty && bytes[0] & 0x80 == 0x80;

  BigInt result;

  if (bytes.length == 1) {
    result = BigInt.from(bytes[0]);
  } else {
    result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      final item = bytes[bytes.length - i - 1];
      result |= BigInt.from(item) << (8 * i);
    }
  }
  return result != BigInt.zero
      ? negative
          ? result.toSigned(result.bitLength)
          : result
      : BigInt.zero;
}

BigInt randomBigInt(int bitLength, {bool signed = false}) {
  final random = Random.secure();
  final builder = BytesBuilder();
  final size = (bitLength / 8).ceil();
  for (var i = 0; i < size; ++i) {
    builder.addByte(random.nextInt(256));
  }
  final bytes = builder.toBytes();
  final fullBigInt = decodeBigInt(bytes);
  return signed
      ? fullBigInt.toSigned(bitLength)
      : fullBigInt.toUnsigned(bitLength);
}
