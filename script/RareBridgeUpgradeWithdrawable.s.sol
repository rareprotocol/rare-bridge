// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {RareBridge} from "contracts/RareBridge.sol";
import {RareBridgeWithdrawable} from "contracts/upgrades/RareBridgeWithdrawable.sol";

// This is example script to upgrade RareBridge contract
// You can refer to it to create your own upgrade script
contract RareBridgeUpgradeWithdrawable is Script {
  function run() external {
    // Load environment variables
    address rareBridgeAddress = vm.envAddress("RARE_BRIDGE_ADDRESS");

    vm.startBroadcast();

    // Deploy new RareBridge implementation
    RareBridgeWithdrawable rareBridgeWithdrawable = new RareBridgeWithdrawable();

    // Update proxy to point to new implementation
    RareBridge(payable(rareBridgeAddress)).upgradeToAndCall(address(rareBridgeWithdrawable), "");

    vm.stopBroadcast();
  }
}
