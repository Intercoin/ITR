# ITR
Smart contracts and code relating to the Intercoin ITR Token

# Installation

# Deploy
when deploy it is no need to pass parameters but need to call init method before use

# Overview
once installed will be use methods:
<table>
<thead>
	<tr>
		<th>method name</th>
		<th>called by</th>
		<th>description</th>
	</tr>
</thead>
<tbody>
	<tr>
		<td><a href="#authorize">authorize</a></td>
		<td>anyone</td>
		<td>Checks if transfer passes transfer rules</td>
	</tr>
	<tr>
		<td><a href="#minimumsview">minimumsView</a></td>
		<td>anyone</td>
		<td>viewing minimums holding in address sender during period from now to timestamp</td>
	</tr>
	<tr>
		<td><a href="#automaticlockupadd">automaticLockupAdd</a></td>
		<td>owner</td>
		<td>adding automatic lockup for person</td>
	</tr>
	<tr>
		<td><a href="#automaticlockupremove">automaticLockupRemove</a></td>
		<td>owner</td>
		<td>removing automatic lockup for person</td>
	</tr>
  <tr>
		<td><a href="#cleansrc">cleanSRC</a></td>
		<td>owner</td>
		<td>possible to owner clean src20 address and re-update settings in ITR tokens</td>
	</tr>
	<tr>
		<td><a href="#minimumsadd">minimumsAdd</a></td>
		<td>owner</td>
		<td>adding minimums holding in sender during period from now to timestamp</td>
	</tr>
  <tr>
		<td><a href="#minimumsclear">minimumsClear</a></td>
		<td>owner</td>
		<td>removing all minimums from this address</td>
	</tr>
	<tr>
		<td><a href="#managersadd">managersAdd</a></td>
		<td>owner</td>
		<td>adding managers</td>
	</tr>
	<tr>
		<td><a href="#managersremove">managersRemove</a></td>
		<td>owner</td>
		<td>removing managers</td>
	</tr>
	<tr>
		<td><a href="#whitelistreduce">whitelistReduce</a></td>
		<td>owner</td>
		<td>whenever anyone on whitelist receives tokens their lockup time reduce</td>
	</tr>
	<tr>
		<td><a href="#dailyrate">dailyRate</a></td>
		<td>owner</td>
		<td>setup limit sell `amount` of their tokens per `daysAmount`</td>
	</tr>
	<tr>
		<td><a href="#whitelistadd">whitelistAdd</a></td>
		<td>managers</td>
		<td>adding persons to whitelist</td>
	</tr>
	<tr>
		<td><a href="#whitelistremove">whitelistRemove</a></td>
		<td>managers</td>
		<td>removing persons from whitelist</td>
	</tr>
</tbody>
</table>

## Methods

### init

init method
    
### cleanSRC

clean SRC20. available only for owner
      
### minimumsView

returning minimum holding in address sender during period from now to timestamp.

Params:
name  | type | description
--|--|--
addr|address|address sender

### minimumsAdd

adding minimum holding at sender during period from now to timestamp.

Params:
name  | type | description
--|--|--
addr|address|address which should be restricted
amount|uint256|amount
timestamp|uint256|timestamp until minimum applied
gradual|bool|true if the limitation can gradually decrease
 
### minimumsClear

removing all minimums from this address. So all tokens are unlocked to send

Params:
name  | type | description
--|--|--
addr|address|address which should be clear restrict
 
### authorize

Checks if transfer passes transfer rules.

Params:
name  | type | description
--|--|--
from|address|The address to transfer from.
to|address|The address to send tokens to.
amount|uint256|The amount of tokens to send.

### managersAdd

adding managers. available only for owner

Params:
name  | type | description
--|--|--
addresses|address[]|array of manager's addreses
   
### managersRemove

removing managers. available only for owner

Params:
name  | type | description
--|--|--
addresses|address[]|array of manager's addreses
     
### whitelistAdd

Adding addresses list to whitelist

Params:
name  | type | description
--|--|--
addresses|address[]|list of addresses which will be added to whitelist
  
### whitelistRemove

Removing addresses list from whitelist

Params:
name  | type | description
--|--|--
addresses|address[]|list of addresses which will be removed from whitelist

### automaticLockupAdd

adding automatic lockup for person which recieve tokens from `from`

Params:
name  | type | description
--|--|--
from|address| `from` address
daysAmount|uint256|duration in days

### automaticLockupRemove

removing automaticLockup from address 

Params:
name  | type | description
--|--|--
from|address| `from` address
    
### whitelistReduce

whenever anyone on whitelist receives tokens their lockup time reduce to daysAmount(if less)

Params:
name  | type | description
--|--|--
daysAmount|uint256|duration in days
        
### dailyRate

setup limit sell `amount` of their tokens per `daysAmount`

Params:
name  | type | description
--|--|--
amount|uint256| amount 
daysAmount|uint256|duration in days
        
## Lifecycle
This contract is part of ITR token and realize two interfaces: ITransferRules and ITransferRestrictions
```
interface ITransferRules {
    function setSRC(address src20) external returns (bool);
    function doTransfer(address from, address to, uint256 value) external returns (bool);
}
```

```
interface ITransferRestrictions {
    function authorize(address from, address to, uint256 value) external returns (bool);
}
```
So ITR token contract should call `setSRC(address src20)` externally, where src20 - is address of ITR contract.
Then before instead own transfer should call `doTransfer(address from, address to, uint256 value)` externally.
TransferRules will call executeTransfer method if it passed own internal validations