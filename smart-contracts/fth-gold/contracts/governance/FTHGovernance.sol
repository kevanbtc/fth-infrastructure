// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessRoles} from "../access/AccessRoles.sol";

/**
 * @title FTHGovernance
 * @dev Simple governance contract for FTH Gold protocol parameter updates
 */
contract FTHGovernance is AccessRoles {
    
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        bytes callData;
        address target;
        uint256 value;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voteChoice; // true = for, false = against
    }
    
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant PROPOSAL_THRESHOLD = 1; // Minimum proposals needed
    uint256 public quorumBps = 2000; // 20% quorum required
    
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower; // Could be based on FTH Gold holdings
    
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);
        
        // Grant initial voting power to admin
        votingPower[admin] = 1000;
    }
    
    /**
     * @dev Create a new governance proposal
     */
    function propose(
        address target,
        uint256 value,
        bytes memory callData,
        string memory description
    ) external returns (uint256) {
        require(votingPower[msg.sender] >= PROPOSAL_THRESHOLD, "Insufficient voting power");
        require(bytes(description).length > 0, "Description required");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.callData = callData;
        proposal.target = target;
        proposal.value = value;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + VOTING_PERIOD;
        proposal.executed = false;
        proposal.canceled = false;
        
        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }
    
    /**
     * @dev Cast vote on a proposal
     */
    function castVote(uint256 proposalId, bool support) external {
        require(votingPower[msg.sender] > 0, "No voting power");
        require(proposalId <= proposalCount && proposalId > 0, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.executed && !proposal.canceled, "Proposal not active");
        
        uint256 weight = votingPower[msg.sender];
        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;
        
        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }
        
        emit VoteCast(proposalId, msg.sender, support, weight);
    }
    
    /**
     * @dev Execute a successful proposal
     */
    function execute(uint256 proposalId) external {
        require(proposalId <= proposalCount && proposalId > 0, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime + EXECUTION_DELAY, "Execution delay not met");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");
        require(_isProposalSuccessful(proposalId), "Proposal failed");
        
        proposal.executed = true;
        
        // Execute the proposal
        (bool success, ) = proposal.target.call{value: proposal.value}(proposal.callData);
        require(success, "Execution failed");
        
        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @dev Cancel a proposal (only by admin or proposer)
     */
    function cancel(uint256 proposalId) external {
        require(proposalId <= proposalCount && proposalId > 0, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Already canceled");
        
        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }
    
    /**
     * @dev Check if proposal meets quorum and majority
     */
    function _isProposalSuccessful(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 totalVotingPower = _getTotalVotingPower();
        
        // Check quorum
        if (totalVotes * 10000 < totalVotingPower * quorumBps) {
            return false;
        }
        
        // Check majority
        return proposal.forVotes > proposal.againstVotes;
    }
    
    /**
     * @dev Get total voting power (simplified - in practice would sum all holders)
     */
    function _getTotalVotingPower() internal view returns (uint256) {
        // Simplified implementation - in practice would calculate from token holdings
        return 1000; 
    }
    
    /**
     * @dev Admin functions
     */
    function setVotingPower(address user, uint256 power) external onlyRole(DEFAULT_ADMIN_ROLE) {
        votingPower[user] = power;
    }
    
    function setQuorum(uint256 newQuorumBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newQuorumBps <= 5000, "Quorum too high"); // Max 50%
        quorumBps = newQuorumBps;
    }
    
    /**
     * @dev View functions
     */
    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        string memory description,
        address target,
        uint256 value,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed,
        bool canceled
    ) {
        require(proposalId <= proposalCount && proposalId > 0, "Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.target,
            proposal.value,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.executed,
            proposal.canceled
        );
    }
    
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }
    
    function getVoteChoice(uint256 proposalId, address voter) external view returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "User has not voted");
        return proposals[proposalId].voteChoice[voter];
    }
    
    function canExecute(uint256 proposalId) external view returns (bool) {
        if (proposalId > proposalCount || proposalId == 0) return false;
        
        Proposal storage proposal = proposals[proposalId];
        return (
            block.timestamp > proposal.endTime + EXECUTION_DELAY &&
            !proposal.executed &&
            !proposal.canceled &&
            _isProposalSuccessful(proposalId)
        );
    }
}