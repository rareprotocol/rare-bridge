// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {SuperRareTokenL2} from "contracts/RareTokenL2.sol";

contract RareTokenL2Deploy is Script {
  function run() external virtual {
    // Load environment variables
    address admin = vm.envAddress("ADMIN_ADDRESS_L2");

    vm.startBroadcast();

    deployRareTokenL2(admin);

    vm.stopBroadcast();
  }

  function deployRareTokenL2(address admin) public returns (address rareTokenL2_proxy, address rareTokenL2_impl) {
    // Deploy RareBridge implementation
    rareTokenL2_impl = address(new SuperRareTokenL2());

    // Deploy Proxy
    rareTokenL2_proxy = address(
      new ERC1967Proxy(rareTokenL2_impl, abi.encodeCall(SuperRareTokenL2.initialize, (admin)))
    );
  }
}
