pragma solidity >=0.6.0 <0.8.0;
interface ITransferRestrictions {
    function authorize(address from, address to, uint256 value) external returns (bool);
}