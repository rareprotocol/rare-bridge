// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {RareBridgeDeployLockAndUnlock} from "./RareBridgeDeployLockAndUnlock.s.sol";
import {RareBridgeAllowlist} from "./RareBridgeAllowlist.s.sol";
import {RareTokenL2SetMinter} from "./RareTokenL2SetMinter.s.sol";
import {RareBridgeSetExtraArgs} from "./RareBridgeSetExtraArgs.s.sol";

contract RareBridgeConfigureL1 is Script, RareBridgeAllowlist, RareBridgeSetExtraArgs {
  function run() external override(RareBridgeAllowlist, RareBridgeSetExtraArgs) {
    // Load environment variables
    address rareBridgeAddress = vm.envAddress("RARE_BRIDGE_ADDRESS");
    address correspondentRareBridgeAddress = vm.envAddress("CORRESPONDENT_RARE_BRIDGE_ADDRESS");
    uint64 correspondentChainSelector = uint64(vm.envUint("CORRESPONDENT_CHAIN_SELECTOR"));
    uint256 correspondentChainGasLimit = vm.envUint("CORRESPONDENT_CHAIN_GAS_LIMIT");

    address admin = msg.sender;

    vm.startBroadcast();

    rareBridgeAllowlist(rareBridgeAddress, correspondentRareBridgeAddress, correspondentChainSelector);
    rareBridgeSetExtraArgs(rareBridgeAddress, correspondentChainSelector, correspondentChainGasLimit);

    vm.stopBroadcast();
  }
}
