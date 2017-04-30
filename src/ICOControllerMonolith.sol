pragma solidity ^0.4.4;

import "Common.sol";
import "Token.sol";
import "ICO.sol";
import "FirstSale.sol";
import "Auction.sol";

contract ICOControllerMonolith is SafeMath, Owned, Constants {
    ICO public ico;
    uint weiPerDollar;
    address advisor;
    uint auctionTokensSold;

    FirstSaleLauncher firstSaleLauncher;
    AuctionLauncher auctionLauncher;
    function setFirstSaleLauncher(address a) onlyOwner setupNotComplete {
        firstSaleLauncher = FirstSaleLauncher(a);
    }
    function setAuctionLauncher(address a) onlyOwner setupNotComplete {
        auctionLauncher = AuctionLauncher(a);
    }
    
    function ICOControllerMonolith() {
        owner = msg.sender;
    }

    function setICO(address _ico) 
    onlyOwner 
    setupNotComplete 
    {
        ico = ICO(_ico);
    }

    function setAdvisor(address _advisor) onlyOwner {
        if (advisor != address(0)) throw;
        advisor = _advisor;
    }

    function setupComplete() private returns (bool) {
        return (
            address(firstSaleLauncher) != address(0) &&
            address(auctionLauncher) != address(0) &&
            address(ico) != address(0) &&
            address(ico.token()) != address(0));
    }

    modifier setupIsComplete() {
        if (!setupComplete()) throw;
        _;
    }

    modifier setupNotComplete() {
        if (setupComplete()) throw;
        _;
    }

    modifier firstSaleComplete() {
        if (!ico.sales(0).isComplete(ico.currTime())) throw;
        _;
    }

    modifier onlyICO() {
        if (msg.sender != address(ico)) throw;
        _;
    }

    function startFirstSale(uint _weiPerDollar) onlyOwner setupIsComplete {
        weiPerDollar = _weiPerDollar;
        address firstsale = firstSaleLauncher.launch(address(ico), weiPerDollar, ico.weiPerEth(), ico.currTime());
        ico.addSale(firstsale);
    }

    function getCurrSale() constant returns (uint) {
        if (ico.numSales() == 0) throw; //no reason to call before startFirstSale
        return ico.numSales() - 1;
    }

    function currSaleIsActive() constant returns (bool) {
        return ico.sales(getCurrSale()).isActive(ico.currTime());
    }

    function availableAuctionTokens() constant returns (uint) {
        uint time = ico.currTime();
        uint soldTokens;
        for (uint i = 1; i < ico.numSales(); i++) {
            soldTokens = safeAdd(soldTokens, ico.sales(i).getSoldTokens());
        }
        return safeSub(auctionTokens(), soldTokens); 
    }

    function launchAuction(uint _numTokens, uint _target, uint _minEth, uint _daysUntilStart, uint _daysLong) 
    {
        launchAuctionWithMinimum(_numTokens, _target, _minEth, _daysUntilStart, _daysLong, 0);
    }

    function launchAuctionWithMinimum(uint _numTokens, uint _target, uint _minEth, uint _daysUntilStart, uint _daysLong,
        uint _minimum) 
    onlyOwner setupIsComplete {
        //can't launch an auction unless previous sale is complete
        if (!ico.sales(getCurrSale()).isComplete(ico.currTime())) throw;

        //can't exceed remaining available auction tokens
        if (_numTokens > availableAuctionTokens()) throw;

        address auction = auctionLauncher.launch(address(ico), _numTokens, _target, _minEth, _daysUntilStart, _daysLong, ico.currTime());
        ico.addSale(auction, _minimum);
    }
/*
Example from whitepaper: 
5 million TKN created in firstsale from incoming payments. Also created:
• 1,666,667 TKN for Monolith Studio
• 416,666 TKN for advisors
• 1,250,000 TKN for the Reserve (auctions)
In total, 7,083,333 TKN are ‘issued’ and 1,250,000 TKN are held in reserve.
Owner is firstsale / 3
Advisor is firstsale / 12
Auction is firstsale / 4
*/

    function advisorTokens() constant returns (uint) {
        uint time = ico.currTime();
        uint tokens;
        if (ico.sales(0).isComplete(time)) {
            tokens = ico.sales(0).getSoldTokens() / 12;
        }
        return tokens;
    }

    function ownerTokens() constant returns (uint) {
        uint time = ico.currTime();
        uint tokens;
        if (ico.sales(0).isComplete(time)) {
            tokens = ico.sales(0).getSoldTokens() / 3;
        }
        return tokens;
    }

    function auctionTokens() constant returns (uint) {
        uint time = ico.currTime();
        uint tokens;
        if (ico.sales(0).isComplete(time)) {
            tokens = ico.sales(0).getSoldTokens() / 4;
        }
        return tokens;
    }

    function totalTokenSupply() constant returns (uint) {
        uint time = ico.currTime();
        uint totalTokens = ico.sales(0).getSoldTokens();
        if (ico.sales(0).isComplete(time)) {
            totalTokens = safeAdd(totalTokens, auctionTokens());
            totalTokens = safeAdd(totalTokens, ownerTokens());
            totalTokens = safeAdd(totalTokens, advisorTokens());
        }
        return totalTokens;
    }

    bool mintedOwnerTokens;
    bool mintedAdvisorTokens;

    function mintOwnerTokens() onlyOwner {
        if (mintedOwnerTokens) throw;

        //owner can only claim tokens after 18 months
        uint time = ico.currTime();
        if (ico.currTime() < ico.sales(0).startTime() + 540 days) {
            throw;
        }

        mintedOwnerTokens = true;
        ico.token().mint(owner, ownerTokens());
    }

    function mintAdvisorTokens() firstSaleComplete {
        if (msg.sender != owner) throw;
        if (mintedAdvisorTokens) throw;

        mintedAdvisorTokens = true;
        ico.token().mint(advisor, advisorTokens());
    }

    //allow non-auction sales
    function launchSale(address _sale) 
    onlyOwner 
    setupIsComplete 
    {
        //can't launch a sale unless previous sale is complete
        if (!ico.sales(getCurrSale()).isComplete(ico.currTime())) throw;

        //can't launch unless token has its max set
        //token will refuse to mint excess this way
        if (ico.token().maxSupply() == 0) throw;

        ico.addSale(_sale);
    }

    //set token max
    //arbitrary sales can't be launched until this is done
    function setTokenMax() onlyOwner firstSaleComplete {
        ico.token().setMaxSupply(totalTokenSupply());
    }
}

