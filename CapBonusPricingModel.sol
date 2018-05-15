pragma solidity ^0.4.21;

import "PricingModel.sol";

contract CapBonusPricingModel is PricingModel {
  uint256 public bonusCap;
  uint256 public bonusAmount;

  constructor(uint256 _rate, uint256 _rateDenominator, uint256 _bonusCap, uint256 _bonusAmount) PricingModel("CapBonus", _rate, _rateDenominator) public {
    bonusCap = _bonusCap;
    bonusAmount = _bonusAmount;
  }

  function calculate(uint256[] paymentTimes, uint256[] paymentValues) view public returns (uint256) {
    require(paymentTimes.length == paymentValues.length);
    uint256 tokenAmount = 0;
    uint256 baseAmount = 0;
    for (uint i = 0; i < paymentTimes.length; i++) {
        baseAmount = baseAmount  + paymentValues[i];
        tokenAmount = tokenAmount + baseRate * paymentValues[i] / baseRateDenominator;
    }
    if (baseAmount >= bonusCap) tokenAmount = tokenAmount + bonusAmount;
    return tokenAmount;
  }

}
