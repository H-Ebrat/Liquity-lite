// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;



import {ITroveManager} from "../Interfaces/ITroveManager.sol";
import {IPriceFeed} from "../Interfaces/IPriceFeed.sol";
import {IHYPDToken} from "../Interfaces/IHYPDToken.sol";
/**
 * @title TroveManager
 * @notice Manages user troves (collateralized debt positions) in Liquity Lite.
 *         Users can open/close troves, add/remove collateral, and borrow/repay LUSD.
 *         Enforces minimum collateralization ratio MCR=110% and handles liquidations.
 *             User troves are stored in a mapping with their collateral and debt amounts.
 *             loans are tracked per user and the contract interacts with the PriceFeed to get the current collateral price.
 *             there is no interest rate or stability fee for the protocol
 *             only a $20 fee on opening a trove, which is added to the total debt and paid in LUSD.
 *             the $20 acts as gas fee compensation for the liquidation events and user calling the liquidation gets the $20 fee as reward for calling the liquidation function.
 * @dev In v1, this is a simplified version without stability pool or recovery mode.
 *      Later versions can add more complex features and optimizations.
 */

abstract contract TroveManager is ITroveManager {
    //state vars

    mapping(address => Trove) public troves;
    address public priceFeed;
    address public hypdToken;
    address public stabilityPool;
    uint256 public totalCollateral;
    uint256 public totalDebt;
    uint256 public L_collateral; // Cumulative collateral reward per unit of collateral
    uint256 public L_debt; // Cumulative debt reward per unit of collateral
    uint256 public constant MCR = 110 * 1e16;          // 110% in 18-decimal form
    uint256 public constant LIQUIDATION_BONUS = 5e15;  // 0.5% of collateral (0.005 * 1e18)



    struct Trove {
        uint256 collateral;
        uint256 debt;
        uint256 rewardSnapshotCollateral; // Snapshot for the L-collateral at last touch
        uint256 rewardSnapshotDebt; // Snapshot for the L-debt at last touch
    }


    // -----------------------------------------------------------------------
    // External functions

    function openTrove(uint256 _debtAmount) external payable {
        require(troves[msg.sender].debt == 0, "Trove already exists");
        require(_debtAmount > 0, "Debt must be greater than 0");
        require(msg.value > 0, "Collateral must be greater than 0");

        uint256 price = IPriceFeed(priceFeed).fetchPrice();
        uint256 newCR = _computeCR(msg.value, _debtAmount, price);
        require(newCR >= MCR, "CR too low");

        // Update trove
        troves[msg.sender] = Trove({
            collateral: msg.value,
            debt: _debtAmount,
            rewardSnapshotCollateral: L_collateral,
            rewardSnapshotDebt: L_debt
        });

        // Update totals
        totalCollateral += msg.value;
        totalDebt += _debtAmount;

        // Mint _debtAmount HYPD to borrower
        IHYPDToken(hypdToken).mint(msg.sender, _debtAmount);

        emit TroveOpened(msg.sender, msg.value, _debtAmount);
    }


    // -----------------------------------------------------------------------
    // Internal functions
    // -----------------------------------------------------------------------


    function _computeCR(uint256 _collateral, uint256 _debt, uint256 _price) internal pure returns (uint256){
        return _collateral * _price / _debt;

    }


    // 

}
