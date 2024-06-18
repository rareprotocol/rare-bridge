// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {RareBridge} from "contracts/RareBridge.sol";

contract RareBridgeAllowlist is Script {
  function run() external virtual {
    // Load environment variables
    address rareBridgeAddress = vm.envAddress("RARE_BRIDGE_ADDRESS");
    address correspondentRareBridgeAddress = vm.envAddress("CORRESPONDENT_RARE_BRIDGE_ADDRESS");
    uint64 chainSelector = uint64(vm.envUint("CHAIN_SELECTOR"));

    vm.startBroadcast();

    rareBridgeAllowlist(rareBridgeAddress, correspondentRareBridgeAddress, chainSelector);

    vm.stopBroadcast();
  }

  function rareBridgeAllowlist(
    address rareBridgeAddress,
    address correspondentRareBridge,
    uint64 chainSelector
  ) public {
    RareBridge rareBridge = RareBridge(payable(rareBridgeAddress));
    rareBridge.allowlistSender(chainSelector, correspondentRareBridge, true);
    rareBridge.allowlistRecipient(chainSelector, correspondentRareBridge, true);
  }
}
