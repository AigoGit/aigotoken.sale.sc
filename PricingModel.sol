pragma solidity ^0.4.18;

contract PricingModel {
  uint256 public baseRate;
  uint256 public baseRateDenominator;
  string public code;

  constructor(string _code, uint256 _baseRate, uint256 _baseRateDenominator) public {
    require(_baseRate > 0);
    require(_baseRateDenominator > 0);
    code = _code;
    baseRate = _baseRate;
    baseRateDenominator = _baseRateDenominator;
  }

  function calculate(uint256[] paymentTimes, uint256[] paymentAmounts) view public returns (uint256);

}