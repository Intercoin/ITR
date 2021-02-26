pragma solidity ^0.6.2;
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";

import "./interfaces/ISRC20.sol";
import "./interfaces/ITransferRules.sol";
import "./Whitelist.sol";

/*
 * @title TransferRules contract
 * @dev Contract that is checking if on-chain rules for token transfers are concluded.
 */
contract TransferRules is Initializable, OwnableUpgradeSafe, ITransferRules, Whitelist {

	ISRC20 public _src20;
	using SafeMath for uint256;
	using Math for uint256;
	using EnumerableSet for EnumerableSet.UintSet;
	
    struct Lockup {
        uint256 duration;
        //bool gradual; // does not used 
        bool exists;
    }
    
    struct Minimum {
        uint256 timestampStart;
        uint256 timestampEnd;
        uint256 amount;
        bool gradual;
    }
    struct UserStruct {
        EnumerableSet.UintSet minimumsIndexes;
        mapping(uint256 => Minimum) minimums;
        Lockup lockup;
    }
    
    struct whitelistSettings {
        uint256 reduceTimestamp;
        //bool alsoGradual;// does not used 
        bool exists;
    }
    
    whitelistSettings settings;
    mapping (address => UserStruct) users;
    
    uint256 internal dayInSeconds;
    
    modifier onlySRC20 {
        require(msg.sender == address(_src20));
        _;
    }
    
    //---------------------------------------------------------------------------------
    // public  section
    //---------------------------------------------------------------------------------

    /**
     * init method
     */
    function init(
    ) 
        public 
        initializer 
    {
        __TransferRules_init();
    }
    
    
    /**
    * @dev view minimum sender for period from now to timestamp.
    */
    function minimumsView(
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
    * @param amount amount.
    * @param timestamp period until minimum applied
    * @param gradual true if the limitation can gradually decrease
    */
    function minimumsAdd(
        address addr,
        uint256 amount, 
        uint256 timestamp,
        bool gradual
    ) 
        public
        onlyOwner()
        returns (bool)
    {
        require(timestamp > block.timestamp, 'timestamp is less then current block.timestamp');
        
        _minimumsClear(addr, false);
        require(users[addr].minimumsIndexes.add(timestamp), 'minimum already exist');
        
        //users[addr].data[timestamp] = minimum;
        users[addr].minimums[timestamp].timestampStart = block.timestamp;
        users[addr].minimums[timestamp].timestampEnd = timestamp;
        users[addr].minimums[timestamp].amount = amount;
        users[addr].minimums[timestamp].gradual = gradual;
        return true;
        
    }
    
    /**
     * @dev removes all minimums from this address
     * so all tokens are unlocked to send
     * @param addr address which should be clear restrict
     */
    function minimumsClear(
        address addr
    )
        public 
        onlyOwner()
        returns (bool)
    {
        return _minimumsClear(addr, true);
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
        view
        returns (bool) 
    {
        uint256 balanceOfFrom = ISRC20(_src20).balanceOf(from);
        return _authorize(from, to, value, balanceOfFrom);
    }
    
    /**
     * added managers. available only for owner
     * @param addresses array of manager's addreses
     */
    function managersAdd(
        address[] memory addresses
    )
        public 
        onlyOwner
        returns(bool)
    {
        return _whitelistAdd('managers',addresses);
    }     
    
    /**
     * removed managers. available only for owner
     * @param addresses array of manager's addreses
     */
    function managersRemove(
        address[] memory addresses
    )
        public 
        onlyOwner
        returns(bool)
    {
        return _whitelistRemove('managers',addresses);
    }    
    
    /**
     * Adding addresses list from whitelist
     * 
     * @dev Available from whitelist with group 'managers' only
     * 
     * @param addresses list of addresses which will be added to whitelist
     * @return success return true in any cases 
     */
    function whitelistAdd(
        address[] memory addresses
    )
        public 
        override 
        onlyWhitelist('managers') 
        returns (bool success) 
    {
        success = _whitelistAdd(commonGroupName, addresses);
    }
    
    /**
     * Removing addresses list from whitelist
     * 
     * @dev Available from whitelist with group 'managers' only
     * Requirements:
     *
     * - `addresses` cannot contains the zero address.
     * 
     * @param addresses list of addresses which will be removed from whitelist
     * @return success return true in any cases 
     */
    function whitelistRemove(
        address[] memory addresses
    ) 
        public 
        override 
        onlyWhitelist('managers') 
        returns (bool success) 
    {
        success = _whitelistRemove(commonGroupName, addresses);
    }
    
    /**
     * @param from will add automatic lockup for destination address sent sent address from
     * @param daysAmount duration in days
     */
    function automaticLockupAdd(
        address from,
        uint256 daysAmount
    )
        public 
        onlyOwner()
    {
        users[from].lockup.duration = daysAmount.mul(dayInSeconds);
        users[from].lockup.exists = false;
    }
    
    /**
     * @dev whenever anyone on whitelist receives 
     * if alsoGradual is true then even gradual lockups are reduced, otherwise they stay
     * @param daysAmount duration in days
     */
    function whitelistReduce(
        uint256 daysAmount
    )
        public 
        onlyOwner()
    {
        if (daysAmount == 0) {
            
        } else {
            settings.reduceTimestamp = daysAmount.mul(dayInSeconds);
            settings.exists = true;    
        }
        
    }

    //---------------------------------------------------------------------------------
    // internal  section
    //---------------------------------------------------------------------------------
    
    /**
     * init internal
     */
    function __TransferRules_init(
    ) 
        internal
        initializer 
    {
        __Ownable_init();
        __Whitelist_init();
        
        dayInSeconds = 86400;
    }
    
    /**
    * @param from The address to transfer from.
    * @param to The address to send tokens to.
    * @param value The amount of tokens to send.
    * @param balanceOfFrom balance at from before transfer
    */
    function _authorize(
        address from, 
        address to, 
        uint256 value,
        uint256 balanceOfFrom
    ) 
        internal
        view
        returns (bool) 
    {

        if (
            (balanceOfFrom >= value) && 
            (
                (isWhitelisted(to)) ||
                (getMinimum(from) <= balanceOfFrom.sub(value))
            )
            
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
        
        for (uint256 i=0; i<users[addr].minimumsIndexes.length(); i++) {
            mapIndex = users[addr].minimumsIndexes.at(i);
            iMinimum = users[addr].minimums[mapIndex].amount;
            if (block.timestamp <= users[addr].minimums[mapIndex].timestampEnd) {
                if (users[addr].minimums[mapIndex].gradual == true) {
                    
                        iMinimum = iMinimum.div(
                                        users[addr].minimums[mapIndex].timestampEnd.sub(users[addr].minimums[mapIndex].timestampStart)
                                        ).
                                     mul(
                                        users[addr].minimums[mapIndex].timestampEnd.sub(block.timestamp)
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
    * @param deleteAnyway if true when delete items regardless expired or not
    */
    function _minimumsClear(
        address addr,
        bool deleteAnyway
    ) 
        internal 
        returns (bool) 
    {
        uint256 iMinimum = 0;
        uint256 mapIndex = 0;
        uint256 len = users[addr].minimumsIndexes.length();
        if (len > 0) {
            for (uint256 i=len; i>0; i--) {
                mapIndex = users[addr].minimumsIndexes.at(i-1);
                if (
                    (deleteAnyway == true) ||
                    (block.timestamp > users[addr].minimums[mapIndex].timestampEnd)
                ) {
                    delete users[addr].minimums[mapIndex];
                    users[addr].minimumsIndexes.remove(mapIndex);
                }
                
            }
        }
        return true;
    }
    
    /**
     * added minimum if not exist by timestamp else append it
     * @param receiver destination address
     * @param timestampEnd "until time"
     * @param value amount
     * @param gradual if true then lockup are gradually
     */
    function _appendMinimum(
        address receiver,
        uint256 timestampEnd, 
        uint256 value, 
        bool gradual
    )
        internal
    {
        if (users[receiver].minimumsIndexes.add(timestampEnd) == true) {
            users[receiver].minimums[timestampEnd].timestampStart = block.timestamp;
            users[receiver].minimums[timestampEnd].amount = value;
            users[receiver].minimums[timestampEnd].timestampEnd = timestampEnd;
            users[receiver].minimums[timestampEnd].gradual = gradual; 
        } else {
            //'minimum already exist' 
            // just summ exist and new value
            users[receiver].minimums[timestampEnd].amount = users[receiver].minimums[timestampEnd].amount.add(value);
        }
    }
    
    /**
     * @dev reduce minimum by value  otherwise remove it 
     * @param addr destination address
     * @param timestampEnd "until time"
     * @param value amount
     */
    function _reduceMinimum(
        address addr,
        uint256 timestampEnd, 
        uint256 value
    )
        internal
    {
        
        if (users[addr].minimumsIndexes.contains(timestampEnd) == true) {
            if (value < users[addr].minimums[timestampEnd].amount) {
               users[addr].minimums[timestampEnd].amount = users[addr].minimums[timestampEnd].amount.sub(value);
            } else {
                delete users[addr].minimums[timestampEnd];
                users[addr].minimumsIndexes.remove(timestampEnd);
            }
        }
    }
    
    /**
     * @dev 
     *  A - issuers
     *  B - not on whitelist
     *  C - on whitelist
     *  There are rules:
     *  1. A sends to B: lockup for 1 year
     *  2. A sends to C: lock up for 40 days
     *  3. B sends to C: lock up for 40 days or remainder of B’s lockup, whichever is lower
     *  4. C sends to other C: transfer minimum with same timestamp to recipient and lockups must remove from sender
     * 
     * @param from sender address
     * @param to destination address
     * @param value amount
     * @param balanceFromBefore balances sender's address before executeTransfer
     */
    function applyRuleLockup(
        address from, 
        address to, 
        uint256 value,
        uint256 balanceFromBefore
    ) 
        internal
        onlySRC20
    {
        
        // check available balance for make transaction. in _authorize have already check whitelist(to) and available tokens 
        require(_authorize(from, to, value, balanceFromBefore), "Transfer not authorized");


        uint256 automaticLockupDuration;

        // get lockup time if was applied into fromAddress by automaticLockupAdd
        if (users[from].lockup.exists == true) {
            automaticLockupDuration = users[from].lockup.duration;
        }
        
        // calculate how much tokens we should transferMinimums without free tokens
        // here 
        //// value -- is how much tokens we would need to transfer
        //// minimum -- how much tokens locks
        //// balanceFromBefore-minimum -- it's free tokens
        //// value-(free tokens) -- how much tokens need to transferMinimums to destination address
        
        uint256 minimum = getMinimum(from);
        if (balanceFromBefore.sub(minimum) < value) {
            value = value.sub(balanceFromBefore.sub(minimum));    
        }
        
        // A -> B automaticLockup minimums added
        // A -> C automaticLockup minimums but reduce to 40
        // B -> C transferLockups and reduce to 40
        // C -> C transferLockups

        if (users[from].lockup.exists == true) {
            // then sender is A
            
            uint256 untilTimestamp = block.timestamp.add( 
                (isWhitelisted(to)) 
                ? 
                    (
                    settings.exists
                    ?
                    automaticLockupDuration.min(settings.reduceTimestamp) 
                    :
                    automaticLockupDuration
                    )
                : 
                automaticLockupDuration
                );
            
            _appendMinimum(
                to,
                value, 
                untilTimestamp,
                false   //bool gradual
            );
            
            // C -> C transferLockups
        } else if (isWhitelisted(from) && isWhitelisted(to)) {
            minimumsTransfer(
                from, 
                to, 
                value, 
                false, 
                0
            );
        } else{
            // else sender is B 
            
            if (isWhitelisted(to)) {
                minimumsTransfer(
                    from, 
                    to, 
                    value, 
                    true, 
                    block.timestamp.add(settings.reduceTimestamp)
                );
            }
            
            // else available only free tokens to transfer and this was checked in autorize method before
        }
    }
    
    /**
     * 
     * @param from sender address
     * @param to destination address
     * @param value amount
     * @param reduceTimeDiff if true then all timestamp which more then minTimeDiff will reduce to minTimeDiff
     * @param minTimeDiff minimum lockup timestamp time
     */
    function minimumsTransfer(
        address from, 
        address to, 
        uint256 value, 
        bool reduceTimeDiff,
        uint256 minTimeDiff
    )
        internal
    {
        
        uint256 len = users[from].minimumsIndexes.length();
        uint256[] memory _dataList;
        uint256 recieverTimeLeft;
        
        if (len > 0) {
            _dataList = new uint256[](len);
            for (uint256 i=0; i<len; i++) {
                _dataList[i] = users[from].minimumsIndexes.at(i);
            }
            _dataList = sortAsc(_dataList);
            
            uint256 iValue;
            
            
            for (uint256 i=0; i<len; i++) {
                
                
                if (value > users[from].minimums[_dataList[i]].amount) {
                    //iValue = users[from].data[_dataList[i]].minimum;
                    iValue = calculateAvailableMinimum(users[from].minimums[_dataList[i]]);
                    
                    value = value.sub(iValue);
                } else {
                    iValue = value;
                    value = 0;
                }
               
                recieverTimeLeft = users[from].minimums[_dataList[i]].timestampEnd.sub(block.timestamp);
                // put to reciver
                _appendMinimum(
                    to,
                    block.timestamp.add((reduceTimeDiff ? minTimeDiff.min(recieverTimeLeft) : recieverTimeLeft)),
                    iValue,
                    false //users[from].data[_dataList[i]].gradual
                );
                
                // remove from sender
                _reduceMinimum(
                    from,
                    users[from].minimums[_dataList[i]].timestampEnd,
                    iValue
                );
                  
                if (value == 0) {
                    break;
                }
            } // end for
            
            
            
            //!!!!!  value can not be left more then zero  if then minimums are gone
            // if (value != 0) {
                
            //     
            //     _appendMinimum(
            //         to,
            //         block.timestamp.add(durationLockupNoneUSAPerson),
            //         value,
            //         false
            //     );
            // }
            
        }
        
    }
    
    /**
     * @dev calculating limit funds for the moment 
     * if gradual option set to true then gradually 
     */
    function calculateAvailableMinimum(
        Minimum memory mininumStruct
    )
        internal
        view
        returns(uint256 ret)
    {
        if (mininumStruct.gradual == true) {
            if (block.timestamp >= mininumStruct.timestampEnd) {
                ret = (mininumStruct.amount).div(
                                        mininumStruct.timestampEnd.sub(mininumStruct.timestampStart)
                                        ).
                                     mul(
                                        mininumStruct.timestampEnd.sub(block.timestamp)
                                        );
            } else {
                ret = 0;
            }
                       
        } else {
            ret = mininumStruct.amount;
        }
    }
    
    //---------------------------------------------------------------------------------
    // external section
    //---------------------------------------------------------------------------------
    
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
        uint256 balanceFromBefore = ISRC20(_src20).balanceOf(from);
        require(ISRC20(_src20).executeTransfer(from, to, value), "SRC20 transfer failed");
        applyRuleLockup(from, to, value, balanceFromBefore);
        return true;
    }
    
    //---------------------------------------------------------------------------------
    // private  section
    //---------------------------------------------------------------------------------
    
    
    // useful method to sort native memory array 
    function sortAsc(uint256[] memory data) private returns(uint[] memory) {
       quickSortAsc(data, int(0), int(data.length - 1));
       return data;
    }
    
    function quickSortAsc(uint[] memory arr, int left, int right) private {
        int i = left;
        int j = right;
        if(i==j) return;
        uint pivot = arr[uint(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint(i)] < pivot) i++;
            while (pivot < arr[uint(j)]) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j)
            quickSortAsc(arr, left, j);
        if (i < right)
            quickSortAsc(arr, i, right);
    }

	
}
