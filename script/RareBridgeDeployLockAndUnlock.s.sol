// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RareBridge} from "contracts/RareBridge.sol";
import {RareBridgeLockAndUnlock} from "contracts/RareBridgeLockAndUnlock.sol";

contract RareBridgeDeployLockAndUnlock is Script {
  function run() external virtual {
    // Load environment variables
    address admin = vm.envAddress("ADMIN_ADDRESS");
    address router = vm.envAddress("CCIP_ROUTER_ADDRESS");
    address linkToken = vm.envAddress("LINK_TOKEN_ADDRESS");
    address rareToken = vm.envAddress("RARE_TOKEN_ADDRESS");

    vm.startBroadcast();

    deployRareBridgeLockAndUnlock(admin, router, linkToken, rareToken);

    vm.stopBroadcast();
  }

  function deployRareBridgeLockAndUnlock(
    address admin,
    address router,
    address linkToken,
    address rareToken
  ) public returns (address rareBridgeLockAndUnlock_proxy, address rareBridgeLockAndUnlock_impl) {
    // Deploy RareBridge implementation
    rareBridgeLockAndUnlock_impl = address(new RareBridgeLockAndUnlock());

    // Deploy Proxy
    rareBridgeLockAndUnlock_proxy = address(
      new ERC1967Proxy(
        rareBridgeLockAndUnlock_impl,
        abi.encodeCall(RareBridge.initialize, (address(router), address(linkToken), address(rareToken), admin))
      )
    );
  }
}
