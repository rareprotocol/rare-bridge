// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IRareBridge} from "./IRareBridge.sol";

/// @title RareBridge
/// @notice The abstract RARE bridge contract that sends and receives RARE tokens and arbitrary messages.
/// @dev Made to be used with Chainlink CCIP.
abstract contract RareBridge is IRareBridge, CCIPReceiver, OwnerIsCreator {
  // Mapping to keep track of allowlisted destination chains.
  mapping(uint64 => mapping(address => bool)) public allowlistedRecipients;

  // Allowlist of senders per chain
  mapping(uint64 => mapping(address => bool)) public allowlistedSenders;

  // Mapping to set parameters of gasLimit on targetChains
  mapping(uint64 => Client.EVMExtraArgsV1) public extraArgsPerChain;

  IERC20 private s_linkToken;
  IERC20 private s_rareToken;

  /// @dev Modifier that checks if the pair of a given chain selector and sender is allowlisted.
  /// @param _sourceChainSelector The selector of the source chain.
  /// @param _sender The address of the sender.
  modifier onlyAllowlistedSender(uint64 _sourceChainSelector, address _sourceChainSender) {
    if (!allowlistedSenders[_sourceChainSelector][_sourceChainSender]) {
      revert NotInAllowlist(_sourceChainSelector, _sourceChainSender);
    }
    _;
  }

  /// @dev Modifier that checks if the pair of a given chain selector and recipient is allowlisted.
  /// @param _destinationChainSelector The selector of the destination chain.
  /// @param _destinationChainRecipient The address of the recipient.
  modifier onlyAllowlistedRecipient(uint64 _destinationChainSelector, address _destinationChainRecipient) {
    if (!allowlistedRecipients[_destinationChainSelector][_destinationChainRecipient]) {
      revert NotInAllowlist(_destinationChainSelector, _destinationChainRecipient);
    }
    _;
  }

  /// @notice Constructor initializes the contract with the router address.
  /// @param _router The address of the CCIP Router.
  /// @param _link The address of the LINK Token.
  /// @param _rare The address of the RARE Token.
  constructor(address _router, address _link, address _rare) CCIPReceiver(_router) {
    if (_link == address(0)) revert ZeroAddressUnsupported();
    if (_rare == address(0)) revert ZeroAddressUnsupported();

    s_linkToken = IERC20(_link);
    s_rareToken = IERC20(_rare);
  }

  /// @dev Updates the allowlist status of a destination chain for transactions.
  /// @notice This function can only be called by the owner.
  /// @param _destinationChainSelector The selector of the destination chain.
  /// @param _destinationChainRecipient The address of the recipient to be updated.
  /// @param allowed The allowlist status to be set for the destination chain.
  function allowlistRecipient(
    uint64 _destinationChainSelector,
    address _destinationChainRecipient,
    bool allowed
  ) external onlyOwner {
    allowlistedRecipients[_destinationChainSelector][_destinationChainRecipient] = allowed;
  }

  /// @dev Updates the allowlist status of a sender for transactions.
  /// @notice This function can only be called by the owner.
  /// @param _sourceChainSelector The selector of a source chain.
  /// @param _sourceChainSender The address of the sender to be updated.
  /// @param allowed The allowlist status to be set for the sender.
  function allowlistSender(uint64 _sourceChainSelector, address _sourceChainSender, bool allowed) external onlyOwner {
    allowlistedSenders[_sourceChainSelector][_sourceChainSender] = allowed;
  }

  /// @dev Set extraArgs per chain.
  /// @notice This function can only be called by the owner.
  /// @param _gasLimit to execute on a target chain.
  /// @param _strict to stop incoming messages from same sender if target chain reverts
  function setExtraArgs(uint64 _destinationChainSelector, uint256 _gasLimit, bool _strict) external onlyOwner {
    extraArgsPerChain[_destinationChainSelector].gasLimit = _gasLimit;
  }

  /// @notice Calculates the estimated fee for sending a message.
  /// @param _destinationChainSelector The selector of the destination chain.
  /// @param _destinationChainRecipient The address of the recipient on the destination chain.
  /// @param _to The address of the token recipient on the destination chain.
  /// @param _amount The amount of RARE tokens to send.
  /// @param _data The encoded call data to send to the recipient.
  /// @param _payFeesInLink Whether the fees will be paid in LINK tokens.
  /// @return The estimated fee.
  function getFee(
    uint64 _destinationChainSelector,
    address _destinationChainRecipient,
    address _to,
    uint256 _amount,
    bytes calldata _data,
    bool _payFeesInLink
  ) external view onlyAllowlistedRecipient(_destinationChainSelector, _destinationChainRecipient) returns (uint256) {
    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
      receiver: abi.encode(_destinationChainRecipient),
      data: abi.encode(_to, _amount, _data),
      tokenAmounts: new Client.EVMTokenAmount[](0),
      extraArgs: Client._argsToBytes(extraArgsPerChain[_destinationChainSelector]),
      feeToken: _payFeesInLink ? address(s_linkToken) : address(0)
    });

    uint256 fee = IRouterClient(i_ccipRouter).getFee(_destinationChainSelector, message);

    return fee;
  }

  /// @notice Sends RARE tokens and calldata to a destination chain.
  /// @param _destinationChainSelector The selector of the destination chain.
  /// @param _destinationChainRecipient The address of the recipient on the destination chain.
  /// @param _to The address of the token recipient on the destination chain.
  /// @param _amount The amount of RARE tokens to send.
  /// @param _data The encoded call data to send to the recipient.
  /// @param _payFeesInLink Whether to pay the fees in LINK tokens.
  function send(
    uint64 _destinationChainSelector,
    address _destinationChainRecipient,
    address _to,
    uint256 _amount,
    bytes calldata _data,
    bool _payFeesInLink
  ) external payable onlyAllowlistedRecipient(_destinationChainSelector, _destinationChainRecipient) {
    Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
      receiver: abi.encode(_destinationChainRecipient),
      data: abi.encode(_to, _amount, _data),
      tokenAmounts: new Client.EVMTokenAmount[](0),
      extraArgs: Client._argsToBytes(extraArgsPerChain[_destinationChainSelector]),
      feeToken: _payFeesInLink ? s_linkToken : address(0)
    });

    uint256 fee = IRouterClient(i_ccipRouter).getFee(_destinationChainSelector, message);

    // Check for sufficient allowance and transfer the RARE tokens
    if (s_rareToken.allowance(msg.sender, address(this)) < _amount) {
      revert InsufficientRareAllowanceForSend(s_rareToken.allowance(msg.sender, address(this)), _amount);
    }
    if (!_handleTokensOnSend(msg.sender, _amount)) {
      revert FailedToHandleTokens(msg.sender, _amount);
    }

    bytes32 messageId;

    // Send the CCIP message through the router and emit the returned CCIP message ID
    if (_payFeesInLink) {
      if (s_linkToken.allowance(msg.sender, address(this)) < fee) {
        revert InsufficientLinkAllowanceForFee(s_linkToken.allowance(msg.sender, address(this)), fee);
      }
      if (!s_linkToken.transferFrom(msg.sender, address(this), fee)) {
        revert FailedToTransferLink();
      }
      s_linkToken.approve(i_ccipRouter, fee);
      messageId = IRouterClient(i_ccipRouter).ccipSend(_destinationChainSelector, message);
    } else {
      // Ensure the user has sent enough ether to cover the fee
      if (msg.value < fee) {
        revert InsufficientEthForFee(msg.value, fee);
      }
      messageId = IRouterClient(i_ccipRouter).ccipSend{value: fee}(_destinationChainSelector, message);
    }

    // Emit an event with message ID
    emit MessageSent(messageId);
  }

  /// @notice Internal ccipReceive function override.
  /// @param message Any2EVMMessage
  function _ccipReceive(
    Client.Any2EVMMessage memory message
  )
    internal
    override
    onlyRouter
    onlyAllowlistedSender(message.sourceChainSelector, abi.decode(message.sender, (address)))
  {
    // Decode the message data
    (address to, uint256 amount, ) = abi.decode(message.data, (address, uint256, bytes));

    if (!_handleTokensOnReceive(to, amount)) {
      revert FailedToHandleTokens(to, amount);
    }

    // Emit an event with message details
    emit MessageReceived(message.messageId, message.sourceChainSelector, abi.decode(message.sender, (address)), amount);
  }

  function _handleTokensOnSend(address _sender, uint256 _amount) internal virtual returns (bool success) {
    return false;
  }

  function _handleTokensOnReceive(address _to, uint256 _amount) internal virtual returns (bool success) {
    return false;
  }

  /// @notice Fallback function to allow the contract to receive Ether.
  /// @dev This function has no function body, making it a default function for receiving Ether.
  /// It is automatically called when Ether is sent to the contract without any data.
  receive() external payable {}

  /// @notice Allows the contract owner to withdraw the entire balance of Ether from the contract.
  /// @dev This function reverts if there are no funds to withdraw or if the transfer fails.
  /// @param _beneficiary The address to which the Ether should be sent.
  function withdraw(address payable _beneficiary) public onlyOwner {
    // Retrieve the balance of this contract
    uint256 amount = address(this).balance;

    // Revert if there is nothing to withdraw
    if (amount == 0) revert NothingToWithdraw();

    // Attempt to send the funds, capturing the success status and discarding any return data
    (bool sent, ) = _beneficiary.call{value: amount}("");

    // Revert if the send failed, with information about the attempted transfer
    if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
  }
}
