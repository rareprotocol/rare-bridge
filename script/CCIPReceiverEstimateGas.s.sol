// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract CCIPReceiverEstimateGas is Script {
  function run() external virtual {
    // Load environment variables
    string memory rpcUrl = vm.envString("RPC_URL");
    address sourceRareBridgeAddress = vm.envAddress("SOURCE_RARE_BRIDGE_ADDRESS");
    uint64 sourceChainSelector = uint64(vm.envUint("SOURCE_CHAIN_SELECTOR"));
    address ccipRouterAddress = vm.envAddress("CCIP_ROUTER_ADDRESS");
    address ccipReceiverAddress = vm.envAddress("CCIP_RECEIVER_ADDRESS");
    bool autoPrepareScenario = vm.envBool("AUTO_PREPARE_SCENARIO");
    uint256 numRecipients = vm.envUint("NUM_RECIPIENTS");

    address[] memory recipients;
    uint256[] memory amounts;

    if (autoPrepareScenario) {
      (recipients, amounts) = prepareScenario(numRecipients);
    } else {
      recipients = vm.envAddress("RECIPIENTS", ",");
      amounts = vm.envUint("AMOUNTS", ",");
    }

    ccipReceiverEstimateGas(
      rpcUrl,
      sourceRareBridgeAddress,
      sourceChainSelector,
      ccipRouterAddress,
      ccipReceiverAddress,
      recipients,
      amounts
    );
  }

  function ccipReceiverEstimateGas(
    string memory rpcUrl,
    address sourceRareBridgeAddress,
    uint64 sourceChainSelector,
    address ccipRouterAddress,
    address ccipReceiverAddress,
    address[] memory recipients,
    uint256[] memory amounts
  ) public {
    uint256 forkId = vm.createFork(rpcUrl);
    vm.selectFork(forkId);

    Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
      messageId: "0",
      sourceChainSelector: sourceChainSelector,
      sender: abi.encode(sourceRareBridgeAddress),
      data: abi.encode(recipients, amounts),
      destTokenAmounts: new Client.EVMTokenAmount[](0)
    });

    vm.prank(ccipRouterAddress);
    CCIPReceiver(ccipReceiverAddress).ccipReceive(message);

    console2.log("Num of recipients:", recipients.length);
    console2.log("Message size in bytes:", message.data.length);
  }

  function prepareScenario(uint256 numRecipients) public pure returns (address[] memory, uint256[] memory) {
    address[] memory recipients = new address[](numRecipients);
    uint256[] memory amounts = new uint256[](numRecipients);

    for (uint i = 0; i < numRecipients; ++i) {
      recipients[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
      amounts[i] = 1 ether;
    }

    return (recipients, amounts);
  }
}
