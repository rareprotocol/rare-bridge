// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RareBridge} from "contracts/RareBridge.sol";

contract RareBridgeSend is Script {
  function run() external virtual {
    // Load environment variables
    address rareTokenAddress = vm.envAddress("RARE_TOKEN_ADDRESS");
    address linkTokenAddress = vm.envAddress("LINK_TOKEN_ADDRESS");
    address rareBridgeAddress = vm.envAddress("RARE_BRIDGE_ADDRESS");
    address correspondingRareBridgeAddress = vm.envAddress("CORRESPONDING_RARE_BRIDGE_ADDRESS");
    uint64 correspondingChainSelector = uint64(vm.envUint("CORRESPONDING_CHAIN_SELECTOR"));
    address[] memory recipients = vm.envAddress("RECIPIENTS", ",");
    uint256[] memory amounts = vm.envUint("AMOUNTS", ",");
    bool payFeesInLink = vm.envBool("PAY_FEES_IN_LINK");

    vm.startBroadcast();

    rareBridgeSend(
      rareTokenAddress,
      linkTokenAddress,
      rareBridgeAddress,
      correspondingRareBridgeAddress,
      correspondingChainSelector,
      recipients,
      amounts,
      payFeesInLink
    );

    vm.stopBroadcast();
  }

  function rareBridgeSend(
    address rareTokenAddress,
    address linkTokenAddress,
    address rareBridgeAddress,
    address correspondingRareBridgeAddress,
    uint64 correspondingChainSelector,
    address[] memory recipients,
    uint256[] memory amounts,
    bool payFeesInLink
  ) public {
    RareBridge rareBridge = RareBridge(payable(rareBridgeAddress));

    uint256 fee = rareBridge.getFee(
      correspondingChainSelector,
      correspondingRareBridgeAddress,
      abi.encode(recipients, amounts),
      "",
      payFeesInLink
    );

    // Calculate the total amount as the sum of the individual amounts
    uint256 totalAmount = 0;

    for (uint i = 0; i < amounts.length; ++i) {
      totalAmount += amounts[i];
    }

    console2.log(IERC20(rareTokenAddress).balanceOf(msg.sender));
    IERC20(rareTokenAddress).approve(rareBridgeAddress, totalAmount);

    if (payFeesInLink) {
      IERC20(linkTokenAddress).approve(rareBridgeAddress, fee);
      rareBridge.send(
        correspondingChainSelector,
        correspondingRareBridgeAddress,
        abi.encode(recipients, amounts),
        "",
        true
      );
    } else {
      rareBridge.send{value: fee}(
        correspondingChainSelector,
        correspondingRareBridgeAddress,
        abi.encode(recipients, amounts),
        "",
        false
      );
    }
  }
}
