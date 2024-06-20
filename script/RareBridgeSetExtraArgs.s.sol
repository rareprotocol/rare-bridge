// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {RareBridge} from "contracts/RareBridge.sol";

contract RareBridgeSetExtraArgs is Script {
  function run() external virtual {
    // Load environment variables
    address rareBridgeAddress = vm.envAddress("RARE_BRIDGE_ADDRESS");
    uint64 correspondentChainSelector = uint64(vm.envUint("CORRESPONDENT_CHAIN_SELECTOR"));
    uint256 correspondentChainGasLimit = vm.envUint("CORRESPONDENT_CHAIN_GAS_LIMIT");

    vm.startBroadcast();

    rareBridgeSetExtraArgs(rareBridgeAddress, correspondentChainSelector, correspondentChainGasLimit);

    vm.stopBroadcast();
  }

  function rareBridgeSetExtraArgs(address rareBridgeAddress, uint64 chainSelector, uint256 gasLimit) public {
    RareBridge rareBridge = RareBridge(payable(rareBridgeAddress));
    rareBridge.setExtraArgs(chainSelector, gasLimit);
  }
}
