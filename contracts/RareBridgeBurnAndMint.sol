// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RareBridge} from "./RareBridge.sol";
import "./IERC20MintableBurnable.sol";

/// @title Rare Bridge: Burn and Mint
/// @notice The bridge that sends and receives RARE tokens and arbitrary messages.
/// @dev This is the burn/mint implementation of the RareBridge.
/// @dev Made to be used with Chainlink CCIP.
contract RareBridgeBurnAndMint is RareBridge {
  constructor (address _router, address _link, address _rare) RareBridge(_router, _link, _rare) {}

  /// @notice Burn RARE tokens.
  /// @param _sender The sender of RARE tokens.
  /// @param _amount The amount of RARE tokens to burn.
  function _handleTokensOnSend(address _sender, uint256 _amount) internal override returns (bool success) {
    // Burn tokens from sender, reducing the total supply.
    return IERC20MintableBurnable(s_rareToken).burnFrom(_sender, _amount);
  }

  /// @notice Mint RARE tokens to a recipient.
  /// @param _to The recipient of RARE tokens.
  /// @param _amount The amount of RARE tokens to mint.
  function _handleTokensOnReceive(address _to, uint256 _amount) internal override returns (bool success) {
    // Mint tokens for a recipient, increasing the total supply.
    return IERC20MintableBurnable(s_rareToken).mint(_to, _amount);
  }
}
