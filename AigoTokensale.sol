pragma solidity ^0.4.21;

import "PricingModel.sol";
import "ERC20Basic.sol";
import "Ownable.sol";
import "UserWallet.sol";

contract AigoTokensale is Ownable {

  struct InvestorPayment {
    uint256 time;
    uint256 weiValue;
    uint256 baseValue;
  }

  struct Investor {
    PricingModel pricingModel;
    InvestorPayment[] payments;
    uint256 tokenAmount;
    bool delivered;
  }

  event TokensaleFinishTimeChanged(uint256 oldTime, uint256 newTime);
  event Payment(address indexed investor, uint256 weiValue, uint256 baseValue);
  event Delivered(address indexed investor, uint256 amount);
  event TokensaleFinished(uint256 tokensSold, uint256 tokensReturned);

  ERC20Basic public token;
  uint256 public finishTime;

  uint256 public baseRate;
  uint256 public baseRateDenominator;

  address[] public investorList;
  mapping(address => Investor) investors;

  function investorPricingModel(address investor) public view returns (address) {
    return investors[investor].pricingModel;
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

  uint256 public totalTokensAllocated;

  constructor(ERC20Basic _token, uint256 _finishTime) Ownable() public {
    require(_token != address(0));
    require(_finishTime > now);

    token = _token;
    finishTime = _finishTime;
  }

  function setBaseRate(uint256 _baseRate, uint256 _baseRateDenominator) public onlyOwner {
    baseRate = _baseRate;
    baseRateDenominator = _baseRateDenominator;
  }

  function setFinishTime(uint256 _finishTime) public onlyOwner {
    uint256 oldTime = finishTime;
    finishTime = _finishTime;
    emit TokensaleFinishTimeChanged(oldTime, finishTime);
  }

  function() public payable {
    require(now < finishTime);
    Investor storage investor = investors[msg.sender];
    require(investor.pricingModel != address(0));
    uint256 value = msg.value * baseRate / baseRateDenominator;
    investor.payments.push(InvestorPayment(now, msg.value, value));

    uint256 newTokenAmount = calculateInvestorTokens(msg.sender);

    totalTokensAllocated = totalTokensAllocated - investor.tokenAmount + newTokenAmount;
    require(token.balanceOf(this) >= totalTokensAllocated);
    investor.tokenAmount = newTokenAmount;

    owner.transfer(msg.value);

    emit Payment(msg.sender, msg.value, value);

  }

  function postExternalPayment(address investorAddress, uint256 time, uint256 baseValue) public onlyOwner {
    require(investorAddress != address(0));
    require(time < finishTime);
    require(baseValue > 0);
    Investor storage investor = investors[investorAddress];
    require(investor.pricingModel != address(0));

    investor.payments.push(InvestorPayment(time, 0, baseValue));

    uint256 newTokenAmount = calculateInvestorTokens(msg.sender);

    totalTokensAllocated = totalTokensAllocated - investor.tokenAmount + newTokenAmount;
    require(token.balanceOf(this) >= totalTokensAllocated);
    investor.tokenAmount = newTokenAmount;

    emit Payment(msg.sender, 0, baseValue);
  }

  function calculateInvestorTokens(address investorAddress) public view returns (uint256) {
    Investor storage investor = investors[investorAddress];
    uint paymentCount = investor.payments.length;
    uint256[] memory paymentTimes = new uint256[](paymentCount);
    uint256[] memory paymentAmounts = new uint256[](paymentCount);

    for (uint i = 0; i < paymentCount; i++) {
      InvestorPayment storage payment = investor.payments[i];
      paymentTimes[i] = payment.time;
      paymentAmounts[i] = payment.baseValue;
    }
    return investor.pricingModel.calculate(paymentTimes, paymentAmounts);
  }

  function setInvestorPricingModel(address _investorAddress, PricingModel _pricingModel) public onlyOwner {
    require(_investorAddress != address(0));
    require(_pricingModel != address(0));
    investors[_investorAddress].pricingModel = _pricingModel;
  }

  function deliverTokens(uint limit) public onlyOwner {
    require(now > finishTime);
    uint counter = 0;
    uint256 tokensDelivered = 0;
    for (uint i = 0; i < investorList.length && counter < limit; i++) {
      address investorAddress = investorList[i];
      Investor storage investor = investors[investorAddress];
      if (!investor.delivered) {
        counter = counter + 1;
        require(token.transfer(investorAddress, investor.tokenAmount));
        UserWallet(investorAddress).onDelivery();
        investor.delivered = true;
        emit Delivered(investorAddress, investor.tokenAmount);
      }
      tokensDelivered = tokensDelivered + investor.tokenAmount;
    }
    if (counter < limit) {
      uint256 tokensLeft = token.balanceOf(this);
      if (tokensLeft > 0)
        require(token.transfer(owner, tokensLeft));

      emit TokensaleFinished(tokensDelivered, tokensLeft);
    }

  }

}