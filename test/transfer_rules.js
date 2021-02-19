const BigNumber = require('bignumber.js');
const util = require('util');

const TransferRules = artifacts.require("TransferRules");
const ExternalItrImitationMock = artifacts.require("ExternalItrImitationMock");


const truffleAssert = require('truffle-assertions');
const helper = require("../helpers/truffleTestHelper");

contract('TransferRules', (accounts) => {
    
    // it("should assert true", async function(done) {
    //     await TestExample.deployed();
    //     assert.isTrue(true);
    //     done();
    //   });
    
    // Setup accounts.
    const accountOne = accounts[0];
    const accountTwo = accounts[1];  
    const accountThree = accounts[2];
    const accountFourth= accounts[3];
    const accountFive = accounts[4];
    const accountSix = accounts[5];
    const accountSeven = accounts[6];
    const accountEight = accounts[7];
    const accountNine = accounts[8];
    const accountTen = accounts[9];
    const accountEleven = accounts[10];
    const accountTwelwe = accounts[11];
    
    const zeroAddr = '0x0000000000000000000000000000000000000000';
    const version = '0.1';
    const name = 'SomeContractName';

    async function sendAndCheckCorrectBalance(obj, from, to, value, message) {
        let balanceAccount1Before = await obj.balanceOf(from);
        let balanceAccount2Before = await obj.balanceOf(to);
        
        await obj.transfer(to, value, {from: from});
        
        let balanceAccount1After = await obj.balanceOf(from);
        let balanceAccount2After = await obj.balanceOf(to);
        
        assert.equal(
            (BigNumber(balanceAccount1Before).minus(value)).toString(),
            (BigNumber(balanceAccount1After)).toString(),
            "wrong balance for 1st account "+message
        )
        assert.equal(
            (BigNumber(balanceAccount2Before).plus(value)).toString(),
            (BigNumber(balanceAccount2After)).toString(),
            "wrong balance for 2nd account "+message
        )
    }
    
    it('test', async () => {
        let latestBlockInfo;
        
        var ExternalItrImitationMockInstance = await ExternalItrImitationMock.new({from: accountTen});
        var TransferRulesInstance = await TransferRules.new({from: accountTen});
        
        await TransferRulesInstance.init({from: accountTen});
        
        // mint to both accounts 1000 ITR
        await ExternalItrImitationMockInstance.mint(accountOne, BigNumber(1000*1e18), {from: accountTen});
        await ExternalItrImitationMockInstance.mint(accountTwo, BigNumber(1000*1e18), {from: accountTen});
        
        // try to send 10ITR from AccountOne to AccountTwo and check it
        await sendAndCheckCorrectBalance(ExternalItrImitationMockInstance, accountOne, accountTwo, BigNumber(10*1e18), "Iteration#1");
        
        // _updateRestrictionsAndRules     
        await ExternalItrImitationMockInstance._updateRestrictionsAndRules(TransferRulesInstance.address, TransferRulesInstance.address, {from: accountTen});
        // try to send 10ITR from AccountOne to AccountTwo and check it AGAIN
        await sendAndCheckCorrectBalance(ExternalItrImitationMockInstance, accountOne, accountTwo, BigNumber(10*1e18), "Iteration#2");
        
        
        latestBlockInfo = await web3.eth.getBlock("latest");
        // balance at Account One for now are 1000-10-10 = 980ITR
        // setup Limit 700ITR fo user accountOne for 1000 seconds from now
        await TransferRulesInstance.addMinimum(accountOne, BigNumber(700*1e18), latestBlockInfo.timestamp+1000, false, {from: accountTen});
        // try to send 500ITR and check error message
        await truffleAssert.reverts(
            ExternalItrImitationMockInstance.transfer(accountTwo, BigNumber(500*1e18), {from: accountOne}), 
            "transferToken restrictions failed"
        );
        // pass 1k seconds
        await helper.advanceTimeAndBlock(1000);
        
    
        // and try to send 500ITR again
        await sendAndCheckCorrectBalance(ExternalItrImitationMockInstance, accountOne, accountTwo, BigNumber(500*1e18), "Iteration#3");
        
        latestBlockInfo = await web3.eth.getBlock("latest");
        // balance at AccountTwo for now are 1000+10+10+500 = 1520ITR
        // setup Limit 1200ITR gradually for user AccountTwo for 1000 seconds from now
        

        await TransferRulesInstance.addMinimum(accountTwo, BigNumber(1200*1e18), latestBlockInfo.timestamp+1000, true, {from: accountTen});

        // try to send 900ITR and check error message
        // 1520-1200 = 320 available

        await truffleAssert.reverts(
            ExternalItrImitationMockInstance.transfer(accountOne, BigNumber(900*1e18), {from: accountTwo}), 
            "transferToken restrictions failed"
        );
        // pass 500 seconds
        // await helper.advanceTimeAndBlock(500);
        await helper.advanceTime(500);
        await helper.advanceBlock();

        // and try to send 900ITR again
        // 1520-1200/2 = 1520-600 = 920 available
        await sendAndCheckCorrectBalance(ExternalItrImitationMockInstance, accountTwo, accountOne, BigNumber(900*1e18), "Iteration#4");

    });
   
});