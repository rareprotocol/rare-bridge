// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {MockCCIPRouter} from "@chainlink/contracts-ccip/src/v0.8/ccip/test/mocks/MockRouter.sol";
import {EVM2EVMOnRamp} from "@chainlink/contracts-ccip/src/v0.8/ccip/onRamp/EVM2EVMOnRamp.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SuperRareTokenL2} from "contracts/RareTokenL2.sol";
import {IRareBridge} from "../contracts/interfaces/IRareBridge.sol";
import {RareBridge} from "contracts/RareBridge.sol";
import {RareBridgeBurnAndMint} from "contracts/RareBridgeBurnAndMint.sol";
import {RareBridgeLockAndUnlock} from "contracts/RareBridgeLockAndUnlock.sol";

contract RareTokenBridgeTest is Test {
  uint256 public constant ccipFee = 0.05 ether;

  RareBridgeLockAndUnlock public rareBridge;
  RareBridgeBurnAndMint public rareBridgeL2;
  CCIPLocalSimulator public ccipLocalSimulator;

  address public tokenOwner = address(1);
  address public tokenOwnerL2 = address(2);
  address public admin = address(3);

  uint64 public chainSelector;

  LinkToken public linkToken;
  SuperRareToken public rareToken;
  SuperRareTokenL2 public rareTokenL2;

  function setUp() public {
    rareToken = new SuperRareToken();
    rareToken.init(tokenOwner);

    SuperRareTokenL2 rareTokenL2Impl = new SuperRareTokenL2();
    ERC1967Proxy proxyRareTokenL2 = new ERC1967Proxy(
      address(rareTokenL2Impl),
      abi.encodeCall(rareTokenL2Impl.initialize, (admin))
    );
    rareTokenL2 = SuperRareTokenL2(address(proxyRareTokenL2));

    ccipLocalSimulator = new CCIPLocalSimulator();
    (
      uint64 _chainSelector,
      IRouterClient sourceRouter,
      IRouterClient destinationRouter,
      ,
      LinkToken _linkToken,
      ,

    ) = ccipLocalSimulator.configuration();

    linkToken = _linkToken;
    chainSelector = _chainSelector;

    MockCCIPRouter(address(sourceRouter)).setFee(ccipFee);
    MockCCIPRouter(address(destinationRouter)).setFee(ccipFee);

    RareBridgeLockAndUnlock rareBridgeLnUImpl = new RareBridgeLockAndUnlock();
    ERC1967Proxy proxyLnU = new ERC1967Proxy(
      address(rareBridgeLnUImpl),
      abi.encodeCall(
        rareBridgeLnUImpl.initialize,
        (address(sourceRouter), address(linkToken), address(rareToken), admin)
      )
    );
    rareBridge = RareBridgeLockAndUnlock(payable(address(proxyLnU)));

    RareBridgeBurnAndMint rareBridgeBnMImpl = new RareBridgeBurnAndMint();
    ERC1967Proxy proxyBnM = new ERC1967Proxy(
      address(rareBridgeBnMImpl),
      abi.encodeCall(
        rareBridgeBnMImpl.initialize,
        (address(destinationRouter), address(linkToken), address(rareTokenL2), admin)
      )
    );
    rareBridgeL2 = RareBridgeBurnAndMint(payable(address(proxyBnM)));

    vm.startPrank(admin);

    rareTokenL2.grantRole(rareTokenL2.MINTER_ROLE(), address(rareBridgeL2));

    rareBridge.allowlistRecipient(chainSelector, address(rareBridgeL2), true);
    rareBridge.allowlistSender(chainSelector, address(rareBridgeL2), true);
    rareBridge.setExtraArgs(chainSelector, 300000);

    rareBridgeL2.allowlistRecipient(chainSelector, address(rareBridge), true);
    rareBridgeL2.allowlistSender(chainSelector, address(rareBridge), true);
    rareBridgeL2.setExtraArgs(chainSelector, 300000);

    vm.stopPrank();
  }

  function prepareScenario(uint256 numRecipients) public pure returns (address[] memory, uint256[] memory) {
    address[] memory recipients = new address[](numRecipients);
    uint256[] memory amounts = new uint256[](numRecipients);

    uint shift = 10;

    for (uint i = 0; i < numRecipients; ++i) {
      recipients[i] = address(uint160(uint256(keccak256(abi.encodePacked(i + shift)))));
      amounts[i] = 1 ether;
    }

    return (recipients, amounts);
  }

  function testAllowlistRecipient() public {
    address receiver = address(7);
    vm.prank(admin);
    vm.expectEmit(true, true, false, true, address(rareBridge));
    emit IRareBridge.RecipientAllowlisted(chainSelector, receiver, true);
    rareBridge.allowlistRecipient(chainSelector, receiver, true);
    assertTrue(rareBridge.allowlistedRecipients(chainSelector, receiver));
  }

  function testAllowlistSender() public {
    address sender = address(8);
    vm.prank(admin);
    vm.expectEmit(true, true, false, true, address(rareBridge));
    emit IRareBridge.SenderAllowlisted(chainSelector, sender, true);
    rareBridge.allowlistSender(chainSelector, sender, true);
    assertTrue(rareBridge.allowlistedSenders(chainSelector, sender));
  }

  function testSetExtraArgs() public {
    uint256 gasLimit = 300_000;
    bytes memory extraArgs = Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit}));
    vm.prank(admin);
    vm.expectEmit(true, false, false, true, address(rareBridge));
    emit IRareBridge.ExtraArgsSet(chainSelector, extraArgs);
    rareBridge.setExtraArgs(chainSelector, gasLimit);
    assertEq(rareBridge.extraArgsPerChain(chainSelector), extraArgs);
  }

  function testPauseAndUnpause() public {
    vm.prank(admin);
    rareBridge.pause();
    assertTrue(rareBridge.paused());

    vm.prank(admin);
    rareBridge.unpause();
    assertFalse(rareBridge.paused());
  }

  function testWithdraw() public {
    vm.deal(address(rareBridge), 1 ether);
    vm.prank(admin);
    rareBridge.withdraw(payable(admin));
    assertEq(admin.balance, 1 ether);
  }

  function testTransferL1toL2PayLINK() public {
    (address[] memory recipients, uint256[] memory amounts) = prepareScenario(2);

    uint256 totalAmountToSend = 0;
    for (uint256 i = 0; i < amounts.length; ++i) {
      totalAmountToSend += amounts[i];
    }

    uint256 initialBalance = rareToken.balanceOf(tokenOwner);
    bool payFeesInLink = true;

    vm.startPrank(tokenOwner);

    uint256 fee = rareBridge.getFee(
      chainSelector,
      address(rareBridgeL2),
      abi.encode(recipients, amounts),
      "",
      payFeesInLink
    );

    ccipLocalSimulator.requestLinkFromFaucet(address(tokenOwner), fee);
    linkToken.approve(address(rareBridge), fee);

    rareToken.approve(address(rareBridge), totalAmountToSend);

    vm.expectEmit(false, true, true, true, address(rareBridgeL2));
    emit IRareBridge.MessageReceived(0, chainSelector, address(rareBridge));
    vm.expectEmit(false, true, true, true, address(rareBridge));
    emit IRareBridge.MessageSent(0, chainSelector, address(rareBridgeL2), fee, payFeesInLink);

    rareBridge.send(chainSelector, address(rareBridgeL2), abi.encode(recipients, amounts), "", payFeesInLink);

    assertEq(rareToken.balanceOf(tokenOwner), initialBalance - totalAmountToSend);
    assertEq(rareToken.balanceOf(address(rareBridge)), totalAmountToSend);

    for (uint256 i = 0; i < recipients.length; ++i) {
      assertEq(rareTokenL2.balanceOf(recipients[i]), amounts[i]);
    }
  }

  function testTransferL1toL2PayETH() public {
    (address[] memory recipients, uint256[] memory amounts) = prepareScenario(2);

    uint256 totalAmountToSend = 0;
    for (uint256 i = 0; i < amounts.length; ++i) {
      totalAmountToSend += amounts[i];
    }

    uint256 initialBalance = rareToken.balanceOf(tokenOwner);
    bool payFeesInLink = false;

    vm.startPrank(tokenOwner);

    uint256 fee = rareBridge.getFee(
      chainSelector,
      address(rareBridgeL2),
      abi.encode(recipients, amounts),
      "",
      payFeesInLink
    );

    vm.deal(address(tokenOwner), fee);

    rareToken.approve(address(rareBridge), totalAmountToSend);

    vm.expectEmit(false, true, true, true, address(rareBridgeL2));
    emit IRareBridge.MessageReceived(0, chainSelector, address(rareBridge));
    vm.expectEmit(false, true, true, true, address(rareBridge));
    emit IRareBridge.MessageSent(0, chainSelector, address(rareBridgeL2), fee, payFeesInLink);

    rareBridge.send{value: fee}(
      chainSelector,
      address(rareBridgeL2),
      abi.encode(recipients, amounts),
      "",
      payFeesInLink
    );

    assertEq(rareToken.balanceOf(tokenOwner), initialBalance - totalAmountToSend);
    assertEq(rareToken.balanceOf(address(rareBridge)), totalAmountToSend);

    for (uint256 i = 0; i < recipients.length; ++i) {
      assertEq(rareTokenL2.balanceOf(recipients[i]), amounts[i]);
    }
  }

  function testTransferL2toL1PayLINK() public {
    (address[] memory recipients, uint256[] memory amounts) = prepareScenario(2);

    uint256 totalAmountToSend = 0;
    for (uint256 i = 0; i < amounts.length; ++i) {
      totalAmountToSend += amounts[i];
    }

    bool payFeesInLink = true;

    vm.prank(tokenOwner);
    rareToken.transfer(address(rareBridge), totalAmountToSend);

    vm.prank(address(rareBridgeL2));
    rareTokenL2.mint(tokenOwnerL2, totalAmountToSend);

    vm.startPrank(tokenOwnerL2);

    uint256 fee = rareBridgeL2.getFee(
      chainSelector,
      address(rareBridge),
      abi.encode(recipients, amounts),
      "",
      payFeesInLink
    );

    ccipLocalSimulator.requestLinkFromFaucet(address(tokenOwnerL2), fee);

    linkToken.approve(address(rareBridgeL2), fee);
    rareTokenL2.approve(address(rareBridgeL2), totalAmountToSend);

    vm.expectEmit(false, true, true, true, address(rareBridge));
    emit IRareBridge.MessageReceived(0, chainSelector, address(rareBridgeL2));
    vm.expectEmit(false, true, true, true, address(rareBridgeL2));
    emit IRareBridge.MessageSent(0, chainSelector, address(rareBridge), fee, payFeesInLink);

    rareBridgeL2.send(chainSelector, address(rareBridge), abi.encode(recipients, amounts), "", payFeesInLink);

    assertEq(rareTokenL2.balanceOf(tokenOwnerL2), 0);
    assertEq(rareToken.balanceOf(address(rareBridge)), 0);

    for (uint256 i = 0; i < recipients.length; ++i) {
      assertEq(rareToken.balanceOf(recipients[i]), amounts[i]);
    }
  }

  function testTransferL2toL1PayETH() public {
    (address[] memory recipients, uint256[] memory amounts) = prepareScenario(2);

    uint256 totalAmountToSend = 0;
    for (uint256 i = 0; i < amounts.length; ++i) {
      totalAmountToSend += amounts[i];
    }

    bool payFeesInLink = false;

    vm.prank(tokenOwner);
    rareToken.transfer(address(rareBridge), totalAmountToSend);

    vm.prank(address(rareBridgeL2));
    rareTokenL2.mint(tokenOwnerL2, totalAmountToSend);

    vm.startPrank(tokenOwnerL2);

    uint256 fee = rareBridgeL2.getFee(
      chainSelector,
      address(rareBridge),
      abi.encode(recipients, amounts),
      "",
      payFeesInLink
    );

    vm.deal(address(tokenOwnerL2), fee);
    rareTokenL2.approve(address(rareBridgeL2), totalAmountToSend);

    vm.expectEmit(false, true, true, true, address(rareBridge));
    emit IRareBridge.MessageReceived(0, chainSelector, address(rareBridgeL2));
    vm.expectEmit(false, true, true, true, address(rareBridgeL2));
    emit IRareBridge.MessageSent(0, chainSelector, address(rareBridge), fee, payFeesInLink);

    rareBridgeL2.send{value: fee}(
      chainSelector,
      address(rareBridge),
      abi.encode(recipients, amounts),
      "",
      payFeesInLink
    );

    assertEq(rareTokenL2.balanceOf(tokenOwnerL2), 0);
    assertEq(rareToken.balanceOf(address(rareBridge)), 0);

    for (uint256 i = 0; i < recipients.length; ++i) {
      assertEq(rareToken.balanceOf(recipients[i]), amounts[i]);
    }
  }

  // Fuzz

  function testFuzzTransferL1toL2(uint256 numRecipients) public {
    vm.assume(numRecipients > 0);
    vm.assume(numRecipients < 30);

    (address[] memory recipients, uint256[] memory amounts) = prepareScenario(numRecipients);

    uint256 totalAmountToSend = 0;
    for (uint256 i = 0; i < amounts.length; ++i) {
      totalAmountToSend += amounts[i];
    }

    uint256 initialBalance = rareToken.balanceOf(tokenOwner);
    bool payFeesInLink = true;

    vm.prank(admin);
    // NOTE: _CCIPReceive gas usage increases with the number of recipients
    rareBridge.setExtraArgs(chainSelector, 900_000);

    vm.startPrank(tokenOwner);

    uint256 fee = rareBridge.getFee(
      chainSelector,
      address(rareBridgeL2),
      abi.encode(recipients, amounts),
      "",
      payFeesInLink
    );

    ccipLocalSimulator.requestLinkFromFaucet(address(tokenOwner), fee);
    linkToken.approve(address(rareBridge), fee);

    rareToken.approve(address(rareBridge), totalAmountToSend);

    vm.expectEmit(false, true, true, true, address(rareBridgeL2));
    emit IRareBridge.MessageReceived(0, chainSelector, address(rareBridge));
    vm.expectEmit(false, true, true, true, address(rareBridge));
    emit IRareBridge.MessageSent(0, chainSelector, address(rareBridgeL2), fee, payFeesInLink);

    rareBridge.send(chainSelector, address(rareBridgeL2), abi.encode(recipients, amounts), "", payFeesInLink);

    assertEq(rareToken.balanceOf(tokenOwner), initialBalance - totalAmountToSend);
    assertEq(rareToken.balanceOf(address(rareBridge)), totalAmountToSend);

    for (uint256 i = 0; i < recipients.length; ++i) {
      assertEq(rareTokenL2.balanceOf(recipients[i]), amounts[i]);
    }
  }

  function testFuzzTransferL2toL1(uint256 numRecipients) public {
    vm.assume(numRecipients > 0);
    vm.assume(numRecipients < 30);

    (address[] memory recipients, uint256[] memory amounts) = prepareScenario(numRecipients);

    uint256 totalAmountToSend = 0;
    for (uint256 i = 0; i < amounts.length; ++i) {
      totalAmountToSend += amounts[i];
    }

    bool payFeesInLink = true;

    vm.prank(admin);
    // NOTE: _CCIPReceive gas usage increases with the number of recipients
    rareBridgeL2.setExtraArgs(chainSelector, 900_000);

    vm.prank(tokenOwner);
    rareToken.transfer(address(rareBridge), totalAmountToSend);

    vm.prank(address(rareBridgeL2));
    rareTokenL2.mint(tokenOwnerL2, totalAmountToSend);

    vm.startPrank(tokenOwnerL2);

    uint256 fee = rareBridgeL2.getFee(
      chainSelector,
      address(rareBridge),
      abi.encode(recipients, amounts),
      "",
      payFeesInLink
    );

    ccipLocalSimulator.requestLinkFromFaucet(address(tokenOwnerL2), fee);

    linkToken.approve(address(rareBridgeL2), fee);
    rareTokenL2.approve(address(rareBridgeL2), totalAmountToSend);

    vm.expectEmit(false, true, true, true, address(rareBridge));
    emit IRareBridge.MessageReceived(0, chainSelector, address(rareBridgeL2));
    vm.expectEmit(false, true, true, true, address(rareBridgeL2));
    emit IRareBridge.MessageSent(0, chainSelector, address(rareBridge), fee, payFeesInLink);

    rareBridgeL2.send(chainSelector, address(rareBridge), abi.encode(recipients, amounts), "", payFeesInLink);

    assertEq(rareTokenL2.balanceOf(tokenOwnerL2), 0);
    assertEq(rareToken.balanceOf(address(rareBridge)), 0);

    for (uint256 i = 0; i < recipients.length; ++i) {
      assertEq(rareToken.balanceOf(recipients[i]), amounts[i]);
    }
  }

  // Upgrade tests

  function testUpgradeRareBridge() public {
    address newRouter = address(4);

    RareBridgeTestable rareBridgeTestable = new RareBridgeTestable();

    vm.prank(tokenOwner);
    rareToken.transfer(address(rareBridge), 1 ether);

    vm.startPrank(admin);
    rareBridge.upgradeToAndCall(
      address(rareBridgeTestable),
      abi.encodeCall(RareBridgeTestable.initializeV2, (newRouter))
    );

    RareBridgeTestable(payable(address(rareBridge))).withdrawToken(admin, address(rareToken));

    assert(rareBridge.getRouter() == newRouter);
    assert(rareToken.balanceOf(admin) == 1 ether);
  }

  // Negative tests

  function testReinitialization() public {
    address router = rareBridge.getRouter();
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    rareBridge.initialize(router, address(linkToken), address(rareToken), admin);
  }

  function testAllowlistRecipientByNonOwner() public {
    vm.prank(tokenOwner);
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, (tokenOwner)));
    rareBridge.allowlistRecipient(1, address(7), true);
  }

  function testAllowlistSenderByNonOwner() public {
    vm.prank(tokenOwner);
    vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, (tokenOwner)));
    rareBridge.allowlistSender(1, address(7), true);
  }

  function testSendTokensWithoutAllowance() public {
    (address[] memory recipients, uint256[] memory amounts) = prepareScenario(2);

    uint256 totalAmountToSend = 0;
    for (uint256 i = 0; i < amounts.length; ++i) {
      totalAmountToSend += amounts[i];
    }

    vm.startPrank(tokenOwner);

    vm.mockCall(
      address(rareToken),
      abi.encodeWithSelector(IERC20.allowance.selector, tokenOwner, address(rareBridge)),
      abi.encode(0) // No allowance
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(rareBridge),
        0,
        totalAmountToSend
      )
    );

    rareBridge.send{value: 0}(chainSelector, address(rareBridgeL2), abi.encode(recipients, amounts), "", false);

    vm.stopPrank();
  }

  function testSendTokensWhenPaused() public {
    (address[] memory recipients, uint256[] memory amounts) = prepareScenario(2);

    vm.prank(admin);
    rareBridge.pause();

    vm.startPrank(tokenOwner);

    uint256 totalAmountToSend = 0;
    for (uint256 i = 0; i < amounts.length; ++i) {
      totalAmountToSend += amounts[i];
    }

    vm.mockCall(
      address(rareToken),
      abi.encodeWithSelector(IERC20.allowance.selector, tokenOwner, address(rareBridge)),
      abi.encode(totalAmountToSend)
    );

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

    rareBridge.send{value: 0}(chainSelector, address(rareBridgeL2), abi.encode(recipients, amounts), "", false);

    vm.stopPrank();
  }

  function testTransferWrongExtraArgs() public {
    (address[] memory recipients, uint256[] memory amounts) = prepareScenario(2);

    bytes memory wrongExtraArgs = "wrong";

    uint256 totalAmountToSend = 0;
    for (uint256 i = 0; i < amounts.length; ++i) {
      totalAmountToSend += amounts[i];
    }

    bool payFeesInLink = true;

    vm.startPrank(tokenOwner);

    uint256 fee = rareBridge.getFee(
      chainSelector,
      address(rareBridgeL2),
      abi.encode(recipients, amounts),
      wrongExtraArgs,
      payFeesInLink
    );

    ccipLocalSimulator.requestLinkFromFaucet(address(tokenOwner), fee);
    linkToken.approve(address(rareBridge), fee);

    rareToken.approve(address(rareBridge), totalAmountToSend);

    vm.expectRevert(EVM2EVMOnRamp.InvalidExtraArgsTag.selector);

    rareBridge.send(
      chainSelector,
      address(rareBridgeL2),
      abi.encode(recipients, amounts),
      wrongExtraArgs,
      payFeesInLink
    );
  }
}

// We do not need to import actual implementation of the RareToken contract for testing purposes.
contract SuperRareToken is ERC20 {
  constructor() ERC20("Rare Token", "RARE") {}
  function init(address account) public {
    _mint(account, 1_000_000 ether);
  }
}

// Testable version of the RareBridge contract to test upgrade functionality and storage values
contract RareBridgeTestable is RareBridge {
  function initializeV2(address _router) public reinitializer(2) {
    if (_router == address(0)) revert ZeroAddressUnsupported();
    __CCIPReceiver_init(_router);
  }
  function _handleTokensOnSend(address, uint256) internal override {}
  function _handleTokensOnReceive(address, uint256) internal override {}
  function withdrawToken(address _beneficiary, address _token) public onlyOwner {
    // Retrieve the balance of this contract
    uint256 amount = IERC20(_token).balanceOf(address(this));

    // Revert if there is nothing to withdraw
    if (amount == 0) revert NothingToWithdraw();

    IERC20(_token).transfer(_beneficiary, amount);
  }
}
