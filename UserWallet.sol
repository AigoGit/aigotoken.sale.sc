pragma solidity ^0.4.18;

import './Ownable.sol';
import './ERC20Basic.sol';
import './SafeMath.sol';
import "./AigoTokensale.sol";


contract UserWallet is Ownable {
    using SafeMath for uint256;

    address public payoutWallet;
    address public vaultWallet;
    AigoTokensale public tokensale;

    constructor(address _payoutWallet, address _vaultWallet, address _owner) public {
      require(_vaultWallet != address(0));
      payoutWallet = _payoutWallet;
      vaultWallet = _vaultWallet;
      tokensale = AigoTokensale(msg.sender);
      owner = _owner;
    }

    function onDelivery() public {
        require(msg.sender == address(tokensale));
        if (payoutWallet != address(0)) {
            ERC20Basic token = tokensale.token();
            uint256 balance = token.balanceOf(this);
            require(token.transfer(payoutWallet, balance));
        }
    }

    function setPayoutWallet(address _payoutWallet) public onlyOwner {
        payoutWallet = _payoutWallet;
        if (payoutWallet != address(0)) {
            ERC20Basic token = tokensale.token();
            uint256 balance = token.balanceOf(this);
            if (balance > 0) {
                require(token.transfer(payoutWallet, balance));
            }
        }
    }

    function() public payable {
        tokensale.postWalletPayment(msg.value);
        vaultWallet.transfer(msg.value);
    }

}
