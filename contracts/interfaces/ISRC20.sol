/**
 * @title SRC20 public interface
 */
interface ISRC20 {
    function balanceOf(address who) external view returns (uint256);
    function executeTransfer(address from, address to, uint256 value) external returns (bool);
}