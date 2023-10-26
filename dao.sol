// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract DAO {
    address public ceo;
    string public name; // Project name | プロジェクト名
    string public about; // Project description | プロジェクトの説明
    IERC20 public daoToken; // DAO token | DAOトークン
    uint256 public voteDuration = 300; // Voting duration | 投票期間

    // Proposal statuses | 提案のステータス
    enum ProposalStatus {Voting, Approved, Rejected, PassedButFailed}

	// Proposal structure | 提案の構造
    struct Proposal {
        address proposer; // Proposer's address | 提案者のアドレス
        string description; // Proposal description | 提案の説明
        bytes data; // Proposal data | 提案データ
        uint256 startBlock; // Start block of the proposal | 提案の開始ブロック
        uint256 forVotes; // Number of approval votes | 承認投票の数
        uint256 againstVotes; // Number of rejection votes | 拒否投票の数
        mapping(address => uint256) votes; // Mapping of voters and their votes | 投票者とその投票のマッピング
        ProposalStatus status; // Status of the proposal | 提案のステータス
    }

    Proposal[] public proposals; // Array of proposals | 提案の配列

    // Modifier to restrict function access | 関数アクセスを制限する修飾子
    modifier onlyDAO() {
        require(msg.sender == address(this), "Not called from this contract");
        _;
    }

    // Constructor function | コンストラクタ関数

    constructor(string memory _name, string memory _about, IERC20 _daoToken) {
        ceo = msg.sender;
        name = _name;
        about = _about;
        daoToken = _daoToken;
    }

    function createProposal(string memory _description, bytes memory _data) public {
        IERC20 daoTokenContract = IERC20(daoToken);
        require(
            msg.sender == ceo || 
            daoTokenContract.balanceOf(msg.sender) >= daoTokenContract.totalSupply() / 20,
            "Permission denied: Insufficient DAO tokens or not the CEO"
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
	        } else if (proposal.againstVotes > proposal.forVotes) {
	            proposal.status = ProposalStatus.Rejected;
	        }
	        else {
	            return;
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


    	function updateVariables(address _ceo, string memory _name, string memory _about, IERC20 _daoToken, uint256 _voteDuration) public onlyDAO {
	        ceo = _ceo;
	        name = _name;
	        about = _about;
	        daoToken = _daoToken;
	        voteDuration = _voteDuration;
    	}
}
