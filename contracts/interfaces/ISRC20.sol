// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
/**
 * @title SRC20 public interface
 */
interface ISRC20 {
    function balanceOf(address who) external view returns (uint256);
    function executeTransfer(address from, address to, uint256 value) external returns (bool);
}