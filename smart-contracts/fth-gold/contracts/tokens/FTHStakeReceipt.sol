// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AccessRoles} from "../access/AccessRoles.sol";

contract FTHStakeReceipt is ERC20, AccessRoles {
    mapping(address => bool) public locked; // non-transferable flag
    mapping(address => bool) public transferable; // override flag for specific users

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

    function setTransferable(address user, bool canTransfer) external onlyRole(ISSUER_ROLE) {
        transferable[user] = canTransfer;
    }

    function _update(address from, address to, uint256 value) internal override {
        // disable transfers (soulbound-like for ERC20) unless explicitly allowed
        if (from != address(0) && to != address(0) && !transferable[from]) {
            revert("NON_TRANSFERABLE");
        }
        super._update(from, to, value);
    }
}
