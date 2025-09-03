// Copyright (C) 2025 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// static_or_runtime_parameter.dart
// Configuration classes for managing parameters that can be set statically or
// at runtime.
//
// 2025 June 27
// Author: Desmond Kirkpatrick <desmond.a.kirkpatrick@intel.com>

import 'package:meta/meta.dart';
import 'package:rohd/rohd.dart';

/// A general configuration class for specifying parameters that are
/// for both static or runtime configurations of a component feature.
abstract class StaticOrRuntimeParameter<ParamType> {
  final ParamType config;

  /// The name of the configuration, especially needed for runtime to add as
  /// a module input.
  final String name;

  /// Creates a new [StaticOrRuntimeParameter] instance.
  StaticOrRuntimeParameter({required this.name, required this.config});

  /// Factory constructor to create a [StaticOrRuntimeParameter] instance from a
  /// dynamic.
  ///
  /// Only accepts [Logic]s or types compatible with [LogicValue.of].
  ///
  /// If a [defaultConfig] is provided, then if [config] is null, the
  /// [defaultConfig] will be used.
  static StaticOrRuntimeParameter<dynamic>? ofDynamic(dynamic config,
      {required String name, dynamic defaultConfig}) {
    if (config == null) {
      if (defaultConfig != null) {
        return ofDynamic(defaultConfig, name: name);
      }

      return null;
    } else if (config is Logic) {
      return RuntimeConfig(config, name: name);
    } else {
      return StaticConfig(config, name: name);
    }
  }

  /// Return a string representation of the configuration, including its name.
  @override
  String toString() => 'Parameter_$name';

  /// Return a `bool` representing the value of the configuration.
  @visibleForTesting
  LogicValue get value;

  /// Return the internal [Logic] signal that represents the configuration,
  /// either static or runtime.
  Logic getLogic(Module module);

  /// If this is a 1-bit or `bool` configuration, then selects [whenTrue] if it
  /// is `true` or high, and [whenFalse] if it is `false` or low.
  Logic boolSelect(Logic whenTrue, Logic whenFalse) {
    if (this is StaticConfig) {
      return (this as StaticConfig).value.toBool() ? whenTrue : whenFalse;
    } else {
      return mux(config as Logic, whenTrue, whenFalse);
    }
  }

  /// Provides a version of [config] that can safely be used in the [module]'s
  /// context.
  ParamType configInContext(Module module);
}

class StaticConfig<StaticType> extends StaticOrRuntimeParameter<StaticType> {
  /// Creates a new [StaticConfig] instance.
  StaticConfig(StaticType config, {required super.name})
      : super(config: config);

  @override
  Logic getLogic(Module module) => Const(LogicValue.ofInferWidth(config));

  @override
  LogicValue get value => LogicValue.ofInferWidth(config);

  @override
  StaticType configInContext(Module module) => config;
}

/// A configuration class for runtime configurations, which can be used to
/// dynamically configure a component at runtime.
class RuntimeConfig<LogicType extends Logic>
    extends StaticOrRuntimeParameter<LogicType> {
  /// Creates a new [RuntimeConfig] instance.
  RuntimeConfig(LogicType config, {required super.name})
      : super(config: config);

  @override
  Logic getLogic(Module module) =>
      module.tryInput(name) ?? module.addTypedInput(name, config);

  @override
  @visibleForTesting
  LogicValue get value => config.value;

  @override
  LogicType configInContext(Module module) => getLogic(module) as LogicType;
}
