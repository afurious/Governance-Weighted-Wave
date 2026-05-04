// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title GovWave
 * @dev Inherits Drips logic + Staking
 */
contract GovWave {
    // Assuming some token interface, totalWaveBudget, etc.
    mapping(uint256 => uint256) public issueBoosts;
    uint256 public totalWaveBudget = 10000; // Mock budget for now
    
    // Placeholder for a token interface
    // IERC20 public token;

    function boostIssue(uint256 _issueId, uint256 _amount) external {
        // Mock token transfer
        // token.transferFrom(msg.sender, address(this), _amount);
        
        issueBoosts[_issueId] += _amount;
    }

    function calculateReward(uint256 _issueId, uint256 _points) public view returns (uint256) {
        // Calculate a multiplier based on the proportion of the budget boosted to this issue
        // We add 1 so the base multiplier is at least 1 (i.e. no boosts = base reward)
        uint256 multiplier = 1 + (issueBoosts[_issueId] / totalWaveBudget);
        return _points * multiplier;
    }
}
