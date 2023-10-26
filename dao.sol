// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DAO {
    address public owner;
    string public name; 
    string public about; 
    IERC20 public daoToken; 
    uint256 public voteDuration = 300; 

    enum ProposalStatus {Voting, Approved, Rejected, PassedButFailed}

    struct Proposal {
        address proposer;
        string description;
        bytes data;
        uint256 startBlock;
        uint256 forVotes;
        uint256 againstVotes;
        mapping(address => uint256) votes;
        ProposalStatus status;
    }

    Proposal[] public proposals;

    modifier onlyDAO() {
        require(msg.sender == address(this), "Not called from this contract");
        _;
    }

    constructor(address _owner, string memory _name, string memory _about, IERC20 _daoToken) {
        owner = _owner;
        name = _name;
        about = _about;
        daoToken = _daoToken;
    }

    function createProposal(string memory _description, bytes memory _data) public {
        IERC20 daoTokenContract = IERC20(daoToken);
        require(
            msg.sender == owner || 
            daoTokenContract.balanceOf(msg.sender) >= daoTokenContract.totalSupply() / 20,
            "Permission denied: Insufficient DAO tokens or not the owner"
        );

        Proposal memory newProposal;
        newProposal.proposer = msg.sender;
        newProposal.description = _description;
        newProposal.data = _data;
        newProposal.startBlock = block.number;
        newProposal.status = ProposalStatus.Voting;

        proposals.push(newProposal);
    }

    function vote(uint256 proposalId, bool support, uint256 _pledgeAmount) public {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.status == ProposalStatus.Voting, "Proposal is not in a valid status");
        
        if (_pledgeAmount == 0) {
            _pledgeAmount = daoToken.balanceOf(msg.sender);
        }

        require(daoToken.balanceOf(msg.sender) >= _pledgeAmount, "Insufficient DAO tokens to pledge");
        require(daoToken.transferFrom(msg.sender, address(this), _pledgeAmount), "Token transfer failed");

        if (support) {
            proposal.forVotes += _pledgeAmount;
        } else {
            proposal.againstVotes += _pledgeAmount;
        }

        proposal.votes[msg.sender] += _pledgeAmount;

        executeProposal(proposalId);
    }

	function executeProposal(uint256 proposalId) public onlyDAO {
		Proposal storage proposal = proposals[proposalId];

		require(proposal.status == ProposalStatus.Voting, "Proposal is not in a valid status");

		uint256 totalVotes = proposal.forVotes + proposal.againstVotes;

		if (block.number > proposal.startBlock + voteDuration){
			if (proposal.forVotes > proposal.againstVotes) {
				proposal.status = ProposalStatus.Approved;
				(bool success,) = address(this).call(proposal.data);
				if (!success) {
					proposal.status = ProposalStatus.PassedButFailed;
				}
			} else {
				proposal.status = ProposalStatus.Rejected;
			}
		} else {
			if (proposal.forVotes * 2 > totalVotes) {
					proposal.status = ProposalStatus.Approved;
						(bool success,) = address(this).call(proposal.data);
					if (!success) {
						proposal.status = ProposalStatus.PassedButFailed;
					}
			}
			if (proposal.againstVotes * 2 > totalVotes) {
				proposal.status = ProposalStatus.Rejected;
			}
		}
		if(proposal.status != ProposalStatus.Voting){
			returnPledgedTokens(proposalId);
		}

	}

	function returnPledgedTokens(uint256 proposalId) public {
		Proposal storage proposal = proposals[proposalId];

		require(proposal.status != ProposalStatus.Voting, "Proposal is still in voting status");

		uint256 userVotes = proposal.votes[msg.sender];
		require(userVotes > 0, "No tokens to return");

		IERC20 daoTokenContract = IERC20(daoToken);

		// Transfer the pledged tokens back to the voter's account
		require(daoTokenContract.transfer(msg.sender, userVotes), "Token return failed");

		proposal.votes[msg.sender] = 0;
	}


    function updateVariables(address _owner, string memory _name, string memory _about, IERC20 _daoToken, uint256 _voteDuration) public onlyDAO {
        owner = _owner;
        name = _name;
        about = _about;
        daoToken = _daoToken;
        voteDuration = _voteDuration;
    }
}
