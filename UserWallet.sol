pragma solidity ^0.4.18;

import 'Ownable.sol';
import 'ERC20Basic.sol';
import 'SafeMath.sol';
import "AigoTokensale.sol";


contract UserWallet is Ownable {
    using SafeMath for uint256;

    address public payoutWallet;
    AigoTokensale public tokensale;

    constructor(address _payoutWallet, AigoTokensale _tokensale) Ownable() public {
        require(_tokensale != address(0));
        payoutWallet = _payoutWallet;
        tokensale = _tokensale;
    }

    function onDelivery() public {
        require(msg.sender == address(tokensale));
        if (payoutWallet != address(0)) {
            ERC20Basic token = tokensale.token();
            uint256 balance = token.balanceOf(this);
            require(token.transfer(payoutWallet, balance));
        }
    }

    function forwardTokens(ERC20Basic token, address _to) public onlyOwner {
        uint256 balance = token.balanceOf(this);
        require(token.transfer(payoutWallet, balance));
    }

    function setPayoutWallet(address _payoutWallet) public onlyOwner {
        payoutWallet = _payoutWallet;
    }


    function() public payable {
        tokensale.transfer(msg.value);
    }

}
