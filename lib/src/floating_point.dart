// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// floating_point.dart
// Implementation of Floating Point stuff
//
// 2023 July 11
// Author:
//  Max Korbel <max.korbel@intel.com>
//  Desmond A Kirkpatrick <desmond.a.kirkpatrick@intel.com
//

import 'package:rohd/rohd.dart';

class FloatingPoint extends LogicStructure {
  final Logic exponent;
  final Logic mantissa;
  final Logic sign;

  FloatingPoint._(this.sign, this.exponent, this.mantissa, {String? name})
      : super([mantissa, exponent, sign], name: name ?? 'FloatingPoint');

  FloatingPoint(
      {required int exponentWidth, required int mantissaWidth, String? name})
      : this._(
            Logic(name: 'sign'),
            Logic(width: exponentWidth, name: 'exponent'),
            Logic(width: mantissaWidth, name: 'mantissa'));

  @override
  FloatingPoint clone({String? name}) => FloatingPoint(
        exponentWidth: exponent.width,
        mantissaWidth: mantissa.width,
        name: name,
      );

  String valueFloatingPointString() => value.isValid
      ? '${sign.value.toBool() ? '-' : ''}'
          '${mantissa.value.toInt() + (1 << 23)}'
          'e${exponent.value.toInt() - 127}'
      : value.toString();

  double? valueFloatingPoint() => double.tryParse(valueFloatingPointString());
}

class FloatingPoint64 extends FloatingPoint {
  FloatingPoint64() : super(exponentWidth: 11, mantissaWidth: 52);
}

class FloatingPoint32 extends FloatingPoint {
  FloatingPoint32() : super(exponentWidth: 8, mantissaWidth: 23);
}

void main() {
  final fp = FloatingPoint32()
    ..exponent.put(0x7c)
    ..mantissa.put(1 << 21)
    ..sign.put(0);
  print(fp.exponent.value.toString(includeWidth: false));
  print(fp.exponent.value.toInt());
  print(fp.mantissa.value.toString(includeWidth: false));
  print(fp.mantissa.value.toInt());
  print(fp.value.toString(includeWidth: false));
  print(fp.valueFloatingPointString());
  print(fp.valueFloatingPoint());
}
