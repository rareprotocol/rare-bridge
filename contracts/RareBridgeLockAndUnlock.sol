// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {RareBridge} from "./RareBridge.sol";

/// @title Rare Bridge: Lock and Unlock
/// @notice The bridge that sends and receives RARE tokens and arbitrary messages.
/// @dev This is the lock/unlock implementation of the RareBridge.
/// @dev Made to be used with Chainlink CCIP.
contract RareBridgeLockAndUnlock is RareBridge {
  using SafeERC20 for IERC20;

  /// @notice Lock RARE tokens in the bridge.
  /// @param _sender The sender of RARE tokens.
  /// @param _amount The amount of RARE tokens to lock in the bridge.
  function _handleTokensOnSend(address _sender, uint256 _amount) internal override {
    IERC20(s_rareToken).safeTransferFrom(_sender, address(this), _amount);
  }

  /// @notice Unlock RARE tokens locked in the bridge and send them to a recipient.
  /// @param _to The recipient of RARE tokens.
  /// @param _amount The amount of RARE tokens to unlock and send.
  function _handleTokensOnReceive(address _to, uint256 _amount) internal override {
    IERC20(s_rareToken).safeTransfer(_to, _amount);
  }
}
