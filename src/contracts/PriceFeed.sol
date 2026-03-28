// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IPriceFeed} from "../Interfaces/IPriceFeed.sol";

/**
 * @title  PriceFeed
 * @notice Reads HYPE/USD price from Hyperliquid's native L1 oracle precompile.
 *
 * ── How the precompile works ────────────────────────────────────────────────
 *
 *  Hyperliquid validators collectively post oracle prices to the L1 (same
 *  prices used for perpetuals mark/settlement — median of validator reports).
 *  HyperEVM exposes these through a system precompile: a special address that
 *  bridges L1 state into EVM staticcalls.
 *
 *  Address : 0x0000000000000000000000000000000000000807  (testnet + mainnet)
 *  Encoding: abi.encode(uint32 index) → returns abi.encode(uint64 rawPrice)
 *  HYPE index: 150 on HyperCore L1
 *
 * ── Decimal math ────────────────────────────────────────────────────────────
 *
 *  Hyperliquid prices have (6 − szDecimals) decimal places.
 *  HYPE szDecimals = 0  →  rawPrice has 6 decimal places.
 *
 *    Example: HYPE = $23.456789  →  rawPrice = 23_456_789 (uint64)
 *
 *  This contract stores and returns prices with 18 decimal places (standard
 *  across Liquity and most DeFi):
 *
 *    price18 = rawPrice * 1e12
 *
 *  ⚠️  If Hyperliquid changes HYPE's szDecimals, update HYPE_SZ_DECIMALS and
 *      recompute SCALE. Verify at: https://api.hyperliquid.xyz/info (meta endpoint)
 *
 * ── Failure handling ────────────────────────────────────────────────────────
 *
 *  1. Precompile call reverts or returns empty data  →  use lastGoodPrice
 *  2. rawPrice == 0                                  →  use lastGoodPrice
 *  3. Scaled price outside [MIN_PRICE, MAX_PRICE]    →  use lastGoodPrice
 *
 *  If lastGoodPrice is also 0 (never successfully set), revert.
 *  This mirrors Liquity's "last good price" circuit-breaker pattern.
 */
contract PriceFeed is IPriceFeed {
    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    /// @dev Hyperliquid perps oracle precompile — same address on testnet and mainnet.
    address private constant ORACLE_PRECOMPILE = 0x0000000000000000000000000000000000000807;

    /// @dev HYPE perpetual asset index on HyperCore L1.

    uint32 private constant HYPE_INDEX = 150;

    /// @dev szDecimals for HYPE on Hyperliquid (number of decimal places in lot size).
    ///      Determines how many decimal places the raw oracle price has:
    ///        price decimal places = 6 − szDecimals
    uint8 private constant HYPE_SZ_DECIMALS = 0;

    /// @dev Scale factor to convert rawPrice (6 dp) → 18 dp.
    ///      = 10 ^ (18 − (6 − HYPE_SZ_DECIMALS))  = 10 ^ (18 − 6) = 1e12
    uint256 private constant SCALE = 1e12;

    /// @dev Sanity bounds in 18-decimal USD. Prevents obviously bad prices
    ///      from being accepted (e.g. oracle bug, stale precompile).
    ///      Adjust as HYPE's realistic price range evolves.
    uint256 private constant MIN_PRICE = 0.01e18; // $0.01
    uint256 private constant MAX_PRICE = 100_000e18; // $100,000

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// @inheritdoc IPriceFeed
    uint256 public lastGoodPrice;

    address public owner;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event PriceFetched(uint256 price);
    event FallbackToLastGoodPrice(uint256 price, string reason);
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error PriceFeed_NotOwner();
    error PriceFeed_ZeroAddress();
    error PriceFeed_NoPriceAvailable();
    error PriceFeed_InvalidInitialPrice();

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    /**
     * @param _initialLastGoodPrice  Seed value (18 decimals) used before the
     *        first successful precompile read. Prevents a cold-start with
     *        lastGoodPrice == 0. Must be within [MIN_PRICE, MAX_PRICE].
     */
    constructor(uint256 _initialLastGoodPrice) {
        if (_initialLastGoodPrice < MIN_PRICE || _initialLastGoodPrice > MAX_PRICE) {
            revert PriceFeed_InvalidInitialPrice();
        }
        owner = msg.sender;
        lastGoodPrice = _initialLastGoodPrice;
    }

    // -----------------------------------------------------------------------
    // IPriceFeed
    // -----------------------------------------------------------------------

    /**
     * @notice Fetch the current HYPE/USD price (18 decimals).
     * @dev    Calls the Hyperliquid oracle precompile. On success, updates
     *         lastGoodPrice. On failure, returns lastGoodPrice unchanged.
     *         Non-view: writes state when the precompile succeeds.
     */
    function fetchPrice() external returns (uint256) {
        (bool success, uint256 price) = _readPrecompile();

        if (success) {
            lastGoodPrice = price;
            emit PriceFetched(price);
            return price;
        }

        uint256 lgp = lastGoodPrice;
        if (lgp == 0) revert PriceFeed_NoPriceAvailable();

        emit FallbackToLastGoodPrice(lgp, "precompile call failed or price out of bounds");
        return lgp;
    }

    // -----------------------------------------------------------------------
    // Internal
    // -----------------------------------------------------------------------

    /**
     * @dev  Calls the oracle precompile and validates the raw result.
     *       Returns (false, 0) on any failure so the caller can fall back.
     *
     *       Encoding note: the precompile expects a 32-byte ABI-encoded uint32
     *       and returns a 32-byte ABI-encoded uint64.
     */
    function _readPrecompile() internal view returns (bool, uint256) {
        (bool ok, bytes memory data) = ORACLE_PRECOMPILE.staticcall(abi.encode(HYPE_INDEX));

        if (!ok || data.length < 32) return (false, 0);

        uint64 raw = abi.decode(data, (uint64));
        if (raw == 0) return (false, 0);

        uint256 price = uint256(raw) * SCALE;

        if (price < MIN_PRICE || price > MAX_PRICE) return (false, 0);

        return (true, price);
    }

    // -----------------------------------------------------------------------
    // Owner — emergency / testnet override
    // -----------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert PriceFeed_NotOwner();
        _;
    }

    /**
     * @notice Manually set lastGoodPrice. Useful on testnet if the precompile
     *         is unavailable, or as an emergency circuit-breaker.
     */
    function setLastGoodPrice(uint256 _price) external onlyOwner {
        if (_price < MIN_PRICE || _price > MAX_PRICE) {
            revert PriceFeed_InvalidInitialPrice();
        }
        lastGoodPrice = _price;
        emit PriceFetched(_price);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert PriceFeed_ZeroAddress();
        emit OwnerUpdated(owner, _newOwner);
        owner = _newOwner;
    }
}
