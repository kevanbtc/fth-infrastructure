// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoRAdapter} from "../interfaces/IPoRAdapter.sol";
import {AccessRoles} from "../access/AccessRoles.sol";

// Simplified Chainlink oracle interface for Proof of Reserve
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract ChainlinkPoRAdapter is IPoRAdapter, AccessRoles {
    AggregatorV3Interface public immutable priceFeed;
    uint256 public constant STALENESS_THRESHOLD = 3600; // 1 hour
    
    constructor(address _priceFeed, address admin) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_ROLE, admin);
    }
    
    function totalVaultedKg() external view returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        require(answer > 0, "Invalid PoR data");
        require(block.timestamp - updatedAt <= STALENESS_THRESHOLD, "Stale PoR data");
        return uint256(answer);
    }
    
    function lastUpdate() external view returns (uint256) {
        (, , , uint256 updatedAt, ) = priceFeed.latestRoundData();
        return updatedAt;
    }
    
    function isHealthy() external view returns (bool) {
        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        return answer > 0 && (block.timestamp - updatedAt <= STALENESS_THRESHOLD);
    }
}
