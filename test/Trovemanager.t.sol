// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {TroveManager} from "../src/contracts/TroveManager.sol";
import {HYPDToken} from "../src/contracts/HYPDToken.sol";

// ── Mock PriceFeed ────────────────────────────────────────────────────────────

contract MockPriceFeed {
    uint256 public lastGoodPrice = 100e18; // $100 per HYPE

    function fetchPrice() external returns (uint256) {
        return lastGoodPrice;
    }

    function setPrice(uint256 _price) external {
        lastGoodPrice = _price;
    }
}

// ── Harness ───────────────────────────────────────────────────────────────────

contract TroveManagerHarness is TroveManager {
    constructor(address _priceFeed, address _hypdToken, address _stabilityPool) {
        priceFeed    = _priceFeed;
        hypdToken    = _hypdToken;
        stabilityPool = _stabilityPool;
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

contract TroveManagerTest is Test {
    TroveManagerHarness troveManager;
    MockPriceFeed priceFeed;
    HYPDToken hypdToken;

    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");

    function setUp() public {
        priceFeed    = new MockPriceFeed();
        hypdToken    = new HYPDToken("Hype Dollar", "HYPD");
        troveManager = new TroveManagerHarness(
            address(priceFeed),
            address(hypdToken),
            address(0)
        );

        hypdToken.setTroveManager(address(troveManager));

        vm.deal(alice, 100 ether);
        vm.deal(bob,   100 ether);
    }

    // write your tests below
    function testOpenTrove() public {
        vm.prank(alice);
        troveManager.openTrove{value: 10 ether}(500e18);

        (uint256 collateral, uint256 debt,,) = troveManager.troves(alice);
        assertEq(collateral, 10 ether);
        assertEq(debt, 500e18);
        assertEq(hypdToken.balanceOf(alice), 500e18);
    }


    function testUserAlreadyHasOpenTrove() public {
        vm.prank(alice);
        troveManager.openTrove{value: 10 ether}(500e18);

        vm.expectRevert("Trove already exists");
        vm.prank(alice);
        troveManager.openTrove{value: 5 ether}(200e18);
    }

    function testMsgValueZero() public {
        vm.prank(alice);
        vm.expectRevert("Collateral must be greater than 0");
        troveManager.openTrove{value: 0}(500e18);
    }


    function testDebtAmountZero() public {
        vm.prank(alice);
        vm.expectRevert("Debt must be greater than 0");
        troveManager.openTrove{value: 10 ether}(0);
    }

    function testCRTooLow() public {
        vm.prank(alice);
        vm.expectRevert("CR too low");
        troveManager.openTrove{value: 1 ether}(500e18);
    }

    function testCloseTrove() public {
        vm.prank(alice);
        troveManager.openTrove{value: 10 ether}(500e18);

        vm.prank(alice);
        troveManager.closeTrove();

        (uint256 collateral, uint256 debt,,) = troveManager.troves(alice);
        assertEq(collateral, 0);
        assertEq(debt, 0);
        assertEq(hypdToken.balanceOf(alice), 0);
         assertEq(troveManager.totalCollateral(), 0);                                                                                                                                          
         assertEq(troveManager.totalDebt(), 0);
    }


    function testCloseTroveRevertsIfNoActiveTrove() public {
        vm.prank(alice);
        vm.expectRevert("No active trove");
        troveManager.closeTrove();
    }

    function testCloseTroveRevertsInsufficentHYPDBalance() public {
        vm.prank(alice);
        troveManager.openTrove{value: 10 ether}(500e18);


        vm.prank(alice);
        hypdToken.transfer(bob, 500e18); // Alice sends all her HYPD to Bob, leaving her with 0 balance
        vm.expectRevert("Insufficient HYPD balance");
        vm.prank(alice);
        troveManager.closeTrove();
    }


    function testCheckCollateralizationRatio() public {
        vm.prank(alice);
        troveManager.openTrove{value: 10 ether}(500e18);

        uint256 cr = troveManager.getCollateralizationRatio(alice);
        assertEq(cr, 200e16); // 200% CR
    }

    
}
