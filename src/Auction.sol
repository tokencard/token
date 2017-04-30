pragma solidity ^0.4.4;

import "Common.sol";

contract AuctionLauncher {
    function launch(address _ico, uint _numTokens, uint _target, uint _minEth, uint _daysUntilStart, uint _daysLong, uint _time) 
    returns (address) {
        return address(new Auction(_ico, _numTokens, _target, _minEth, _daysUntilStart, _daysLong, _time));
    }
}

contract Auction is Owned, SafeMath, EventDefinitions, Sale {
    uint public numTokens; 
    uint public minEth;
    event logSaleStart(uint startTime, uint stopTimej);
    
    function Auction(address _ico, uint _numTokens, uint _target, uint _minEth, uint _daysUntilStart, uint _daysLong, uint _time) {
        //to avoid potential divide-by-zero
        //(in practice unlikely except in testing):
        if (_target < _numTokens) throw;

        owner = _ico;
        numTokens = _numTokens;
        target = _target;
        minEth = _minEth;
        startTime = _time + (_daysUntilStart * 1 days);
        stopTime = startTime + (_daysLong * 1 days);
        logSaleStart(startTime, stopTime);
    }

    function buyTokens(address _a, uint _eth, uint _time) onlyOwner returns (uint) {
        if (balances[_a] == 0) {
            numContributors += 1;
        }
        balances[_a] = safeAdd(balances[_a], _eth);
        raised = safeAdd(raised, _eth);

        return 0;
    }

    function getPayout(address _a) private returns (uint tokens, uint refund) {
        if (balances[_a] == 0) {
            tokens = 0;
            refund = 0;
            return;
        }

        //suppose raised < numTokens
        //then weiPerToken rounds off to zero
        //and we'd get a divide-by-zero error later
        if (raised < numTokens || raised < minEth) {
            tokens = 0;
            refund = balances[_a];
            return;
        }

        uint deposit = balances[_a];
        uint weiPerToken = raised / numTokens;

        if (raised <= target) {
            refund = 0;
            tokens = deposit / weiPerToken;
        } else {
            uint effectiveDeposit = safeMul(deposit, target) / raised;
            refund = deposit - effectiveDeposit;
            tokens = effectiveDeposit / weiPerToken;
        }
    }

    function getTokens(address _a) constant returns (uint tokens) {
        var (tok, _) = getPayout(_a);
        tokens = tok;
    }

    function getRefund(address _a) constant returns (uint refund) {
        var (_, ref) = getPayout(_a);
        refund = ref;
    }

    function getSoldTokens() constant returns (uint) { 
        if (raised == 0) return 0;
        if (raised < minEth) return 0;

        //if raise less than target we always sell all the tokens
        //at whatever price necessary
        if (raised < target) return numTokens;

        //We've already returned if raised < target
        //We require target > numtokens
        //so no worries about divide-by-zero here:
        uint weiPerToken = raised / numTokens;
        return target / weiPerToken;
    }

    //same as overage sale
    //either keep target, or whatever you raise under target
    function getOwnerEth() constant returns (uint) {
        if (raised == 0) return 0;
        if (raised < minEth) return 0;
        if (raised < target) return raised;
        return target;
    }

    function isActive(uint _time) constant returns (bool) {
        return (_time >= startTime &&
                _time <= stopTime);
    }

    function isComplete(uint _time) constant returns (bool) {
        return (_time > stopTime);
    }

    //just to match interface
    function tokensPerEth() constant returns (uint) {
        return 0;
    }
    
    
}

