// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRareBridge {
  /*//////////////////////////////////////////////////////////////////////////
                              Events
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Emitted when a message is sent to a destination chain.
  /// @param messageId The unique ID of the CCIP message.
  /// @param destinationChainSelector The selector of the destination chain.
  /// @param destinationChainRecipient The address of the CCIP recipient on the destination chain.
  /// @param fee The amount of fees paid.
  /// @param payFeesInLink True if fees were paid in LINK, false if paid in native.
  event MessageSent(
    bytes32 indexed messageId,
    uint64 indexed destinationChainSelector,
    address indexed destinationChainRecipient,
    uint256 fee,
    bool payFeesInLink
  );

  /// @notice Emitted when a message is received from a sender chain.
  /// @param messageId The unique ID of the CCIP message.
  /// @param sourceChainSelector The selector of the source chain.
  /// @param sourceChainSender The address of the CCIP sender on the source chain.
  event MessageReceived(
    bytes32 indexed messageId,
    uint64 indexed sourceChainSelector,
    address indexed sourceChainSender
  );

  /*//////////////////////////////////////////////////////////////////////////
                            Custom Errors
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Emitted when Zero address provided where it is not allowed.
  error ZeroAddressUnsupported();

  /// @notice Emitted if there is nothing to withdraw.
  error NothingToWithdraw();

  /// @notice Emitted when ETH transfer fails.
  error FailedToWithdrawEth(address sender, address beneficiary, uint256 amount);

  /// @notice Emitted when balance is not enough.
  error NotEnoughBalance(uint256 balance, uint256 required);

  /// @notice Emitted when the pair of chain selector and account is not in the allowlist.
  error NotInAllowlist(uint64 chainSelector, address account);

  /// @notice Emitted when _handleTokens returns false, it either failed or not implemented.
  error FailedToHandleTokens(address from, address to, uint256 amount);

  /// @notice Emitted when the LINK token allowance is not enough to cover fees.
  error InsufficientLinkAllowanceForFee(uint256 allowance, uint256 fee);

  /// @notice Emitted when the LINK token balance is not enough to cover fees.
  error FailedToTransferLink();

  /// @notice Emitted when the ETH sent is not enough to cover fees.
  error InsufficientEthForFee(uint256 ethSent, uint256 fee);

  /// @notice Emitted when the RARE token allowance is not enough to send.
  error InsufficientRareAllowanceForSend(uint256 allowance, uint256 amount);

  /// @notice Emitted when recipients array length does not match amounts array length.
  error RecipientsAndAmountsLengthMismatch();
}
