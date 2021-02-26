pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "../TransferRules.sol";
/*
 * @title TransferRules contract
 * @dev Contract that is checking if on-chain rules for token transfers are concluded.
 * It implements whitelist and grey list.
 */
contract TransferRulesMock is TransferRules {
    
    function getMinimumsList(address addr) public view returns (uint256[] memory ret, uint256[] memory ret2 ) {
        
        
        uint256 mapIndex = 0;
        ret = new uint256[](users[addr].indexes.length());
        ret2 = new uint256[](users[addr].indexes.length());
        for (uint256 i=0; i<users[addr].indexes.length(); i++) {
            
            mapIndex = users[addr].indexes.at(i);
            ret[i] = users[addr].data[mapIndex].minimum;
            ret2[i] = users[addr].data[mapIndex].timestampEnd;
            // ret[i].timestampStart = users[addr].data[mapIndex].timestampStart;
            // ret[i].timestampEnd = users[addr].data[mapIndex].timestampEnd;
            // ret[i].minimum = users[addr].data[mapIndex].minimum;
            // ret[i].gradual = users[addr].data[mapIndex].gradual;
            
    
        }
        //return ret;
            
    }
    
    function getInitParams() public view returns(uint256, uint256) {
        return (durationLockupUSAPerson,durationLockupNoneUSAPerson);
    }
}
    