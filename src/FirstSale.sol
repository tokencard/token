pragma solidity ^0.4.4;

import "Common.sol";

contract FirstSaleLauncher {
    function launch(address ico, uint _weiPerDollar, uint _weiPerEth, uint _time) 
    returns (address) {
        return address(new FirstSale(ico, _weiPerDollar, _weiPerEth, _time));
    }
}

contract FirstSale is Sale, SafeMath, EventDefinitions, Owned, Constants {
    uint public minEth;
    uint[6] rates;      //tokens per ETH
    uint[6] thresholds; //in dollars
    uint weiPerEth;
    uint public hardcap; //dollars

    uint totalSaleTokens;
    
    mapping (address => uint) tokens;
    
    function FirstSale(address ico, uint _weiPerDollar, uint _weiPerEth, uint _time) {
        owner = ico;
        startTime = _time;
        stopTime = _time + 7 days;

        uint increment = 750000;
        uint targetDollars = increment * 6; // $4.5 million
        target = safeMul(targetDollars, _weiPerDollar);        
        hardcap = safeMul(12500000, _weiPerDollar);
        minEth = 0; 
        weiPerEth = _weiPerEth;
        
        //rates are per ether (not dollar or wei)
        uint nextThreshold = 0;

        rates[0] = 150 * (uint(10)**DECIMALS);
        thresholds[0] = 0;

        rates[1] = 140 * (uint(10)**DECIMALS);
        nextThreshold += increment;
        thresholds[1] = safeMul(nextThreshold, _weiPerDollar);

        rates[2] = 130 * (uint(10)**DECIMALS);
        nextThreshold += increment;
        thresholds[2] = safeMul(nextThreshold, _weiPerDollar);

        rates[3] = 120 * (uint(10)**DECIMALS);
        nextThreshold += increment;
        thresholds[3] = safeMul(nextThreshold, _weiPerDollar);

        rates[4] = 110 * (uint(10)**DECIMALS);
        nextThreshold += increment;
        thresholds[4] = safeMul(nextThreshold, _weiPerDollar);

        rates[5] = 100 * (uint(10)**DECIMALS);
        nextThreshold += increment;
        thresholds[5] = safeMul(nextThreshold, _weiPerDollar);

        logSaleStart(startTime, stopTime);
    }

    function tokensPerEth() constant returns (uint rate) {
        for (uint i = 0; i < rates.length; i++) {
            if (raised >= thresholds[i]) rate = rates[i];
        }
    }

    event logExcess(address a, uint sent, uint refund);

    bool earlyStop;
    
    function buyTokens(address _a, uint _eth, uint _time) onlyOwner returns (uint) {
        if (balances[_a] == 0) {
            numContributors += 1;
        }

        balances[_a] = safeAdd(balances[_a], _eth);

        if (!earlyStop && safeAdd(raised, _eth) >= target) {
            stopTime = _time + 1 days;
            earlyStop = true;
        }

        uint effectiveEth = _eth;
        if (_eth + raised > hardcap) {
            effectiveEth = hardcap - raised;
            logExcess(_a, _eth, raised + _eth - hardcap);
        }

        uint userTokens = safeMul(effectiveEth, tokensPerEth()) / weiPerEth;

        raised = safeAdd(raised, effectiveEth);
        totalSaleTokens = safeAdd(totalSaleTokens, userTokens);
        tokens[_a] = safeAdd(tokens[_a], userTokens);

        return userTokens; //will be minted immediately
    }

    //these are the unminted tokens, given to ico for minting in claim()
    //for auction, that's how user gets tokens
    //in firstsale, the tokens are minted immediately
    //so we have to return 0 here
    function getTokens(address _a) constant returns (uint) {
        return 0;
    }

    //only refund if we never met the minimum so you get all your money back
    function getRefund(address _a) constant returns (uint) {
        if (raised >= minEth) {
            return 0;
        } else {
            return balances[_a];
        }
    }

    function getSoldTokens() constant returns (uint) {
        return totalSaleTokens;
    }

    function getOwnerEth() constant returns (uint) {
        if (raised < minEth) return 0;
        return raised;
    }

    function isActive(uint _time) constant returns (bool) {
        return (_time >= startTime && _time <= stopTime
                && raised < hardcap);
    }

    function isComplete(uint _time) constant returns (bool) {
        return (_time > stopTime || raised >= hardcap);
    }

}


