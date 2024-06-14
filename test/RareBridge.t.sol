// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {CCIPLocalSimulator, IRouterClient, LinkToken, BurnMintERC677Helper} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {MockCCIPRouter} from "@chainlink/contracts-ccip/src/v0.8/ccip/test/mocks/MockRouter.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {SuperRareTokenL2} from "contracts/RareTokenL2.sol";
import {IRareBridge} from "contracts/IRareBridge.sol";
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
      abi.encodeCall(
        rareTokenL2Impl.initialize,
        (admin)
      )
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
    rareBridge.setExtraArgs(chainSelector, 400_000);

    rareBridgeL2.allowlistRecipient(chainSelector, address(rareBridge), true);
    rareBridgeL2.allowlistSender(chainSelector, address(rareBridge), true);
    rareBridgeL2.setExtraArgs(chainSelector, 400_000);

    vm.stopPrank();
  }

  function prepareScenario() private pure returns (uint256 amountToSend, bytes memory data) {
    amountToSend = 0.001 ether;
    data = abi.encode("");
  }

  function testAllowlistRecipient() public {
    address receiver = address(7);
    vm.prank(admin);
    rareBridge.allowlistRecipient(chainSelector, receiver, true);
    assertTrue(rareBridge.allowlistedRecipients(chainSelector, receiver));
  }

  function testAllowlistSender() public {
    address sender = address(8);
    vm.prank(admin);
    rareBridge.allowlistSender(chainSelector, sender, true);
    assertTrue(rareBridge.allowlistedSenders(chainSelector, sender));
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
    uint256 initialBalance = rareToken.balanceOf(tokenOwner);
    bool payFeesInLink = true;

    (uint256 amountToSend, bytes memory data) = prepareScenario();

    vm.startPrank(tokenOwner);

    uint256 fee = rareBridge.getFee(
      chainSelector,
      address(rareBridgeL2),
      tokenOwnerL2,
      amountToSend,
      data,
      payFeesInLink
    );

    ccipLocalSimulator.requestLinkFromFaucet(address(tokenOwner), fee);

    linkToken.approve(address(rareBridge), fee);
    rareToken.approve(address(rareBridge), amountToSend);
    rareBridge.send(chainSelector, address(rareBridgeL2), tokenOwnerL2, amountToSend, data, payFeesInLink);

    assertEq(rareToken.balanceOf(tokenOwner), initialBalance - amountToSend);
    assertEq(rareToken.balanceOf(address(rareBridge)), amountToSend);
    assertEq(rareTokenL2.balanceOf(tokenOwnerL2), amountToSend);
  }

  function testTransferL1toL2PayETH() public {
    uint256 initialBalance = rareToken.balanceOf(tokenOwner);
    bool payFeesInLink = false;

    (uint256 amountToSend, bytes memory data) = prepareScenario();

    vm.startPrank(tokenOwner);

    uint256 fee = rareBridge.getFee(
      chainSelector,
      address(rareBridgeL2),
      tokenOwnerL2,
      amountToSend,
      data,
      payFeesInLink
    );

    vm.deal(address(tokenOwner), fee);
    rareToken.approve(address(rareBridge), amountToSend);
    rareBridge.send{value: fee}(chainSelector, address(rareBridgeL2), tokenOwnerL2, amountToSend, data, payFeesInLink);

    assertEq(rareToken.balanceOf(tokenOwner), initialBalance - amountToSend);
    assertEq(rareToken.balanceOf(address(rareBridge)), amountToSend);
    assertEq(rareTokenL2.balanceOf(tokenOwnerL2), amountToSend);
  }

  function testTransferL2toL1PayLINK() public {
    uint256 initialBalance = rareToken.balanceOf(tokenOwner);
    bool payFeesInLink = true;

    (uint256 amountToSend, bytes memory data) = prepareScenario();

    vm.prank(tokenOwner);
    rareToken.transfer(address(rareBridge), amountToSend);

    vm.prank(address(rareBridgeL2));
    rareTokenL2.mint(tokenOwnerL2, amountToSend);

    vm.startPrank(tokenOwnerL2);

    uint256 fee = rareBridgeL2.getFee(
      chainSelector,
      address(rareBridge),
      tokenOwner,
      amountToSend,
      data,
      payFeesInLink
    );

    ccipLocalSimulator.requestLinkFromFaucet(address(tokenOwnerL2), fee);

    linkToken.approve(address(rareBridgeL2), fee);

    rareTokenL2.approve(address(rareBridgeL2), amountToSend);
    rareBridgeL2.send(chainSelector, address(rareBridge), tokenOwner, amountToSend, data, payFeesInLink);

    assertEq(rareToken.balanceOf(tokenOwner), initialBalance);
    assertEq(rareToken.balanceOf(address(rareBridge)), 0);
    assertEq(rareTokenL2.balanceOf(tokenOwnerL2), 0);
  }

  function testTransferL2toL1PayETH() public {
    uint256 initialBalance = rareToken.balanceOf(tokenOwner);
    bool payFeesInLink = false;

    (uint256 amountToSend, bytes memory data) = prepareScenario();

    vm.prank(tokenOwner);
    rareToken.transfer(address(rareBridge), amountToSend);

    vm.prank(address(rareBridgeL2));
    rareTokenL2.mint(tokenOwnerL2, amountToSend);

    vm.startPrank(tokenOwnerL2);

    uint256 fee = rareBridgeL2.getFee(
      chainSelector,
      address(rareBridge),
      tokenOwner,
      amountToSend,
      data,
      payFeesInLink
    );

    vm.deal(address(tokenOwnerL2), fee);
    rareTokenL2.approve(address(rareBridgeL2), amountToSend);
    rareBridgeL2.send{value: fee}(chainSelector, address(rareBridge), tokenOwner, amountToSend, data, payFeesInLink);

    assertEq(rareToken.balanceOf(tokenOwner), initialBalance);
    assertEq(rareToken.balanceOf(address(rareBridge)), 0);
    assertEq(rareTokenL2.balanceOf(tokenOwnerL2), 0);
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

  function testSendIfPaused() public {
    (uint256 amountToSend, bytes memory data) = prepareScenario();

    vm.prank(admin);
    rareBridge.pause();

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    rareBridge.send(chainSelector, address(rareBridgeL2), tokenOwnerL2, amountToSend, data, true);
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
    (uint256 amountToSend, bytes memory data) = prepareScenario();
    vm.startPrank(tokenOwner);

    vm.mockCall(
      address(rareToken),
      abi.encodeWithSelector(IERC20.allowance.selector, tokenOwner, address(rareBridge)),
      abi.encode(0) // No allowance
    );

    vm.expectRevert(abi.encodeWithSelector(IRareBridge.InsufficientRareAllowanceForSend.selector, 0, amountToSend));

    rareBridge.send{value: 0}(chainSelector, address(rareBridgeL2), tokenOwnerL2, amountToSend, data, false);

    vm.stopPrank();
  }

  function testSendTokensWhenPaused() public {
    (uint256 amountToSend, bytes memory data) = prepareScenario();

    vm.prank(admin);
    rareBridge.pause();

    vm.startPrank(tokenOwner);

    vm.mockCall(
      address(rareToken),
      abi.encodeWithSelector(IERC20.allowance.selector, tokenOwner, address(rareBridge)),
      abi.encode(amountToSend)
    );

    vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

    rareBridge.send{value: 0}(chainSelector, address(rareBridgeL2), tokenOwnerL2, amountToSend, data, false);

    vm.stopPrank();
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
