// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "contracts/RareBridge.sol";

contract RareBridgeWithdrawable is RareBridge {
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
