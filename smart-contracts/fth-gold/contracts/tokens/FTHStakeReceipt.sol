// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessRoles} from "../access/AccessRoles.sol";

contract FTHStakeReceipt is ERC20, AccessRoles {
    mapping(address => bool) public locked; // non-transferable flag

    constructor(address admin) ERC20("FTH Stake Receipt","FTH-SR"){
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        locked[address(0)] = true;
    }

    function mint(address to, uint256 amt) external onlyRole(ISSUER_ROLE) {
        _mint(to, amt);
    }
    function burn(address from, uint256 amt) external onlyRole(ISSUER_ROLE) {
        _burn(from, amt);
    }

    function _update(address from, address to, uint256 value) internal override returns (bool) {
        // disable transfers (soulbound-like for ERC20)
        if (from != address(0) && to != address(0)) revert("NON_TRANSFERABLE");
        return super._update(from, to, value);
    }
}
