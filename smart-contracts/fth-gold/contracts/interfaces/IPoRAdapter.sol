// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPoRAdapter {
    function totalVaultedKg() external view returns (uint256);
    function lastUpdate() external view returns (uint256);
    function isHealthy() external view returns (bool);
}
