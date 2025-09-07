// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoRAdapter} from "../interfaces/IPoRAdapter.sol";

contract MockPoRAdapter is IPoRAdapter {
    bool    private _healthy;
    uint256 private _totalVaultedKg;
    uint256 private _lastUpdate;

    // --- Test setters ---
    function setHealthy(bool h) external {
        _healthy = h;
        _lastUpdate = block.timestamp;
    }

    function setTotalVaultedKg(uint256 kg) external {
        _totalVaultedKg = kg;
        _lastUpdate = block.timestamp;
    }

    function setLastUpdate(uint256 ts) external {
        _lastUpdate = ts;
    }

    // --- IPoRAdapter impl expected by StakeLocker ---
    function isHealthy() external view returns (bool) {
        return _healthy;
    }

    function totalVaultedKg() external view returns (uint256) {
        return _totalVaultedKg;
    }

    function lastUpdate() external view returns (uint256) {
        return _lastUpdate;
    }
}
