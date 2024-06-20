// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RareBridge} from "contracts/RareBridge.sol";
import {RareBridgeBurnAndMint} from "contracts/RareBridgeBurnAndMint.sol";

contract DeployRareBridgeBurnAndMint is Script {
  function run() external virtual {
    // Load environment variables
    address admin = vm.envAddress("ADMIN_ADDRESS");
    address router = vm.envAddress("CCIP_ROUTER_ADDRESS_L2");
    address linkToken = vm.envAddress("LINK_TOKEN_ADDRESS_L2");
    address rareToken = vm.envAddress("RARE_TOKEN_ADDRESS_L2");

    vm.startBroadcast();

    deployRareBridgeBurnAndMint(admin, router, linkToken, rareToken);

    vm.stopBroadcast();
  }

  function deployRareBridgeBurnAndMint(
    address admin,
    address router,
    address linkToken,
    address rareToken
  ) public returns (address rareBridgeBurnAndMint_proxy, address rareBridgeBurnAndMint_impl) {
    // Deploy RareBridge implementation
    rareBridgeBurnAndMint_impl = address(new RareBridgeBurnAndMint());

    // Deploy Proxy
    rareBridgeBurnAndMint_proxy = address(
      new ERC1967Proxy(
        rareBridgeBurnAndMint_impl,
        abi.encodeCall(RareBridge.initialize, (address(router), address(linkToken), address(rareToken), admin))
      )
    );
  }
}
