// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @dev Interface of ERC20 & add permit function
 */
interface ICoin is IERC20Metadata {
    function permit(address owner, address to, uint256 amount, bytes memory signature) external;
}