// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

/**
 * @title PriceFeed
 * @notice Simple testnet price oracle for Liquity Lite (HyperEVM / HYPE collateral)
 * @dev In v1 this is a privileged on-chain setter, not a decentralized oracle.
 *      Later versions can replace with Chainlink/AggregatorV3Interface or swap-based TWAP.
 */
contract PriceFeed {

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    // Price is stored as USD with 18 decimals (e.g., 1.12 USD => 1.12e18)
    uint256 public price;    // current HYPE/USD price

    // Privileged account able to update price in v1
    address public owner;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event OwnerUpdated(address indexed oldOwner, address indexed newOwner);

    // -----------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------

    error PriceFeed_NotOwner();
    error PriceFeed_ZeroPrice();
    error PriceFeed_ZeroAddress();

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    /**
     * @param _initialPrice Initial HYPE/USD price (18 decimals). Must be > 0.
     */
    constructor(uint256 _initialPrice) {
        if (_initialPrice == 0) revert PriceFeed_ZeroPrice();
        owner = msg.sender;
        price = _initialPrice;
        emit PriceUpdated(0, _initialPrice);
    }

    // -----------------------------------------------------------------------
    // Modifiers
    // -----------------------------------------------------------------------

    modifier onlyOwner() {
        if (msg.sender != owner) revert PriceFeed_NotOwner();
        _;
    }

    // -----------------------------------------------------------------------
    // Owner functions
    // -----------------------------------------------------------------------

    /**
     * @notice Set a new price in HYPE/USD (18 decimals)
     */
    function setPrice(uint256 _price) external onlyOwner {
        if (_price == 0) revert PriceFeed_ZeroPrice();
        uint256 old = price;
        price = _price;
        emit PriceUpdated(old, _price);
    }

    /**
     * @notice Transfer ownership of the price feed.
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert PriceFeed_ZeroAddress();
        emit OwnerUpdated(owner, _newOwner);
        owner = _newOwner;
    }

    // -----------------------------------------------------------------------
    // Read helpers
    // -----------------------------------------------------------------------

    /**
     * @notice Get current HYPE/USD price (18 decimals).
     */
    function getPrice() external view returns (uint256) {
        return price;
    }

    /**
     * @notice Get current HYPE/USD price, revert if uninitialized.
    //  */
    function getPriceOrRevert() external view returns (uint256) {
        uint256 p = price;
        if (p == 0) revert PriceFeed_ZeroPrice();
        return p;
    }

}
