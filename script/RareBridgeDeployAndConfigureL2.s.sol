// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {RareTokenL2Deploy} from "./RareTokenL2Deploy.s.sol";
import {DeployRareBridgeBurnAndMint} from "./RareBridgeDeployBurnAndMint.s.sol";
import {RareBridgeAllowlist} from "./RareBridgeAllowlist.s.sol";
import {RareTokenL2SetMinter} from "./RareTokenL2SetMinter.s.sol";
import {RareBridgeSetExtraArgs} from "./RareBridgeSetExtraArgs.s.sol";

contract DeployAndConfigureRareBridgeL2 is
  Script,
  RareTokenL2Deploy,
  DeployRareBridgeBurnAndMint,
  RareBridgeAllowlist,
  RareTokenL2SetMinter,
  RareBridgeSetExtraArgs
{
  function run()
    external
    override(
      RareTokenL2Deploy,
      DeployRareBridgeBurnAndMint,
      RareBridgeAllowlist,
      RareTokenL2SetMinter,
      RareBridgeSetExtraArgs
    )
  {
    // Load environment variables
    address router = vm.envAddress("CCIP_ROUTER_ADDRESS");
    address linkTokenAddress = vm.envAddress("LINK_TOKEN_ADDRESS");
    address correspondentRareBridgeAddress = vm.envAddress("CORRESPONDENT_RARE_BRIDGE_ADDRESS");
    uint64 correspondentChainSelector = uint64(vm.envUint("CORRESPONDENT_CHAIN_SELECTOR"));
    uint256 correspondentChainGasLimit = vm.envUint("CORRESPONDENT_CHAIN_GAS_LIMIT");

    address admin = msg.sender;

    vm.startBroadcast();

    (address rareTokenL2_proxy, address rareTokenL2_impl) = deployRareTokenL2(admin);
    console2.log("Deployed RareTokenL2 Proxy at address: ", rareTokenL2_proxy);
    console2.log("Deployed RareTokenL2 Implementation at address: ", rareTokenL2_impl);

    (address rareBridgeBurnAndMint_proxy, address rareBridgeBurnAndMint_impl) = deployRareBridgeBurnAndMint(
      admin,
      router,
      linkTokenAddress,
      rareTokenL2_proxy
    );
    console2.log("Deployed RareBridgeBurnAndMint Proxy at address: ", rareBridgeBurnAndMint_proxy);
    console2.log("Deployed RareBridgeBurnAndMint Implementation at address: ", rareBridgeBurnAndMint_impl);

    rareTokenL2SetMinter(rareTokenL2_proxy, rareBridgeBurnAndMint_proxy);
    rareBridgeAllowlist(rareBridgeBurnAndMint_proxy, correspondentRareBridgeAddress, correspondentChainSelector);
    rareBridgeSetExtraArgs(rareBridgeBurnAndMint_proxy, correspondentChainSelector, correspondentChainGasLimit);

    vm.stopBroadcast();
  }
}
