// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RareBridge} from "./RareBridge.sol";

/// @title Rare Bridge: Lock and Unlock
/// @notice The bridge that sends and receives RARE tokens and arbitrary messages.
/// @dev This is the lock/unlock implementation of the RareBridge.
/// @dev Made to be used with Chainlink CCIP.
contract RareBridgeLockAndUnlock is RareBridge {
  constructor(address _router, address _link, address _rare) RareBridge(_router, _link, _rare) {}

  /// @notice Lock RARE tokens in the bridge.
  /// @param _sender The sender of RARE tokens.
  /// @param _amount The amount of RARE tokens to lock in the bridge.
  function _handleTokensOnSend(address _sender, uint256 _amount) internal override {
    if (!IERC20(s_rareToken).transferFrom(_sender, address(this), _amount)) {
      revert FailedToHandleTokens(_sender, address(this), _amount);
    }
  }

  /// @notice Unlock RARE tokens locked in the bridge and send them to a recipient.
  /// @param _to The recipient of RARE tokens.
  /// @param _amount The amount of RARE tokens to unlock and send.
  function _handleTokensOnReceive(address _to, uint256 _amount) internal override {
    if (!IERC20(s_rareToken).transferFrom(address(this), _to, _amount)) {
      revert FailedToHandleTokens(address(this), _to, _amount);
    }
  }
}
