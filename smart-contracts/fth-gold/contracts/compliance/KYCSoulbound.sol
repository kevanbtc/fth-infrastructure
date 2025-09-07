// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessRoles} from "../access/AccessRoles.sol";

contract KYCSoulbound is ERC721, AccessRoles {
    struct KYCData { bytes32 idHash; bytes32 passportHash; uint48 expiry; uint16 juris; bool accredited; }
    mapping(address => KYCData) public kycOf;
    mapping(address => bool)    public locked;

    constructor(address admin) ERC721("FTH KYC Pass","KYC-PASS"){
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(KYC_ISSUER_ROLE, admin);
    }

    function mint(address to, KYCData calldata d) external onlyRole(KYC_ISSUER_ROLE) {
        require(!_exists(uint160(to)), "Exists");
        _safeMint(to, uint160(to));
        kycOf[to] = d; locked[to] = true;
    }

    function revoke(address to) external onlyRole(KYC_ISSUER_ROLE) {
        _burn(uint160(to)); delete kycOf[to]; locked[to] = false;
    }

    function _update(address to, uint256 id, address auth) internal override returns(address){
        if (_ownerOf(id) != address(0)) revert("SBT");
        return super._update(to,id,auth);
    }

    function isValid(address user) external view returns(bool){
        KYCData memory d = kycOf[user];
        return locked[user] && d.expiry > block.timestamp;
    }
}
