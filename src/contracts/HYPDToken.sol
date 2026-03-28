// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// /Users/harisebrat/liquity-lite/lib/openzeppelin-contracts/contracts/access/Ownable.sol

contract HYPDToken is ERC20, Ownable {
    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    address public troveManager; // later: authorized minter/burner
    address public stabilityPool; // later: authorized burner (optional)

    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------

    /**
     * @param _name   Token name (e.g., "Liquity Lite USD")
     * @param _symbol Token symbol (e.g., "lUSD")
     */
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {
        // Ownable sets owner to msg.sender via base constructor
    }

    // -----------------------------------------------------------------------
    // Access control setters (optional for v1)
    // -----------------------------------------------------------------------

    function setTroveManager(address _troveManager) external onlyOwner {
        require(_troveManager != address(0), "HYPD: zero troveManager");
        troveManager = _troveManager;
    }

    function setStabilityPool(address _stabilityPool) external onlyOwner {
        require(_stabilityPool != address(0), "HYPD: zero stabilityPool");
        stabilityPool = _stabilityPool;
    }

    // -----------------------------------------------------------------------
    // Mint / burn functions
    // -----------------------------------------------------------------------

    function mint(address _to, uint256 _amount) external {
        _requireCallerIsAuthorized();
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        _requireCallerIsAuthorized();
        _burn(_from, _amount);
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    function _requireCallerIsAuthorized() internal view {
        require(
            msg.sender == owner() || msg.sender == troveManager || msg.sender == stabilityPool,
            "LUSDT: caller not authorized"
        );
    }
}
