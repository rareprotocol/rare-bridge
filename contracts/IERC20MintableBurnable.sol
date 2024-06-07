pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20MintableBurnable is IERC20 {
  function mint(address account, uint256 amount) external returns (bool);
  function burnFrom(address account, uint256 amount) external returns (bool);
}
