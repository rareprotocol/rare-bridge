// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBurnMintERC20} from "@chainlink/contracts-ccip/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";
import {RareBridge} from "./RareBridge.sol";

/// @title Rare Bridge: Burn and Mint
/// @notice The bridge that sends and receives RARE tokens and arbitrary messages.
/// @dev This is the burn/mint implementation of the RareBridge.
/// @dev Made to be used with Chainlink CCIP.
contract RareBridgeBurnAndMint is RareBridge {
  /// @notice Burn RARE tokens.
  /// @param _sender The sender of RARE tokens.
  /// @param _amount The amount of RARE tokens to burn.
  function _handleTokensOnSend(address _sender, uint256 _amount) internal override {
    // Burn tokens from sender, reducing the total supply.
    IBurnMintERC20(s_rareToken).burnFrom(_sender, _amount);
  }

  /// @notice Mint RARE tokens to a recipient.
  /// @param _to The recipient of RARE tokens.
  /// @param _amount The amount of RARE tokens to mint.
  function _handleTokensOnReceive(address _to, uint256 _amount) internal override {
    // Mint tokens for a recipient, increasing the total supply.
    IBurnMintERC20(s_rareToken).mint(_to, _amount);
  }
}
