pragma solidity ^0.6.0;
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./interfaces/ISRC20.sol";
import "./interfaces/ITransferRules.sol";

/*
 * @title TransferRules contract
 * @dev Contract that is checking if on-chain rules for token transfers are concluded.
 * It implements whitelist and grey list.
 */
contract TransferRules is Initializable, OwnableUpgradeSafe, ITransferRules {

	ISRC20 public _src20;
	using SafeMath for uint256;
	using EnumerableSet for EnumerableSet.UintSet;

    struct Min {
        uint256 timestampStart;
        uint256 timestampEnd;
        uint256 minimum;
        bool gradual;
    }
    struct MinStruct {
        EnumerableSet.UintSet indexes;
        // // uint256 timestamp => uint256 minimum;
        // mapping(uint256 => uint256) data;
        
        // uint256 timestamp => struct Min;
        mapping(uint256 => Min) data;
        
    }
    
    mapping (address => MinStruct) users;
    
    modifier onlySRC20 {
        require(msg.sender == address(_src20));
        _;
    }

    function init(
    ) 
        public 
        initializer 
    {
        __Ownable_init();
    }
    
    /**
    * @dev view minimum sender for period from now to timestamp.
    */
    function viewMinimum(
    ) 
        public
        view
        returns (uint256)
    {
        return getMinimum(_msgSender());
    }
    
    /**
    * @dev add minimum to sender for period from now to timestamp.
    *
    * @param addr address which should be restricted
    * @param minimum amount.
    * @param timestamp period until miimum applied
    * @param gradual true if the limitation can gradually decrease
    */
    function addMinimum(
        address addr,
        uint256 minimum, 
        uint256 timestamp,
        bool gradual
    ) 
        public
        onlyOwner()
        returns (bool)
    {
        require(timestamp > block.timestamp, 'minimum is less then current timestamp');
        
        clearMinimums(addr);
        require(users[addr].indexes.add(timestamp) == true, 'minimum already exist');
        
        //users[addr].data[timestamp] = minimum;
        users[addr].data[timestamp].timestampStart = block.timestamp;
        users[addr].data[timestamp].timestampEnd = timestamp;
        users[addr].data[timestamp].minimum = minimum;
        users[addr].data[timestamp].gradual = gradual;
        return true;
        
    }
    
    
    /**
    * @dev Checks if transfer passes transfer rules.
    *
    * @param from The address to transfer from.
    * @param to The address to send tokens to.
    * @param value The amount of tokens to send.
    */
    function authorize(
        address from, 
        address to, 
        uint256 value
    ) 
        public 
        returns (bool) 
    {
        
        uint256 balance = ISRC20(_src20).balanceOf(from);

        if (
            (balance >= value) && 
            (getMinimum(from) <= balance.sub(value))
        ) {
            return true;
        }
        return false;
    }

    /**
    * @dev get sum minimum from address for period from now to timestamp.
    *
    * @param addr address.
    */
    function getMinimum(
        address addr
    ) 
        internal 
        view
        returns (uint256 ret) 
    {
        ret = 0;
        
        uint256 iMinimum = 0;
        uint256 mapIndex = 0;
        
        for (uint256 i=0; i<users[addr].indexes.length(); i++) {
            mapIndex = users[addr].indexes.at(i);
            iMinimum = users[addr].data[mapIndex].minimum;
            if (block.timestamp <= users[addr].data[mapIndex].timestampEnd) {
                if (users[addr].data[mapIndex].gradual == true) {
                    
                    iMinimum = iMinimum.sub(
                        (
                            iMinimum.
                            div(
                                users[addr].data[mapIndex].timestampEnd.sub(users[addr].data[mapIndex].timestampStart)
                            )
                        ).mul(
                            users[addr].data[mapIndex].timestampEnd.sub(block.timestamp)
                        )
                    );
                }
                
                ret = ret.add(iMinimum);
            }
        }
        
    }
    
    /**
    * @dev clear expired items from mapping. used while addingMinimum
    *
    * @param addr address.
    */
    function clearMinimums(
        address addr
    ) 
        internal 
        returns (uint256 ret) 
    {
        uint256 iMinimum = 0;
        uint256 mapIndex = 0;
        uint256 len = users[addr].indexes.length();
        if (len > 0) {
            for (uint256 i=len; i>0; i--) {
                mapIndex = users[addr].indexes.at(i-1);
                if (block.timestamp > users[addr].data[mapIndex].timestampEnd) {
                    delete users[addr].data[mapIndex];
                    users[addr].indexes.remove(mapIndex);
                }
                
            }
        }
    }
    
    /**
    * @dev Set for what contract this rules are.
    *
    * @param src20 - Address of SRC20 contract.
    */
    function setSRC(
        address src20
    ) 
        override 
        external 
        returns (bool) 
    {
        require(address(_src20) == address(0), "SRC20 already set");
        _src20 = ISRC20(src20);
        return true;
    }


    /**
    * @dev Do transfer and checks where funds should go. If both from and to are
    * on the whitelist funds should be transferred but if one of them are on the
    * grey list token-issuer/owner need to approve transfer.
    *
    * @param from The address to transfer from.
    * @param to The address to send tokens to.
    * @param value The amount of tokens to send.
    */
    function doTransfer(
        address from, 
        address to, 
        uint256 value
    ) 
        override 
        external 
        onlySRC20 
        returns (bool) 
    {
        require(authorize(from, to, value), "Transfer not authorized");

        require(ISRC20(_src20).executeTransfer(from, to, value), "SRC20 transfer failed");

        return true;
    }
	
}
