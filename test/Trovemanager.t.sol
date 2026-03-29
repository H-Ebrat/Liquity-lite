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
}
