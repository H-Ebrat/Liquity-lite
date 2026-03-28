// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface ITroveManager {
    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event TroveOpened(address indexed borrower, uint256 collateralAmount, uint256 debtAmount);
    event TroveClosed(address indexed borrower);
    event CollateralAdded(address indexed borrower, uint256 amountAdded);
    event CollateralRemoved(address indexed borrower, uint256 amountRemoved);
    event HYPDBorrowed(address indexed borrower, uint256 amountBorrowed);
    event HYPDRepaid(address indexed borrower, uint256 amountRepaid);
    event TroveFullyLiquidated(
        address indexed borrower, address indexed liquidator, uint256 collateralLiquidated, uint256 debtRepaid
    );
    event DebtRedistributed(uint256 collateralRedistributed, uint256 debtRedistributed);

    // -----------------------------------------------------------------------
    // External functions
    // -----------------------------------------------------------------------

    function openTrove(uint256 _debtAmount) external payable;

    function closeTrove() external;

    function addCollateral() external payable;

    function removeCollateral(uint256 _amount) external;

    function borrowHYPD(uint256 _amount) external;

    function repayHYPD(uint256 _amount) external;

    function liquidate(address _borrower) external;

    function getPendingCollateralReward(address _borrower) external view returns (uint256);

    function getPendingDebtReward(address _borrower) external view returns (uint256);

    // -----------------------------------------------------------------------
    // View functions
    // -----------------------------------------------------------------------

    function getTrove(address _borrower) external view returns (uint256 collateralAmount, uint256 debtAmount);

    function getCollateralizationRatio(address _borrower) external view returns (uint256);
}
