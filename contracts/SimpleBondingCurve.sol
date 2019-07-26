pragma solidity 0.4.24;

import "./interfaces/IBancorFormula.sol";
import "@aragon/os/contracts/lib/math/SafeMath.sol";
import "./lib/FixedPointMath.sol";


/*
 * curveDegree is n, where the curve is of the form y = m * x^n
 * reserve ratio r = 1 / (n+1) is the ratio between pool balance and market cap (total supply * current price)
 * r = connectorweight / 1000000
 * See, for reference:
 * https://blog.relevant.community/bonding-curves-in-depth-intuition-parametrization-d3905a681e0a
 * https://medium.com/@billyrennekamp/converting-between-bancor-and-bonding-curve-price-formulas-9c11309062f5
 */
contract SimpleBondingCurve is IBancorFormula {
    using SafeMath for uint256;
    using FixedPointMath for uint256;

    uint32 private constant MAX_WEIGHT = 1000000;

    /**
        @dev given a token supply, connector balance, weight and a deposit amount (in the connector token),
        calculates the return for a given conversion (in the main token)

        Formula:
        Return = _supply * ((1 + _depositAmount / _connectorBalance) ^ (_connectorWeight / 1000000) - 1)

        @param _supply              token total supply
        @param _connectorBalance    total connector balance
        @param _connectorWeight     connector weight, represented in ppm, 1-1000000
        @param _depositAmount       deposit amount, in connector token

        @return purchase return amount
    */
    function calculatePurchaseReturn(
        uint256 _supply,
        uint256 _connectorBalance,
        uint32 _connectorWeight,
        uint256 _depositAmount
    )
        public
        view
        returns (uint256)
    {
        uint8 curveDegree = _connectorWeightToCurveDegree(_connectorWeight);

        return _calculatePurchaseReturn(_supply, _connectorBalance, curveDegree, _depositAmount);
    }

    /**
        @dev given a token supply, connector balance, weight and a sell amount (in the main token),
        calculates the return for a given conversion (in the connector token)

        Formula:
        Return = _connectorBalance * (1 - (1 - _sellAmount / _supply) ^ (1 / (_connectorWeight / 1000000)))

        @param _supply              token total supply
        @param _connectorBalance    total connector
        @param _connectorWeight     connector weight, represented in ppm, 1-1000000
        @param _sellAmount          sell amount, in the token itself

        @return sale return amount
    */
    function calculateSaleReturn(
        uint256 _supply,
        uint256 _connectorBalance,
        uint32 _connectorWeight,
        uint256 _sellAmount
    )
        public
        view
        returns (uint256)
    {
        uint8 curveDegree = _connectorWeightToCurveDegree(_connectorWeight);

        return _calculateSaleReturn(_supply, _connectorBalance, curveDegree, _sellAmount);
    }

    /* *** With curveDegree instead of connectorWeight *** */

    /**
        @dev given a token supply, connector balance, weight and a deposit amount (in the connector token),
        calculates the return for a given conversion (in the main token)

        Formula:
        Return = _supply * ((1 + _depositAmount / _connectorBalance) ^ (1 / (_curveDegree + 1)) - 1)

        @param _supply              token total supply
        @param _connectorBalance    total connector balance
        @param _curveDegree         n, where the curve is of the form y = m * x^n
        @param _depositAmount       deposit amount, in connector token

        @return purchase return amount
    */
    function calculatePurchaseReturn2(
        uint256 _supply,
        uint256 _connectorBalance,
        uint8 _curveDegree,
        uint256 _depositAmount
    )
        public
        pure
        returns (uint256)
    {
        return _calculatePurchaseReturn(_supply, _connectorBalance, _curveDegree, _depositAmount);
    }

    /**
        @dev given a token supply, connector balance, weight and a sell amount (in the main token),
        calculates the return for a given conversion (in the connector token)

        Formula:
        Return = _connectorBalance * (1 - (1 - _sellAmount / _supply) ^ (_curveDegree + 1))

        @param _supply              token total supply
        @param _connectorBalance    total connector
        @param _curveDegree         n, where the curve is of the form y = m * x^n
        @param _sellAmount          sell amount, in the token itself

        @return sale return amount
    */
    function calculateSaleReturn2(
        uint256 _supply,
        uint256 _connectorBalance,
        uint8 _curveDegree,
        uint256 _sellAmount
    )
        public
        pure
        returns (uint256)
    {
        return _calculateSaleReturn(_supply, _connectorBalance, _curveDegree, _sellAmount);
    }

    /**
        @dev given two connector balances/weights and a sell amount (in the first connector token),
        calculates the return for a conversion from the first connector token to the second connector token (in the second connector token)

        Formula:
        Return = _toConnectorBalance * (1 - (_fromConnectorBalance / (_fromConnectorBalance + _amount)) ^ (_fromConnectorWeight / _toConnectorWeight))

        @return second connector amount
    */
    function calculateCrossConnectorReturn(uint256, uint32, uint256, uint32, uint256) public view returns (uint256) {
        // TODO: not supported
        return 0;
    }

    function _calculatePurchaseReturn(
        uint256 _supply,
        uint256 _connectorBalance,
        uint8 _curveDegree,
        uint256 _depositAmount
    )
        internal
        pure
        returns (uint256)
    {
        // validate input
        require(_supply > 0 && _connectorBalance > 0);

        // special case for 0 deposit amount
        if (_depositAmount == 0)
            return 0;

        // special case if the weight = 100%
        // no need to use fixed because we are multiplying and dividing
        if (_curveDegree == 0)
            return _supply.mul(_depositAmount) / _connectorBalance;

        uint256 result;
        uint256 baseN = _depositAmount.add(_connectorBalance);
        result = baseN.divideFixed(_connectorBalance).rootFixed(_curveDegree + 1);
        //result = rootFixed2(divideFixed(baseN, _connectorBalance), uint8(_curveDegree + 1), 3, INITIAL_ROOT_VALUE);
        uint256 temp = _supply.multiplyFixed(result);
        return temp - _supply;
    }

    function _calculateSaleReturn(
        uint256 _supply,
        uint256 _connectorBalance,
        uint8 _curveDegree,
        uint256 _sellAmount
    )
        internal
        pure
        returns (uint256)
    {
        // validate input
        require(_supply > 0 && _connectorBalance > 0 && _sellAmount <= _supply);

        // special case for 0 sell amount
        if (_sellAmount == 0)
            return 0;

        // special case for selling the entire supply
        if (_sellAmount == _supply)
            return _connectorBalance;

        // special case if the weight = 100%
        // no need to use fixed because we are multiplying and dividing
        if (_curveDegree == 0)
            return _connectorBalance.mul(_sellAmount) / _supply;

        /*
        uint256 result;
        uint256 baseD = _supply - _sellAmount;
        result = powFixed(divideFixed(_supply, baseD), uint8(_curveDegree + 1)); // TODO: uint8 overflow
        uint256 temp1 = multiplyFixed(_connectorBalance, result);
        return divideFixed(temp1, result);
        */
        uint256 tmp1 = _supply - _sellAmount;
        uint256 tmp2 = tmp1.divideFixed(_supply);
        uint256 tmp3 = tmp2.powFixed(_curveDegree + 1);
        uint256 tmp4 = _connectorBalance.multiplyFixed(tmp3);
        uint256 tmp5 = _connectorBalance - tmp4;
        //return (tmp1, tmp2, tmp3, tmp4, tmp5);
        return tmp5;
    }

    function _connectorWeightToCurveDegree(uint32 _connectorWeight) internal pure returns (uint8) {
        // to avoid overflow on uint8 (and dividing by zero implicitly)
        require(_connectorWeight >= MAX_WEIGHT / 256);
        return uint8(MAX_WEIGHT / _connectorWeight - 1);
    }
}
