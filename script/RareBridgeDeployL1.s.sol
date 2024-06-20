// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {RareBridgeDeployLockAndUnlock} from "./RareBridgeDeployLockAndUnlock.s.sol";
import {RareBridgeAllowlist} from "./RareBridgeAllowlist.s.sol";
import {RareTokenL2SetMinter} from "./RareTokenL2SetMinter.s.sol";
import {RareBridgeSetExtraArgs} from "./RareBridgeSetExtraArgs.s.sol";

contract DeployRareBridgeL1 is Script, RareBridgeDeployLockAndUnlock {
  function run() external override(RareBridgeDeployLockAndUnlock) {
    // Load environment variables
    address router = vm.envAddress("CCIP_ROUTER_ADDRESS");
    address linkTokenAddress = vm.envAddress("LINK_TOKEN_ADDRESS");
    address rareTokenAddress = vm.envAddress("RARE_TOKEN_ADDRESS");

    address admin = msg.sender;

    vm.startBroadcast();

    (address rareBridgeLockAndUnlock_proxy, address rareBridgeLockAndUnlock_impl) = deployRareBridgeLockAndUnlock(
      admin,
      router,
      linkTokenAddress,
      rareTokenAddress
    );
    console2.log("Deployed RareBridgeLockAndUnlock Proxy at address: ", rareBridgeLockAndUnlock_proxy);
    console2.log("Deployed RareBridgeLockAndUnlock Implementation at address: ", rareBridgeLockAndUnlock_impl);

    vm.stopBroadcast();
  }
}
