pragma solidity 0.5.8;

import "../../../lib/Compound/CErc20.sol";

contract FakeCDai is CErc20 {
    constructor(
      address _token,
      ComptrollerInterface _comptroller,
      InterestRateModel _interestRateModel
    )
    CErc20(
      _token,
      _comptroller,
      _interestRateModel,
      200000000 * (10 ** 18),
      "Fake Compound Dai",
      "cDAI",
      8
    )
    public
    {}
}
