pragma solidity ^0.4.24;

import "../lib/FixedPointMath.sol";


contract FixedPointMathWrapper {
    using FixedPointMath for uint256;

    function multiplyFixed(uint256 a, uint256 b) external pure returns (uint256 result) {
        return a.multiplyFixed(b);
    }

    function divideFixed(uint256 a, uint256 b) external pure returns (uint256) {
        return a.divideFixed(b);
    }

    function powFixed(uint256 base, uint8 exp) external pure returns (uint256 result) {
        return base.powFixed(exp);
    }

    function rootFixed(uint256 base, uint8 n) external pure returns (uint256) {
        return base.rootFixed(n);
    }
}
