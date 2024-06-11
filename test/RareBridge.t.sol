// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {MockCCIPRouter} from "@chainlink/contracts-ccip/src/v0.8/ccip/test/mocks/MockRouter.sol";
import {SuperRareToken} from "@rare/contracts/token/ERC20/SuperRareGovToken.sol";
import {SuperRareTokenL2} from "contracts/RareTokenL2.sol";
import {RareBridgeBurnAndMint} from "contracts/RareBridgeBurnAndMint.sol";
import {RareBridgeLockAndUnlock} from "contracts/RareBridgeLockAndUnlock.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RareTokenBridgeTest is Test {
  RareBridgeLockAndUnlock public rareBridgeLnU;
  RareBridgeBurnAndMint public rareBridgeBnM;
  CCIPLocalSimulator public ccipLocalSimulator;

  address public tokenOwner = address(1);
  address public tokenOwnerL2 = address(2);
  address public admin = address(3);

  LinkToken linkToken;

  uint64 public chainSelector;
  SuperRareToken public rareToken;
  SuperRareTokenL2 public rareTokenL2;

  uint256 linkTokenFee = 0.5 ether;

  function setUp() public {
    rareToken = new SuperRareToken();
    rareToken.init(tokenOwner);
    rareTokenL2 = new SuperRareTokenL2();

    ccipLocalSimulator = new CCIPLocalSimulator();
    (
      uint64 chainSelector_,
      IRouterClient sourceRouter,
      IRouterClient destinationRouter,
      ,
      LinkToken linkToken_,
      ,

    ) = ccipLocalSimulator.configuration();

    linkToken = linkToken_;

    MockCCIPRouter(address(sourceRouter)).setFee(linkTokenFee);
    MockCCIPRouter(address(destinationRouter)).setFee(linkTokenFee);

    RareBridgeLockAndUnlock rareBridgeLnUImpl = new RareBridgeLockAndUnlock();
    ERC1967Proxy proxyLnU = new ERC1967Proxy(
      address(rareBridgeLnUImpl),
      abi.encodeCall(
        rareBridgeLnUImpl.initialize,
        (address(sourceRouter), address(linkToken), address(rareToken), admin)
      )
    );
    rareBridgeLnU = RareBridgeLockAndUnlock(payable(address(proxyLnU)));

    RareBridgeBurnAndMint rareBridgeBnMImpl = new RareBridgeBurnAndMint();
    ERC1967Proxy proxyBnM = new ERC1967Proxy(
      address(rareBridgeBnMImpl),
      abi.encodeCall(
        rareBridgeBnMImpl.initialize,
        (address(destinationRouter), address(linkToken), address(rareTokenL2), admin)
      )
    );
    rareBridgeBnM = RareBridgeBurnAndMint(payable(address(proxyBnM)));

    rareTokenL2.initialize(tokenOwnerL2, address(rareBridgeBnM));

    chainSelector = chainSelector_;

    vm.startPrank(admin);
    rareBridgeLnU.allowlistRecipient(chainSelector, address(rareBridgeBnM), true);
    rareBridgeLnU.allowlistSender(chainSelector, address(rareBridgeBnM), true);
    rareBridgeBnM.allowlistRecipient(chainSelector, address(rareBridgeLnU), true);
    rareBridgeBnM.allowlistSender(chainSelector, address(rareBridgeLnU), true);

    rareBridgeLnU.setExtraArgs(chainSelector, 400_000);
    rareBridgeBnM.setExtraArgs(chainSelector, 400_000);
  }

  function prepareScenario() private pure returns (uint256 amountToSend, bytes memory data) {
    amountToSend = 0.001 ether;
    data = abi.encode("");
  }

  function test_regularTransferL1toL2() public {
    uint256 initialBalance = rareToken.balanceOf(tokenOwner);

    (uint256 amountToSend, bytes memory data) = prepareScenario();

    vm.startPrank(tokenOwner);

    uint256 amountForFeesInLink = rareBridgeLnU.getFee(
      chainSelector,
      address(rareBridgeBnM),
      tokenOwnerL2,
      amountToSend,
      data,
      true
    );

    ccipLocalSimulator.requestLinkFromFaucet(address(tokenOwner), amountForFeesInLink);

    linkToken.approve(address(rareBridgeLnU), amountForFeesInLink);
    rareToken.approve(address(rareBridgeLnU), amountToSend);
    rareBridgeLnU.send(chainSelector, address(rareBridgeBnM), tokenOwnerL2, amountToSend, data, true);

    assertEq(rareToken.balanceOf(tokenOwner), initialBalance - amountToSend);
    assertEq(rareToken.balanceOf(address(rareBridgeLnU)), amountToSend);
    assertEq(rareTokenL2.balanceOf(tokenOwnerL2), amountToSend);
  }

  function test_regularTransferL2toL1() public {
    uint256 initialBalance = rareToken.balanceOf(tokenOwner);

    (uint256 amountToSend, bytes memory data) = prepareScenario();

    vm.startPrank(tokenOwner);

    uint256 amountForFeesInLink = rareBridgeLnU.getFee(
      chainSelector,
      address(rareBridgeBnM),
      tokenOwnerL2,
      amountToSend,
      data,
      true
    );

    ccipLocalSimulator.requestLinkFromFaucet(address(tokenOwner), amountForFeesInLink);

    linkToken.approve(address(rareBridgeLnU), amountForFeesInLink);
    rareToken.approve(address(rareBridgeLnU), amountToSend);
    rareBridgeLnU.send(chainSelector, address(rareBridgeBnM), tokenOwnerL2, amountToSend, data, true);

    vm.startPrank(tokenOwnerL2);

    amountForFeesInLink = rareBridgeBnM.getFee(
      chainSelector,
      address(rareBridgeLnU),
      tokenOwner,
      amountToSend,
      data,
      true
    );

    ccipLocalSimulator.requestLinkFromFaucet(address(tokenOwnerL2), amountForFeesInLink);

    linkToken.approve(address(rareBridgeBnM), amountForFeesInLink);

    rareTokenL2.approve(address(rareBridgeBnM), amountToSend);
    rareBridgeBnM.send(chainSelector, address(rareBridgeLnU), tokenOwner, amountToSend, data, true);

    assertEq(rareToken.balanceOf(tokenOwner), initialBalance);
    assertEq(rareToken.balanceOf(address(rareBridgeLnU)), 0);
    assertEq(rareTokenL2.balanceOf(tokenOwnerL2), 0);
  }
}
