// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IPriceFeed {
    // Called by TroveManager before any operation that depends on price.
    // Updates lastGoodPrice on success; falls back to it on failure.
    // Non-view because it writes state when the precompile call succeeds.
    function fetchPrice() external returns (uint256);

    // Last successfully validated price, always readable.
    function lastGoodPrice() external view returns (uint256);
}
