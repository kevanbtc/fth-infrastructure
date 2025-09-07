// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IPoRAdapter} from "../oracle/ChainlinkPoRAdapter.sol";

contract MockPoRAdapter is IPoRAdapter {
    uint256 public kg;
    uint256 public updated;
    bool public healthy = true;

    function set(uint256 _kg, bool _healthy) external { kg = _kg; healthy = _healthy; updated = block.timestamp; }

    function totalVaultedKg() external view returns (uint256){ return kg; }
    function batchKg(uint256) external view returns (uint256){ return kg; }
    function lastUpdate() external view returns (uint256){ return updated; }
    function isHealthy() external view returns (bool){ return healthy; }
}
