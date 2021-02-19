pragma solidity ^0.6.0;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";

import "../interfaces/ITransferRestrictions.sol";
import "../interfaces/ITransferRules.sol";

contract ExternalItrImitationMock is ERC20UpgradeSafe {
    
    /**
     * Configured contract implementing token restriction(s).
     * If set, transferToken will consult this contract should transfer
     * be allowed after successful authorization signature check.
     */
    ITransferRestrictions public _restrictions;

    /**
     * Configured contract implementing token rule(s).
     * If set, transfer will consult this contract should transfer
     * be allowed after successful authorization signature check.
     * And call doTransfer() in order for rules to decide where fund
     * should end up.
     */
    ITransferRules public _rules;
    
    event RestrictionsAndRulesUpdated(address restrictions, address rules);
    
    function init() public initializer {
        __ERC20_init("Intercoin", 'ITR');
    }
    
    
    function _updateRestrictionsAndRules(address restrictions, address rules) public returns (bool) {

        _restrictions = ITransferRestrictions(restrictions);
        _rules = ITransferRules(rules);

        if (rules != address(0)) {
            require(_rules.setSRC(address(this)), "SRC20 contract already set in transfer rules");
        }

        emit RestrictionsAndRulesUpdated(restrictions, rules);
        return true;
    }
 
 
    function transfer(address to, uint256 value) override public returns (bool) {
        
        if (address(_restrictions) != address(0)) {
            require(_restrictions.authorize(msg.sender, to, value), "transferToken restrictions failed");
        }
        
        if (_rules != ITransferRules(0)) {
            require(_rules.doTransfer(msg.sender, to, value), "Transfer failed");
        } else {
            _transfer(msg.sender, to, value);
        }

        return true;
    }

    function transferFrom(address from, address to, uint256 value) override public returns (bool) {
        if (address(_restrictions) != address(0)) {
            require(_restrictions.authorize(from, to, value), "transferToken restrictions failed");
        }

        if (_rules != ITransferRules(0)) {
            _approve(from, msg.sender, allowance(from,msg.sender).sub(value));
            require(_rules.doTransfer(from, to, value), "Transfer failed");
        } else {
            _approve(from, msg.sender, allowance(from,msg.sender).sub(value));
            _transfer(from, to, value);
        }

        return true;
    }
    
    /**
     * @dev This method is intended to be executed by TransferRules contract when doTransfer is called in transfer
     * and transferFrom methods to check where funds should go.
     *
     * @param from The address to transfer from.
     * @param to The address to send tokens to.
     * @param value The amount of tokens to send.
     */
    function executeTransfer(address from, address to, uint256 value) external /*onlyAuthority*/ returns (bool) {
        _transfer(from, to, value);
        return true;
    }
    
   /**
     * @dev Creates `amount` tokens and send to account.
     *
     * See {ERC20-_mint}.
     */
    function mint(address account, uint256 amount) public virtual {
        _mint(account, amount);
    }
        
}