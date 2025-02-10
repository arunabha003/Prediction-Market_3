// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library MathUtils {
    /**
     * @dev Returns the integer cube root of `x`, i.e. floor(cbrt(x)).
     *      Uses a binary search approach. 
     *
     * Requirements:
     * - `x` must fit into a uint256.
     */
    function cbrt(uint256 x) internal pure returns (uint256) {
        // Early exits for trivial cases
        if (x < 8) {
            // cbrt(0..7) is 0..1
            if (x == 0) return 0;
            if (x < 8) return 1; // 1^3 = 1..7
        }

        // Define the search bounds
        // The cube root of (2^256 -1) < 2^86, so we can start hi around 2^86
        uint256 hi = 1 << 86; 
        uint256 lo = 0;

        // Binary search
        while (lo < hi) {
            uint256 mid = (lo + hi) >> 1; // mid = (lo + hi)/2
            uint256 mid_cubed = mid * mid * mid;

            if (mid_cubed == x) {
                return mid; // perfect cube
            } else if (mid_cubed < x) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }

        // At this point, lo == hi and might be 1 too high if (lo^3 > x).
        // So we do one check:
        if (lo * lo * lo > x) {
            return lo - 1;
        } else {
            return lo;
        }
    }

}