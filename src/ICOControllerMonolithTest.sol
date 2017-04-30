pragma solidity >=0.4.4;

import 'dapple/test.sol'; 
import 'Common.sol';
import 'ICO.sol';
import 'FirstSale.sol';
import 'ICOControllerMonolith.sol';

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

    function () payable {
    }
}

contract ICOControllerMonolithTest is Test, EventDefinitions, Constants {
    ICO ico;
    ICOControllerMonolith con;
    Person p1;
    Person p2;
    Person p3;
    Person p4;
    Person p5;
    Person p6;
    Person p7;
    Person advisor;
    Token token;

    //for testing we say 10 weis makes an eth
    //because dapple only gives us 10 eths to work with
    //so let's say 1 ether = 10 dollars = 200 wei
    uint weiPerDollar = 20; 
    uint weiPerEth = 200;

    uint RATE0 = 150 * (uint(10)**DECIMALS);
    uint RATE1 = 140 * (uint(10)**DECIMALS);
    uint RATE2 = 130 * (uint(10)**DECIMALS);
    uint RATE3 = 120 * (uint(10)**DECIMALS);
    uint RATE4 = 110 * (uint(10)**DECIMALS);

    uint TARGET = 750000 * 5;
    uint MINIMUM = 500000;
    
    uint increment = 750000;
    uint THRESHOLD1 = 750000;
    uint THRESHOLD2 = increment * 2;
    uint THRESHOLD3 = increment * 3;
    uint THRESHOLD4 = increment * 4;
    uint THRESHOLD5 = increment * 5;

    function () payable {}

    function eth(uint eth) returns (uint) {
        return eth * weiPerEth;
    }
    function dollars(uint dollars) returns (uint) {
        return dollars * weiPerDollar;
    }
    
    function setUp() {
        con = new ICOControllerMonolith();

        ico = new ICO();
        con.setICO(address(ico));
        ico.setAsTest();
        ico.setController(con);
        token = new Token();
        token.setICO(address(ico));
        token.setController(address(con));
        ico.setToken(token);
        con.setFirstSaleLauncher(new FirstSaleLauncher());
        con.setAuctionLauncher(new AuctionLauncher());
        advisor = new Person(address(ico));
        con.setAdvisor(address(advisor));

        ico.setFakeTime(1);
        weiPerEth = ico.weiPerEth();
        p1 = new Person(address(ico));
        p2 = new Person(address(ico));
        p3 = new Person(address(ico));
        p4 = new Person(address(ico));
        p5 = new Person(address(ico));
        p6 = new Person(address(ico));
        p7 = new Person(address(ico));
    }

    function testFirstSaleNum() {
        con.startFirstSale(weiPerDollar);
        assertEq(ico.getCurrSale(), 0, "first sale not set");
        assertEq(ico.nextClaim(address(p1)), 0, "first claim");
    }

    function testBuyOneEther() {
        uint eths = 1;
        uint weis = eth(eths);

        con.startFirstSale(weiPerDollar);

        assertEq(ico.weiPerEth(), 200, "wei per eth");
        assertEq(ico.currSaleActive(), true, "active");
        assertEq(ico.currSaleComplete(), false, "complete");

        p1.deposit.value(weis)();
        assertEq(ico.claimableRefund(address(p1)), 0, "incomplete refund");
        assertEq(ico.claimableTokens(address(p1)), 0, "incomplete tokens");

        ico.addDays(20);
        assertEq(ico.currSaleActive(), false, "2 active");
        assertEq(ico.currSaleComplete(), true, "2 complete");
        assertEq(token.balanceOf(address(p1)), RATE0 * eths, "minted tokens");
        assertEq(ico.claimableRefund(address(p1)), 0, "complete refund");
        assertEq(ico.claimableTokens(address(p1)), 0, "complete tokens");
    }

    function testBuyMaxEther() {
        assertEq(ico.weiPerEth(), 200, "wei per eth");
        con.startFirstSale(weiPerDollar);

        uint weis = dollars(3750000);
        uint eths = weis / weiPerEth;

        p1.deposit.value(weis)();
        assertEq(ico.claimableRefund(address(p1)), 0, "refund");
        assertEq(token.balanceOf(address(p1)), RATE0 * eths, "tokens");
        assertEq(ico.claimableTokens(address(p1)), 0, "claimable tokens");
    }

    function testFullSequence() {
        uint weimax = dollars(4500000);
        uint weis = weimax + eth(1000);
        uint eths = weis / weiPerEth;
        uint mult = 10**DECIMALS;
        uint firstTokens = eths * 150 * mult;
        uint auctionTokens = firstTokens / 4;
        uint advisorTokens = firstTokens / 12;
        uint ownerTokens = firstTokens / 3;
        uint tokenSupply = firstTokens + auctionTokens + 
                           advisorTokens + ownerTokens;

        con.startFirstSale(weiPerDollar);
        ico.addDays(1);
        assertEq(ico.getCurrSale(), 0, "curr sale 0");

        p1.deposit.value(weis)();
        assertEq(ico.claimableRefund(address(p1)), 0, "refund");
        assertEq(ico.claimableTokens(address(p1)), 0, "tokens");
        assertEq(ico.token().balanceOf(address(p1)), firstTokens, "first token balance");
        assertEq(ico.sales(0).stopTime(), ico.currTime() + 1 days, "stop time");
        
        ico.addDays(2);

        assertEq(con.totalTokenSupply(), tokenSupply, "token supply");

        //this does nothing right now, no refund no new mint
        //p1.claim(); 
        //assertEq(ico.nextClaim(address(p1)), 1, "p1 next claim");


        //Now let's do an auction
        //1000 tokens, we'll send twice target hence sell 500 tokens
        con.launchAuction(1000, eth(100), 0, 0, 3);
        assertEq(ico.getCurrSale(), 1, "curr sale 1");

        assertEq(con.availableAuctionTokens(), auctionTokens, "auction tokens 1");
        assertEq(ico.currSaleActive(), true, "auction 1 active");

        p5.deposit.value(eth(40))();
        p6.deposit.value(eth(60))();
        p7.deposit.value(eth(100))();
        ico.addDays(10);
        assertEq(ico.currSaleActive(), false, "auction 1 inactive");

        assertEq(ico.claimableTokens(address(p5)), 100, "a5 tokens auction1");
        assertEq(ico.claimableTokens(address(p6)), 150, "a6 tokens auction1");
        assertEq(ico.claimableTokens(address(p7)), 250, "a7 tokens auction1");

        assertEq(ico.claimableRefund(address(p5)), eth(20), "a5 refund auction1");
        assertEq(ico.claimableRefund(address(p6)), eth(30), "a6 refund auction1");
        assertEq(ico.claimableRefund(address(p7)), eth(50), "a7 refund auction1");

        p5.claim();
        p6.claim();
        p7.claim();

        assertEq(p5.balance, eth(20), "p5 balance");
        assertEq(p6.balance, eth(30), "p6 balance");
        assertEq(p7.balance, eth(50), "p7 balance");
        assertEq(token.balanceOf(address(p5)), 100, "p5 minted tokens");
        assertEq(token.balanceOf(address(p6)), 150, "p6 minted tokens");
        assertEq(token.balanceOf(address(p7)), 250, "p7 minted tokens");

        assertEq(ico.claimableRefund(address(p2)), 0, "p2 refund");
        assertEq(ico.claimableTokens(address(p2)), 0, "p2 tokens");

        //Make sure we're decrementing available auction tokens
        assertEq(con.availableAuctionTokens(), auctionTokens - 500, "auction tokens 2");

        uint tokens = 1000;
        uint target = eth(100);

        con.launchAuction(tokens, target, 0, 0, 3);

        p1.deposit.value(eth(40))();
        p2.deposit.value(eth(60))();
        p3.deposit.value(eth(100))();

        ico.addDays(10);

        uint raised = eth(200);
        uint weiPerToken = raised / tokens;

        assertEq(ico.claimableTokens(address(p1)), 100, "a1 tokens auction2");
        assertEq(ico.claimableTokens(address(p2)), 150, "a2 tokens auction2");
        assertEq(ico.claimableTokens(address(p3)), 250, "a3 tokens auction2");

        assertEq(ico.claimableRefund(address(p1)), eth(20), "a1 refund auction2");
        assertEq(ico.claimableRefund(address(p2)), eth(30), "a2 refund auction2");
        assertEq(ico.claimableRefund(address(p3)), eth(50), "a3 refund auction2");

        //have to put the rest in another function
        //due to limit on number of local variables
    }

    function testOwnerWithdraw() {
        uint weis = dollars(1000000);
        uint eths = weis / weiPerEth;
        uint mult = 10**DECIMALS;
        uint firstTokens = eths * 150 * mult;
        uint auctionTokens = firstTokens / 4;
        uint advisorTokens = firstTokens / 12;
        uint ownerTokens = firstTokens / 3;
        uint tokenSupply = firstTokens + auctionTokens + 
                           advisorTokens + ownerTokens;

        con.startFirstSale(weiPerDollar);
        assertEq(ico.getCurrSale(), 0, "curr sale 0");

        p1.deposit.value(weis)();
        ico.addDays(1000);

        //withdraw owner's stuff

        assertEq(ico.owner(), address(this), "ico owner");
        assertEq(con.owner(), address(this), "con owner");
        
        uint ownereth = ico.claimableOwnerEth(0);
        assertEq(ownereth, weis, "available owner eth");

        uint oldbalance = address(this).balance;
        ico.claimOwnerEth(0);
        uint newbalance = address(this).balance;
        //This could fail but apparent gas price is zero in dapple
        assertEq(newbalance - oldbalance, weis, "old balance");

        ico.addDays(1000);
    
        assertEq(ico.sales(0).isComplete(ico.currTime()), true, "complete");

        assertEq(con.ownerTokens(), ownerTokens, "owner token balance");
        con.mintOwnerTokens();
        assertEq(token.balanceOf(address(this)), ownerTokens, "owner tokens");

        con.mintAdvisorTokens();
        assertEq(token.balanceOf(address(advisor)), advisorTokens, "advisor tokens");
    }

    function testThrowsAuctionMinimumPurchase() {
        uint weis = dollars(1000000);
        uint eths = weis / weiPerEth;

        con.startFirstSale(weiPerDollar);
        p1.deposit.value(weis)();

        ico.addDays(30);

        //Now let's do an auction
        //1000 tokens, 100 eth target, 50 eth minimum
        con.launchAuctionWithMinimum(1000, eth(100), 0, 0, 3, eth(50));

        assertEq(ico.getCurrSale(), 1, "curr sale 1");
        assertEq(ico.currSaleActive(), true, "auction 1 active");

        p2.deposit.value(eth(40))();
    }

    function testAuctionMax() {
        uint weis = dollars(1000000);
        uint eths = weis / weiPerEth;
        uint mult = 10**DECIMALS;
        uint firstTokens = eths * 150 * mult;
        uint auctionTokens = firstTokens / 4;
        uint advisorTokens = firstTokens / 12;
        uint ownerTokens = firstTokens / 3;
        uint tokenSupply = firstTokens + auctionTokens + 
                           advisorTokens + ownerTokens;
    
        con.startFirstSale(weiPerDollar);
        p1.deposit.value(weis)();

        ico.addDays(30);

        assertEq(con.availableAuctionTokens(), auctionTokens, "available auction tokens");

        //_numTokens, _target, _minEth, _daysUntilStart, _daysLong,
        con.launchAuctionWithMinimum(auctionTokens, auctionTokens+1, 0, 0, 3, eth(500));
    }

    function testThrowsAuctionOverMax() {
        uint weis = dollars(1000000);
        uint eths = weis / weiPerEth;
        uint mult = 10**DECIMALS;
        uint firstTokens = eths * 150 * mult;
        uint auctionTokens = firstTokens / 4;
        uint advisorTokens = firstTokens / 12;
        uint ownerTokens = firstTokens / 3;
        uint tokenSupply = firstTokens + auctionTokens + 
                           advisorTokens + ownerTokens;
    
        con.startFirstSale(weiPerDollar);
        p1.deposit.value(weis)();

        ico.addDays(30);

        //Now let's do an auction with too many tokens
        con.launchAuctionWithMinimum(auctionTokens+1, auctionTokens+2, 0, 0, 3, eth(50));
    }

    function testThrowsAddSale() {
        uint weis = dollars(1000000);
        con.startFirstSale(weiPerDollar);
        p1.deposit.value(weis)();
        ico.addDays(30);

        con.launchSale(0x1);
    }

    function testAddSale() {
        uint weis = dollars(1000000);
        con.startFirstSale(weiPerDollar);
        p1.deposit.value(weis)();
        ico.addDays(30);
        
        con.setTokenMax();
        con.launchSale(new SampleSale(0));
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


