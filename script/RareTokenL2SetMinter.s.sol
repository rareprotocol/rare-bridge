// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {SuperRareTokenL2} from "contracts/RareTokenL2.sol";

contract RareTokenL2SetMinter is Script {
  function run() external virtual {
    // Load environment variables
    address rareTokenL2 = vm.envAddress("RARE_TOKEN_L2_ADDRESS");
    address tokenMinterAddress = vm.envAddress("RARE_TOKEN_L2_MINTER_ADDRESS");

    vm.startBroadcast();

    rareTokenL2SetMinter(rareTokenL2, tokenMinterAddress);

    vm.stopBroadcast();
  }

  function rareTokenL2SetMinter(address rareTokenL2, address tokenMinterAddress) public {
    SuperRareTokenL2 rareToken = SuperRareTokenL2(rareTokenL2);
    rareToken.grantRole(rareToken.MINTER_ROLE(), address(tokenMinterAddress));
  }
}
