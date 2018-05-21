pragma solidity ^0.4.21;

import "./ERC20Basic.sol";
import "./MultiOwnable.sol";
import "./UserWallet.sol";

contract AigoTokensale is MultiOwnable {

  struct InvestorPayment {
    uint256 time;
    uint256 value;
    uint8 currency;
    uint256 tokens;
  }

  struct Investor {
    bool isActive;
    InvestorPayment[] payments;
    bool needUpdate;
  }

  event InvestorAdded(address indexed investor);
  event TokensaleFinishTimeChanged(uint256 oldTime, uint256 newTime);
  event Payment(address indexed investor, uint256 value, uint8 currency);
  event Delivered(address indexed investor, uint256 amount);
  event TokensaleFinished(uint256 tokensSold, uint256 tokensReturned);

  ERC20Basic public token;
  uint256 public finishTime;
  address vaultWallet;

  UserWallet[] public investorList;
  mapping(address => Investor) investors;

  function investorsCount() public view returns (uint256) {
    return investorList.length;
  }
  function investorInfo(address investorAddress) public view returns (bool, bool, uint256, uint256) {
    Investor storage investor = investors[investorAddress];
    uint256 investorTokens = 0;
    for (uint i=0; i<investor.payments.length; i++) {
      investorTokens += investor.payments[i].tokens;
    }
    return (investor.isActive, investor.needUpdate, investor.payments.length, investorTokens);
  }
  function investorPayment(address investor, uint index) public view returns (uint256,  uint256, uint8, uint256) {
    InvestorPayment storage payment = investors[investor].payments[index];
    return (payment.time, payment.value, payment.currency, payment.tokens);
  }
  function totalTokens() public view returns (uint256) {
    return token.balanceOf(this);
  }

  constructor(ERC20Basic _token, uint256 _finishTime, address _vaultWallet) MultiOwnable() public {
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
    require(investor.isActive);
    investor.payments.push(InvestorPayment(now, value, 0, 0));
    investor.needUpdate = true;
    emit Payment(msg.sender, value, 0);
  }

  function postExternalPayment(address investorAddress, uint256 time, uint256 value, uint8 currency, uint256 tokenAmount) public onlyOwner {
    require(investorAddress != address(0));
    require(time <= now);
    require(now < finishTime);
    Investor storage investor = investors[investorAddress];
    require(investor.isActive);
    investor.payments.push(InvestorPayment(time, value, currency, tokenAmount));
    emit Payment(msg.sender, value, currency);
  }

  function updateTokenAmount(address investorAddress, uint256 paymentIndex, uint256 tokenAmount) public onlyOwner {
    Investor storage investor = investors[investorAddress];
    require(investor.isActive);
    investor.needUpdate = false;
    investor.payments[paymentIndex].tokens = tokenAmount;
  }

  function addInvestor(address _payoutAddress) public onlyOwner {
    UserWallet wallet = new UserWallet(_payoutAddress, vaultWallet);
    investorList.push(wallet);
    investors[wallet].isActive = true;
    emit InvestorAdded(wallet);
  }

  function deliverTokens(uint limit) public onlyOwner {
    require(now > finishTime);
    uint counter = 0;
    uint256 tokensDelivered = 0;
    for (uint i = 0; i < investorList.length && counter < limit; i++) {
      UserWallet investorAddress = investorList[i];
      Investor storage investor = investors[investorAddress];
      require(!investor.needUpdate);
      uint256 investorTokens = 0;
      for (uint j=0; j<investor.payments.length; j++) {
        investorTokens += investor.payments[j].tokens;
      }
      if (investor.isActive) {
        counter = counter + 1;
        require(token.transfer(investorAddress, investorTokens));
        investorAddress.onDelivery();
        investor.isActive = false;
        emit Delivered(investorAddress, investorTokens);
      }
      tokensDelivered = tokensDelivered + investorTokens;
    }
    if (counter < limit) {
      uint256 tokensLeft = token.balanceOf(this);
      if (tokensLeft > 0) {
        require(token.transfer(vaultWallet, tokensLeft));
      }
      emit TokensaleFinished(tokensDelivered, tokensLeft);
    }
  }

}