pragma solidity 0.4.4;

import 'dapple/test.sol'; 
import 'Common.sol';
import 'ICO.sol';
import 'FirstSale.sol';

contract Person {
    ICO ico;
    function Person(address _ico) {
        ico = ICO(_ico);
    }

    function deposit() payable {
        ico.deposit.value(msg.value)();
    }

    function claim() {
        ico.claim();
    }

    function claimableTokens() returns (uint) {
        return ico.claimableTokens();
    }

    function claimableRefund() returns (uint) {
        return ico.claimableRefund();
    }

    function () payable { }

    function acceptOwnership() {
        ico.acceptOwnership();
    }

}

contract Attacker {
    ICO ico;
    bool done = false;
    function Attacker(address _ico) {
        ico = ICO(_ico);
    }

    function deposit() payable {
        ico.deposit.value(msg.value)();
    }

    function claim() {
        ico.claim();
    }

    function () payable {
        bool wasdone = done;
        done = true;
        if (!wasdone) ico.claim();
    }
}

//for testing purposes
//this sale refunds half your money, and buys tokens with the rest
//and mints only upon calling claim()
contract SampleSale is Sale {
    uint public startTime;
    uint public stopTime;
    uint public target;
    uint public raised;
    uint public collected;
    uint public numContributors;
    uint price = 100;
    mapping(address => uint) public balances;

    function SampleSale(uint _time) {
        startTime = _time;
        stopTime = startTime + 10 days;
    }
    function buyTokens(address _a, uint _eth, uint _time) returns (uint) {
        if (balances[_a] == 0) {
            numContributors += 1;
        }
        balances[_a] += _eth;
        raised += _eth / 2;
        return 0;
    }
    function getTokens(address _a) constant returns (uint) {
        return price * (balances[_a]) / 2;
    } 
    function getRefund(address _a) constant returns (uint) {
        return balances[_a] / 2;
    }
    function getSoldTokens() constant returns (uint) {
        return (raised / 2) * price;
    }
    function getOwnerEth() constant returns (uint) {
        return raised;
    }
    function isActive(uint time) constant returns (bool) {
        return (time >= startTime && time <= stopTime);
    }
    function isComplete(uint time) constant returns (bool) {
        return (time >= stopTime);
    }
    function tokensPerEth() constant returns (uint) {
        return 1;
    }    
}

//like SampleSale but mints immediately
contract SampleSaleFastMint is SampleSale {
    function SampleSaleFastMint(uint _time) SampleSale(_time) {}
    function buyTokens(address _a, uint _eth, uint _time) returns (uint) {
        if (balances[_a] == 0) {
            numContributors += 1;
        }
        balances[_a] += _eth;
        raised += _eth / 2;
        return (_eth / 2) * price;
    }
    function getTokens(address _a) constant returns (uint) {
        return 0;
    } 
}

contract TestController is Owned {
    ICO public ico;
    uint weiPerDollar = 20;
    function TestController() {
        owner = msg.sender;
    }

    function setICO(address _ico) {
        ico = ICO(_ico);
    }

    function startSampleSale() {
        address sale = address(new SampleSale(ico.currTime())); 
        ico.addSale(sale);
    }

    function startSampleSaleFastMint() {
        address sale = address(new SampleSaleFastMint(ico.currTime())); 
        ico.addSale(sale);
    }

    function startSampleSaleWithMinimum(uint _minimum) {
        address sale = address(new SampleSale(ico.currTime())); 
        ico.addSale(sale, _minimum);
    }
}

contract ICOTest is Test, EventDefinitions {
    ICO ico;
    TestController con;
    Person p1;
    Person p2;
    Person p3;
    Token token;

    //for testing we say 10 weis makes an eth
    //because dapple only gives us 10 eths to work with
    //so let's say 1 ether = 10 dollars = 200 wei
    uint weiPerDollar = 20;
    uint weiPerEth = 200;

    function () payable {}

    function eth(uint eth) returns (uint) {
        return eth * weiPerEth;
    }
    function dollars(uint d) returns (uint) {
        return d * weiPerDollar;
    }
    
    function setUp() {
        con = new TestController();
        ico = new ICO();
        con.setICO(ico);
        ico.setController(con);
        ico.setAsTest();
        token = new Token();
        token.setICO(address(ico));
        token.setController(con);
        ico.setToken(token);

        ico.setFakeTime(1);
        weiPerEth = ico.weiPerEth();
        p1 = new Person(address(ico));
        p2 = new Person(address(ico));
        p3 = new Person(address(ico));
    }

    function testFirstSaleNum() {
        con.startSampleSale();
        ico.setFakeTime(3 days + 2);
        assertEq(ico.getCurrSale(), 0, "first sale not set");
        assertEq(ico.nextClaim(address(p1)), 0, "first claim");
    }

    function testThrowsMinimumPurchase() {
        con.startSampleSaleWithMinimum(10);
        Sale sale = ico.sales(0);
        ico.setFakeTime(3 days + 2);
        p1.deposit.value(5)();
    }

    function testAboveMinimumPurchase() {
        con.startSampleSaleWithMinimum(10);
        Sale sale = ico.sales(0);
        ico.setFakeTime(3 days + 2);
        p1.deposit.value(20)();
    }

    function testBuy() {
        expectEventsExact(ico);
    
        uint weis = 1000;

        con.startSampleSale();
        Sale sale = ico.sales(0);
        logSaleStart(sale.startTime(), sale.stopTime());

        ico.setFakeTime(3 days + 2);

        assertEq(ico.currSaleActive(), true, "active");
        assertEq(ico.currSaleComplete(), false, "complete");

        p1.deposit.value(weis)();
        logPurchase(address(p1), weis);
        assertEq(p1.claimableRefund(), 0, "incomplete refund");
        assertEq(p1.claimableTokens(), 0, "incomplete tokens");

        ico.addDays(20);
        assertEq(ico.currSaleActive(), false, "2 active");
        assertEq(ico.currSaleComplete(), true, "2 complete");
        assertEq(p1.claimableRefund(), weis / 2, "complete refund");
        assertEq(p1.claimableTokens(), 100 * weis / 2, "complete tokens");
    }

    function testClaim() {
        uint weis = 1000;

        con.startSampleSale();
        ico.setFakeTime(3 days + 2);

        assertEq(ico.currSaleActive(), true, "active");
        assertEq(ico.currSaleComplete(), false, "complete");

        p1.deposit.value(weis)();
        logPurchase(address(p1), weis);
        assertEq(p1.claimableRefund(), 0, "incomplete refund");
        assertEq(p1.claimableTokens(), 0, "incomplete tokens");

        ico.addDays(20);
        assertEq(ico.currSaleActive(), false, "2 active");
        assertEq(ico.currSaleComplete(), true, "2 complete");
        assertEq(p1.claimableRefund(), weis / 2, "complete refund");
        assertEq(p1.claimableTokens(), 100 * weis / 2, "complete tokens");

        p1.claim();
        assertEq(ico.nextClaim(address(p1)), 1, "next claim");
        assertEq(p1.balance, weis / 2, "p1 balance");
        assertEq(p1.claimableRefund(), 0, "p1 refund after claim");
        assertEq(p1.claimableTokens(), 0, "p1 tokens after claim");
    }

    function testClaimFastMint() {
        uint weis = 1000;

        con.startSampleSaleFastMint();
        ico.setFakeTime(3 days + 2);

        assertEq(ico.currSaleActive(), true, "active");
        assertEq(ico.currSaleComplete(), false, "complete");

        p1.deposit.value(weis)();
        logPurchase(address(p1), weis);
        assertEq(token.balanceOf(address(p1)), 100 * weis / 2, "fast mint");
        assertEq(p1.claimableRefund(), 0, "incomplete refund");
        assertEq(p1.claimableTokens(), 0, "incomplete tokens");

        ico.addDays(20);
        assertEq(ico.currSaleActive(), false, "2 active");
        assertEq(ico.currSaleComplete(), true, "2 complete");
        assertEq(p1.claimableRefund(), weis / 2, "complete refund");
        assertEq(p1.claimableTokens(), 0, "complete tokens");

        p1.claim();
        assertEq(ico.nextClaim(address(p1)), 1, "next claim");
        assertEq(p1.balance, weis / 2, "p1 balance");
        assertEq(p1.claimableRefund(), 0, "p1 refund after claim");
        assertEq(p1.claimableTokens(), 0, "p1 tokens after claim");
    }

    function testClaimFor() {
        uint weis = 1000;

        con.startSampleSale();
        ico.setFakeTime(4 days);
        p1.deposit.value(weis)();

        ico.addDays(20);
        assertEq(p1.claimableRefund(), weis / 2, "complete refund");
        assertEq(p1.claimableTokens(), 100 * weis / 2, "complete tokens");

        ico.addDays(400);
        ico.claimFor(address(p1), address(p2));

        assertEq(p2.balance, weis / 2, "recipient balance");
        assertEq(token.balanceOf(address(p2)), 100 * weis / 2, "recip tokens");

        assertEq(p2.claimableTokens(), 0, "recip claimable tokens");
        assertEq(p2.claimableRefund(), 0, "recip claimable refund");
        assertEq(p1.claimableTokens(), 0, "p1 claimable tokens 2");
        assertEq(p1.claimableRefund(), 0, "p1 claimable refund 2");
    }

    function testClaimForTooSoon() {
        uint weis = 1000;

        con.startSampleSale();
        ico.setFakeTime(4 days);
        p1.deposit.value(weis)();

        ico.addDays(20);
        assertEq(p1.claimableRefund(), weis / 2, "complete refund");
        assertEq(p1.claimableTokens(), 100 * weis / 2, "complete tokens");

        ico.claimFor(address(p1), address(p2));

        assertEq(p2.balance, 0, "recipient balance");
        assertEq(token.balanceOf(address(p2)), 0, "recip tokens");

        assertEq(p1.claimableRefund(), weis / 2, "p1 claimable refund 2");
        assertEq(p1.claimableTokens(), 100 * weis / 2, "p1 claimable tokens 2");
    }

    function testDoubleClaim() {
        //two people deposit max so each should get half back
        //one tries to do it twice and take it all
        uint weis = 1000;

        con.startSampleSale();
        ico.setFakeTime(4 days);

        p1.deposit.value(weis)();
        p2.deposit.value(weis)();

        ico.addDays(20);
        p1.claim();
        p1.claim();

        assertEq(p1.balance, 500, "p1 balance");
        assertEq(token.balanceOf(address(p1)), 50000, "p1 tokens");

        p2.claim();
        assertEq(p2.balance, 500, "p2 balance");
        assertEq(token.balanceOf(address(p2)), 50000, "p2 tokens");
    }

    function testThrowReentrantAttack () {
        //two people deposit max so each should get half back
        //one tries to do it twice via reentrance 
        uint weis = 1000;

        con.startSampleSale();
        ico.setFakeTime(4 days);

        p1.deposit.value(weis)();

        Attacker a2 = new Attacker(ico);
        a2.deposit.value(weis)();

        ico.addDays(20);
        a2.claim();
        p1.claim();

        assertEq(p1.balance, 500, "p1 balance");
        assertEq(token.balanceOf(address(p1)), 100 * weis / 2, "p1 tokens");

        a2.claim();
        assertEq(a2.balance, 500, "a2 balance");
        assertEq(token.balanceOf(address(a2)), 100 * weis / 2, "a2 tokens");
    }

    function testMulticlaim() {
        uint weis = 1000;

        //DEPOSIT IN FIRST SALE

        con.startSampleSale();
        ico.setFakeTime(4 days);

        p1.deposit.value(weis)();

        ico.addDays(20);
        assertEq(ico.currSaleActive(), false, "0 active");
        assertEq(ico.currSaleComplete(), true, "0 complete");

        //DEPOSIT IN SECOND SALE
        con.startSampleSale();
        ico.addDays(4);
        assertEq(ico.currSaleActive(), true, "1 active");
        assertEq(ico.currSaleComplete(), false, "1 complete");
        
        p1.deposit.value(weis)();

        ico.addDays(20);
        assertEq(ico.currSaleActive(), false, "1 active b");
        assertEq(ico.currSaleComplete(), true, "1 complete b");

        //DEPOSIT IN THIRD SALE
        con.startSampleSale();
        ico.addDays(4);
        assertEq(ico.currSaleActive(), true, "2 active");
        assertEq(ico.currSaleComplete(), false, "2 complete");
        
        p1.deposit.value(weis)();

        //DO A CLAIM WHILE THIRD SALE RUNNING
        //so this is a claim on two sales

        p1.claim();
        //at this point we should have tokens and refund from first two sales
        assertEq(p1.balance, 2 * (weis / 2), "balance2");
        assertEq(token.balanceOf(address(p1)), 2 * (100 * weis / 2), "tokens2");

        //END THIRD SALE AND CLAIM

        ico.addDays(20);
        p1.claim();

        //now should have tokens and refund frmo all three sales
        assertEq(p1.balance, 3 * (weis / 2), "balance3");
        assertEq(token.balanceOf(address(p1)), 3 * (100 * weis / 2), "tokens3");
    }

    function testClaimWithActiveSale() {
        uint weis = 1000;

        con.startSampleSale();
        ico.setFakeTime(4 days);

        p1.deposit.value(weis)();
        p1.claim();
        assertEq(address(p1).balance, 0, "eth balance");
        assertEq(token.balanceOf(address(p1)), 0, "token balance");
    }

    function testOwnerWithdraw() {
        uint weis = 1000;
        con.startSampleSale();
        ico.setFakeTime(3 days + 2);
        p1.deposit.value(weis)();
        ico.addDays(20);
        assertEq(address(ico).balance, 1000, "pre-withdraw");
        uint prewithdraw = this.balance;
        ico.claimOwnerEth(0);
        assertEq(address(ico).balance, 500, "withdraw");
        assertEq(this.balance, prewithdraw + 500, "post-withdraw");
    }

    function testTopup() {
        uint weis = 1000;
        con.startSampleSale();
        ico.setFakeTime(3 days + 2);
        p1.deposit.value(weis)();
        assertEq(ico.balance, weis, "a");
        assertEq(ico.topUpAmount(), 0, "b");
        
        ico.topUp.value(10)();
        assertEq(ico.balance, weis + 10, "c");
        assertEq(ico.topUpAmount(), 10, "d");

        ico.withdrawTopUp();
        assertEq(ico.balance, weis, "e");
        assertEq(ico.topUpAmount(), 0, "f");
        
        ico.withdrawTopUp();
        assertEq(ico.balance, weis, "g");
    }

    function testBuyerCount() {
        con.startSampleSale();
        Sale sale = ico.sales(0);
        ico.setFakeTime(3 days + 2);
        p1.deposit.value(1)();
        p1.deposit.value(2)();
        p3.deposit.value(2)();

        assertEq(ico.numContributors(0), 2, "count");
    }


    function testStopAndRefund() {
        uint weis = 1000;

        con.startSampleSale();
        ico.setFakeTime(3 days + 2);

        p1.deposit.value(weis)();

        ico.allStop();
        ico.allStart();

        p1.deposit.value(weis)();

        ico.allStop();

        ico.emergencyRefund(address(p1), weis * 2);
        assertEq(address(p1).balance, weis * 2, "emergency refund");
    }

    function testThrowStop() {
        uint weis = 1000;
        con.startSampleSale();
        ico.setFakeTime(3 days + 2);
        ico.allStop();
        p1.deposit.value(weis)();
    }

    function testThrowEmergencyRefundWithoutStop() {
        uint weis = 1000;
        con.startSampleSale();
        ico.setFakeTime(3 days + 2);
        p1.deposit.value(weis)();
        ico.emergencyRefund(address(p1), weis);
    }

    function testSetPayee() {
        ico.changePayee(0x0);
        assertEq(ico.payee(), 0x0, "payee");
    }
        
    /*  Fix this test */
    function testPurchaseByToken() {
        uint weis = 1000;

        con.startSampleSaleFastMint();
        ico.setFakeTime(3 days + 2);

        assertEq(ico.currSaleActive(), true, "active");
        assertEq(ico.currSaleComplete(), false, "complete");

        assertEq(ico.tokensPerEth(), 1, "tokens per eth");
        assertEq(weiPerEth, 200, "wei per eth");

        address tok = address(new Token());
        ico.depositTokens(address(p1), 0x1, weis, 100, bytes32(0x123));

        assertEq(token.balanceOf(address(p1)), 1000 / weiPerEth, "fast mint");
        assertEq(p1.claimableRefund(), 0, "incomplete refund");
        assertEq(p1.claimableTokens(), 0, "incomplete tokens");
    }

    function testThrowsPurchaseByToken() {
        uint weis = 1000;

        con.startSampleSaleFastMint();
        ico.setFakeTime(3 days + 2);

        assertEq(ico.currSaleActive(), true, "active");
        assertEq(ico.currSaleComplete(), false, "complete");

        ico.depositTokens(address(p1), 0x1, weis, 100, bytes32(0x123));
        ico.depositTokens(address(p1), 0x1, weis, 100, bytes32(0x123));
    }

    function testChangeOwner() {
        ico.changeOwner(address(p1));
        p1.acceptOwnership();
        assertEq(ico.owner(), address(p1), "owner");
    }

}

