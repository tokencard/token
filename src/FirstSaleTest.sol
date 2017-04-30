pragma solidity 0.4.4;

import 'dapple/test.sol'; 
import 'Common.sol';
import 'FirstSale.sol';

contract FirstSaleTest is Test, EventDefinitions, Constants {
    FirstSale sale;
    address a1 = address(1);
    address a2 = address(2);
    address a3 = address(3);
    address a4 = address(4);
    address a5 = address(5);
    address a6 = address(6);
    uint weiPerDollar = 20;
    uint weiPerEth = 200;
    uint startTime = 1;

    uint RATE0 = 150 * (uint(10)**DECIMALS);
    uint RATE1 = 140 * (uint(10)**DECIMALS);
    uint RATE2 = 130 * (uint(10)**DECIMALS);
    uint RATE3 = 120 * (uint(10)**DECIMALS);
    uint RATE4 = 110 * (uint(10)**DECIMALS);
    uint RATE5 = 100 * (uint(10)**DECIMALS);

    uint TARGET = 750000 * 6;
    uint MINIMUM = 0;
    
    uint increment = 750000;
    uint THRESHOLD1 = 750000;
    uint THRESHOLD2 = increment * 2;
    uint THRESHOLD3 = increment * 3;
    uint THRESHOLD4 = increment * 4;
    uint THRESHOLD5 = increment * 5;

    function setUp() {
        sale = new FirstSale(address(this), weiPerDollar, weiPerEth, startTime);
    }

    function eth(uint eth) returns (uint) {
        return eth * weiPerEth;
    }
    function dollars(uint dollars) returns (uint) {
        return dollars * weiPerDollar;
    }

    function testBasicPurchase() {
        assertEq(uint(DECIMALS), 8, "8 decimals");
        assertEq(uint(10)**DECIMALS, uint(100000000), "Decimals");
        assertEq(RATE2, 13000000000, "RATE2");

        assertEq(sale.target(), dollars(TARGET), "target");
        assertEq(sale.minEth(), 0, "mineth");

        uint tok = sale.buyTokens(a1, eth(1), startTime + 1);
        assertEq(tok, RATE0, "tok");
        assertEq(sale.balances(a1), eth(1), "a1 eth balance");
        assertEq(sale.getTokens(a1), 0, "a1 tokens"); //0 because immediate mint
        assertEq(sale.getRefund(a1), 0, "a1 refund");
        assertEq(sale.raised(), eth(1), "raised");
        assertEq(sale.getOwnerEth(), eth(1), "owner eth");
    }

    function testZero() {
        sale.buyTokens(a1, 0, startTime + 1);
        assertEq(sale.balances(a1), 0, "a1 eth balance");
        assertEq(sale.getTokens(a1), 0, "a1 tokens");
        assertEq(sale.raised(), 0, "raised");
        assertEq(sale.getOwnerEth(), 0, "owner eth");
    }


    function testOverMinimum1() {
        //previous thresholds 50,125,200
        //thresholds in ether at $10/eth:
        //minimum = 50,000
        //75,000
        //150,000
        //300,000
        //450,000
        assertEq(sale.tokensPerEth(), RATE0, "starting rate");

        //first deposit, less than minimum
        uint firstDeposit = 49990;
        uint tok1 = sale.buyTokens(a1, eth(firstDeposit), startTime + 1);
        assertEq(tok1, 49990 * RATE0, "minted first tokens");
        assertEq(sale.balances(a1), eth(firstDeposit), "a1 eth balance");
        assertEq(sale.getTokens(a1), 0, "a1 first tokens");
        assertEq(sale.getRefund(a1), 0, "a1 first refund");
        assertEq(sale.tokensPerEth(), RATE0, "second rate");

        //second deposit, taking it over minimum, still at first rate
        uint secondDeposit = 20000;
        uint tok = sale.buyTokens(a2, eth(secondDeposit), startTime + 2);
        assertEq(sale.balances(a2), eth(secondDeposit), "a2 eth balance");
        assertEq(tok, RATE0 * secondDeposit, "a2 tokens");
        assertEq(sale.getTokens(a3), 0, "a3 tokens");
        assertEq(sale.getRefund(a2), 0, "a2 refund");
        assertEq(sale.tokensPerEth(), RATE0, "third rate");

        //now we're over minimum so a1 doesn't get refund
        assertEq(sale.getRefund(a1), 0, "a1 second refund");

        //third deposit, taking it to second rate
        uint thirdDeposit = 75000;
        tok = sale.buyTokens(a3, eth(thirdDeposit), startTime + 3);
        assertEq(sale.balances(a3), eth(thirdDeposit), "a3 eth balance");
        assertEq(tok, RATE0 * thirdDeposit, "a3 tokens");
        assertEq(sale.getTokens(a3), 0, "a3 tokens");
        assertEq(sale.tokensPerEth(), RATE1, "fourth rate");


        assertEq(sale.getSoldTokens(), (RATE0 * firstDeposit) + (RATE0 * secondDeposit) + (RATE0 * thirdDeposit), "sold Tokens");
        //reached minimum 
        assertEq(sale.getOwnerEth(), sale.raised(), "owner eth");
    }

    function testOverMinimum2() {
        uint eths;
        uint weis;

        eths = 100000;
        weis = eth(eths);
        uint tok = sale.buyTokens(a1, weis, startTime + 1);
        assertEq(sale.balances(a1), weis, "a1 eth balance");
        assertEq(tok, RATE0 * eths, "a1 tokens");
        assertEq(sale.tokensPerEth(), RATE1, "second rate");

        eths = 90000;
        weis = eth(eths);
        tok = sale.buyTokens(a2, weis, startTime + 1);
        assertEq(sale.balances(a2), weis, "a2 eth balance");
        assertEq(tok, RATE1 * eths, "a2 tokens");
        assertEq(sale.tokensPerEth(), RATE2, "third rate");

        assertEq(sale.getOwnerEth(), sale.raised(), "owner eth");
    }

    function testOverMaximum() {
        uint eths = 449000;
        uint weis = eth(eths);
        uint tok = sale.buyTokens(a1, weis, startTime);
        assertEq(sale.balances(a1), weis, "a1 eth balance");
        assertEq(tok, RATE0 * eths, "a1 tokens");
        assertEq(sale.tokensPerEth(), RATE5, "second rate");

        eths = 3000;
        weis = eth(eths);
        uint currTime = startTime + 2;
        tok = sale.buyTokens(a2, weis, currTime);
        assertEq(sale.balances(a2), eth(3000), "a2 eth balance");
        assertEq(sale.getRefund(a2), 0, "a2 refund");
        assertEq(tok, RATE5 * 3000, "a2 tokens");
        assertEq(sale.stopTime(), currTime + 1 days, "stoptime");

        assertEq(sale.tokensPerEth(), RATE5, "third rate");
    }

    function testOneGiant() {
        uint eths = 500000;
        uint maxeths = 450000;
        uint weis = eth(eths);
        uint tok = sale.buyTokens(a1, weis, startTime);
        assertEq(sale.balances(a1), weis, "a1 eth balance");
        assertEq(tok, RATE0 * eths, "a1 tokens");
        assertEq(sale.getRefund(a1), 0, "a1 refund");
        assertEq(sale.stopTime(), startTime + 1 days, "stoptime");
    }
}



