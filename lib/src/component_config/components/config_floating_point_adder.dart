// Copyright (C) 2023-24 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// config_floating_point_adder.dart
// Configurator for a Floating Point Adder.
//
// 2024 April 24
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'dart:collection';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';

/// A [Configurator] for [FloatingPointAdder]s.
class FloatingPointAdderConfigurator extends Configurator {
  /// Map from Type to Function for Floating Point Adder generator
  static Map<Type,
          ParallelPrefix Function(List<Logic>, Logic Function(Logic, Logic))>
      generatorMap = {
    Ripple: Ripple.new,
    Sklansky: Sklansky.new,
    KoggeStone: KoggeStone.new,
    BrentKung: BrentKung.new
  };

  /// Controls the type of [ParallelPrefix] tree used in the adder.
  final prefixTreeKnob =
      ChoiceConfigKnob(generatorMap.keys.toList(), value: KoggeStone);

  /// Controls the width of the exponent.!
  final IntConfigKnob exponentWidthKnob = IntConfigKnob(value: 4);

  /// Controls the width of the mantissa.!
  final IntConfigKnob mantissaWidthKnob = IntConfigKnob(value: 4);

  @override
  Module createModule() => FloatingPointAdder(
      FloatingPoint(
          exponentWidth: exponentWidthKnob.value,
          mantissaWidth: mantissaWidthKnob.value),
      FloatingPoint(
          exponentWidth: exponentWidthKnob.value,
          mantissaWidth: mantissaWidthKnob.value),
      generatorMap[prefixTreeKnob.value]!);

  @override
  late final Map<String, ConfigKnob<dynamic>> knobs = UnmodifiableMapView({
    'Tree type': prefixTreeKnob,
    'Exponent width': exponentWidthKnob,
    'Mantissa width': mantissaWidthKnob,
  });

  @override
  final String name = 'Floating Point  Adder';
}
