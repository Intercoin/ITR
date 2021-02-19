interface ITransferRestrictions {
    function authorize(address from, address to, uint256 value) external returns (bool);
}