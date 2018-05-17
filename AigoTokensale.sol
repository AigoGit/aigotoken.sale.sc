pragma solidity ^0.4.21;

import "./ERC20Basic.sol";
import "./Ownable.sol";
import "./UserWallet.sol";

contract AigoTokensale is Ownable {

  struct InvestorPayment {
    uint256 time;
    uint256 weiValue;
    uint256 baseValue;
  }

  struct Investor {
    bool isUserWallet;
    InvestorPayment[] payments;
    uint256 tokenAmount;
    bool delivered;
  }

  event InvestorAdded(address indexed investor);
  event TokensaleFinishTimeChanged(uint256 oldTime, uint256 newTime);
  event Payment(address indexed investor, uint256 weiValue, uint256 baseValue);
  event TokenAmountUpdated(address indexed investor, uint256 tokenAmount);
  event Delivered(address indexed investor, uint256 amount);
  event TokensaleFinished(uint256 tokensSold, uint256 tokensReturned);

  ERC20Basic public token;
  uint256 public finishTime;
  address vaultWallet;

  UserWallet[] public investorList;
  mapping(address => Investor) investors;

  function investorListLength() public view returns (uint) {
    return investorList.length;
  }
  function isInvestorSet(address investor) public view returns (bool) {
    return investors[investor].isUserWallet;
  }
  function investorTokenAmount(address investor) public view returns (uint256) {
    return investors[investor].tokenAmount;
  }
  function investorTokensDelivered(address investor) public view returns (bool) {
    return investors[investor].delivered;
  }
  function investorPaymentCount(address investor) public view returns (uint256) {
    return investors[investor].payments.length;
  }
  function investorPayment(address investor, uint index) public view returns (uint256,  uint256, uint256) {
    InvestorPayment storage payment = investors[investor].payments[index];
    return (payment.time, payment.weiValue, payment.baseValue);
  }
  function totalTokens() public view returns (uint256) {
    return token.balanceOf(this);
  }

  constructor(ERC20Basic _token, uint256 _finishTime, address _vaultWallet) Ownable() public {
    require(_token != address(0));
    require(_finishTime > now);
    require(_vaultWallet != address(0));
    token = _token;
    finishTime = _finishTime;
    vaultWallet = _vaultWallet;
  }

  function setFinishTime(uint256 _finishTime) public onlyOwner {
    uint256 oldTime = finishTime;
    finishTime = _finishTime;
    emit TokensaleFinishTimeChanged(oldTime, finishTime);
  }

  function postWalletPayment(uint256 value) public {
    require(now < finishTime);
    Investor storage investor = investors[msg.sender];
    require(investor.isUserWallet);
    investor.payments.push(InvestorPayment(now, value, 0));
    investor.tokenAmount = 0;
    emit Payment(msg.sender, value, 0);
  }

  function postExternalPayment(address investorAddress, uint256 time, uint256 baseValue, uint256 tokenAmount) public onlyOwner {
    require(investorAddress != address(0));
    require(time <= now);
    require(now < finishTime);
    require(baseValue > 0);
    Investor storage investor = investors[investorAddress];
    require(investor.isUserWallet);
    investor.payments.push(InvestorPayment(time, 0, baseValue));
    investor.tokenAmount = tokenAmount;
    emit Payment(msg.sender, 0, baseValue);
  }

  function updateTokenAmount(address investorAddress, uint256 tokenAmount) public onlyOwner {
    Investor storage investor = investors[investorAddress];
    require(investor.isUserWallet);
    investor.tokenAmount = tokenAmount;
    emit TokenAmountUpdated(investorAddress, tokenAmount);
  }

  function addInvestor(address _payoutAddress) public onlyOwner {
    UserWallet wallet = new UserWallet(_payoutAddress, vaultWallet, owner);
    investorList.push(wallet);
    investors[wallet].isUserWallet = true;
    emit InvestorAdded(wallet);
  }

  function deliverTokens(uint limit) public onlyOwner {
    require(now > finishTime);
    uint counter = 0;
    uint256 tokensDelivered = 0;
    for (uint i = 0; i < investorList.length && counter < limit; i++) {
      UserWallet investorAddress = investorList[i];
      Investor storage investor = investors[investorAddress];
      if (!investor.delivered) {
        counter = counter + 1;
        require(token.transfer(investorAddress, investor.tokenAmount));
        investorAddress.onDelivery();
        investor.delivered = true;
        emit Delivered(investorAddress, investor.tokenAmount);
      }
      tokensDelivered = tokensDelivered + investor.tokenAmount;
    }
    if (counter < limit) {
      uint256 tokensLeft = token.balanceOf(this);
      if (tokensLeft > 0) {
        require(token.transfer(owner, tokensLeft));
      }
      emit TokensaleFinished(tokensDelivered, tokensLeft);
    }

  }

}