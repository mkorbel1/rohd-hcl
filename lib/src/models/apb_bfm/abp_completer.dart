// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// apb_completer.dart
// An agent for completing APB requests.
//
// 2023 June 12
// Author: Max Korbel <max.korbel@intel.com>

import 'dart:async';

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/rohd_hcl.dart';
import 'package:rohd_vf/rohd_vf.dart';

/// A model for the completer side of an [ApbInterface].
class ApbCompleterAgent extends Agent {
  /// The interface to drive.
  final ApbInterface intf;

  //TODO: slverr

  /// The index that this is listening to on the [intf].
  final int selectIndex;

  /// A place where the completer should save and retrieve data.
  ///
  /// The [ApbCompleterAgent] will reset [storage] whenever the `resetN` signal is
  /// dropped.
  final MemoryStorage storage;

  /// A function which delays the response for the given `request`.
  ///
  /// If none is provided, then the delay will always be `0`.
  final int Function(ApbPacket request)? responseDelay;

  /// Creates a new model [ApbCompleterAgent].
  ApbCompleterAgent(
      {required this.intf,
      required this.storage,
      required Component parent,
      this.selectIndex = 0,
      this.responseDelay,
      String name = 'apbCompleter'})
      : super(name, parent);

  @override
  Future<void> run(Phase phase) async {
    unawaited(super.run(phase));

    intf.resetN.negedge.listen((event) {
      storage.reset();
    });

    intf.ready.inject(0);

    // wait for reset to complete
    await intf.resetN.nextPosedge;

    while (!Simulator.simulationHasEnded) {
      await _receive();
    }
  }

  /// Calculates a strobed version of data.
  LogicValue _strobeData(
          LogicValue originalData, LogicValue newData, LogicValue strobe) =>
      [
        for (var i = 0; i < strobe.width; i++)
          (strobe[i].toBool() ? newData : originalData)
              .getRange(i * 8, i * 8 + 8)
      ].rswizzle();

  /// Receives one packet (or returns if not selected).
  Future<void> _receive() async {
    await intf.enable.nextPosedge;

    if (!intf.sel[selectIndex].value.toBool()) {
      // we're not selected, wait for the next time
      return;
    }

    ApbPacket packet;
    if (intf.write.value.toBool()) {
      packet = ApbWritePacket(
        addr: intf.addr.value,
        data: intf.wData.value,
        strobe: intf.strb.value,
      );
    } else {
      packet = ApbReadPacket(addr: intf.addr.value);
    }

    if (responseDelay != null) {
      final delayCycles = responseDelay!(packet);
      if (delayCycles > 0) {
        await waitCycles(
          intf.clk,
          delayCycles,
          edge: Edge.neg,
        );
      }
    }

    if (packet is ApbWritePacket) {
      // store the data
      storage.writeData(
        packet.addr,
        _strobeData(
          storage.readData(packet.addr),
          packet.data,
          packet.strobe,
        ),
      );
      intf.ready.inject(1);
    } else if (packet is ApbReadPacket) {
      // capture the data
      Simulator.injectAction(() {
        intf.rData.put(storage.readData(packet.addr));
        intf.ready.put(1);
      });
    }

    // wait a cycle then end the transfer
    await intf.enable.nextNegedge;
    intf.ready.inject(0);
  }
}
