pragma solidity ^0.4.24;

import "@aragon/os/contracts/lib/math/SafeMath.sol";


library FixedPointMath {
    using SafeMath for uint256;

    uint256 private constant FIXED_1 = 10**18;
    uint256 private constant ROOT_ERROR_THRESHOLD = 10**12; //1e-6

    function multiplyFixed(uint256 a, uint256 b) internal pure returns (uint256 result) {
        uint256 aInt = integer(a);
        uint256 aFrac = fractional(a);
        uint256 bInt = integer(b);
        uint256 bFrac = fractional(b);

        result = aInt.mul(bInt).mul(FIXED_1);
        result = result.add(aInt.mul(bFrac));
        result = result.add(aFrac.mul(bInt));
        result = result.add(aFrac.mul(bFrac) / FIXED_1);
    }

    function divideFixed(uint256 a, uint256 b) internal pure returns (uint256) {
        return a.mul(FIXED_1) / b;
    }

    function powFixed(uint256 base, uint8 exp) internal pure returns (uint256 result) {
        if (exp == 0) {
            return 1;
        }
        if (exp == 1) {
            return base;
        }
        uint256 tmp = base;
        uint256 n = exp;
        while(result == 0 && tmp > 0) {
            if (n & 1 > 0) {
                result = tmp;
            }
            n = n >> 1;
            tmp = multiplyFixed(tmp, tmp);
        }
        while (n > 0 && result > 0) {
            if (n & 1 > 0) {
                result = multiplyFixed(result, tmp);
            }
            n = n >> 1;
            tmp = multiplyFixed(tmp, tmp);
        }
    }

    /*
     * This uses the nth-root algorithm based on Newton's method for finding zeroes.
     * See: https://en.wikipedia.org/wiki/Nth_root_algorithm
     * Initial value is the image of the tangent line to the curve y = x^(1/n)
     * which passes by the point (1, 1)
     * This line is always over, as the derivative of that curve is decreasing from x=1 on
     * Therefore the initial value will always be bigger than the sought value,
     * which seems to behave better for these family of curves.
     * One important assumption is that we are computing roots of values in the interval [1,2]
     * This is due to the fact that they come from the term (1 + p / b)^(1/(n+1)) in the Bancor formula,
     * where always 0 <= p <= b
     * So the error in this initial value will be relatively small, specially when close to 1
     * i.e., when the deposit amount for the purchase is small relative to the total balance,
     * which seems to be a fairly common case.
     * A possible improvement could be to divide that interval [1,2] in, let's say, 10 sub-intervals of 0.1
     * and then pre-compute and harcode here initial values for each region (using the smame method of the tnagent line)
     * that would be specially useful if we already know the order of our curve (n), which is not going to change (often)
     */
    function rootFixed(uint256 base, uint8 n) internal pure returns (uint256) {
        uint256 initialValue = (base + (n - 1) * FIXED_1) / n;
        return _rootIteration(base, n, initialValue);
    }

    function _rootIteration(uint256 base, uint8 n, uint256 previous) private pure returns (uint256) {
        // TODO: try to do base / previous.mul(powFixed(previous, n - 2))
        uint256 delta1 = divideFixed(base, powFixed(previous, n - 1));
        bool deltaPositive = false;
        uint256 delta;
        if (delta1 < previous) {
            delta = (previous - delta1) / n;
        } else {
            deltaPositive = true;
            delta = (delta1 - previous) / n;
        }

        uint256 result = deltaPositive ? previous + delta : previous - delta;
        if (delta < ROOT_ERROR_THRESHOLD) {
            return result;
        }

        return _rootIteration(base, n, result);
    }

    /*
    function rootFixed2(uint256 base, uint8 n, uint256 N) internal pure returns (uint256 result) {
        uint256 previous = (base + (n - 1) * FIXED_1) / n;
        for (uint256 i = 0; i < N; i++) {
            uint256 pow = powFixed(previous, n - 1);
            uint256 delta1 = divideFixed(base, pow);
            bool deltaPositive = false;
            uint256 delta;
            if (delta1 < previous) {
                delta = (previous - delta1) / n;
            } else {
                deltaPositive = true;
                delta = (delta1 - previous) / n;
            }

            result = deltaPositive ? previous + delta : previous - delta;
            previous = result;
        }
    }
    */

    function integer(uint256 a) internal pure returns (uint256) {
        return a / FIXED_1;
    }

    function fractional(uint256 a) internal pure returns (uint256) {
        return a % FIXED_1;
    }

}
