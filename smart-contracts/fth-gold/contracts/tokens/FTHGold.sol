// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessRoles} from "../access/AccessRoles.sol";

contract FTHGold is ERC20, ERC20Permit, Pausable, AccessRoles {
    constructor(address admin) ERC20("FTH Gold (1 kg)","FTH-G") ERC20Permit("FTH Gold (1 kg)"){
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);
    }
    function pause() external onlyRole(GUARDIAN_ROLE) { _pause(); }
    function unpause() external onlyRole(GUARDIAN_ROLE) { _unpause(); }

    function mint(address to, uint256 amountKg) external onlyRole(ISSUER_ROLE) { _mint(to, amountKg * 1e18); }
    function burn(address from, uint256 amountKg) external onlyRole(ISSUER_ROLE) { _burn(from, amountKg * 1e18); }

    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from,to,value);
    }
}
