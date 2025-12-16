// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 磚瓦新生 DAO (KinmenRenovationDAO)
 * @dev 實作 PPT 中提及的《民法》820條共識機制：人數過半且持分過半
 */
contract KinmenDAO {
    
    // 定義屋主結構
    struct Owner {
        uint256 share; // 應有部分 (例如 1000 代表 10.00%)
        bool exists;   // 是否存在
    }

    // 定義提案結構
    struct Proposal {
        uint256 id;
        string description;       // 修繕內容描述
        uint256 voteCount;        // 同意人數
        uint256 voteShareWeight;  // 同意持分總和
        bool passed;              // 是否通過
        bool executed;            // 是否執行
        mapping(address => bool) hasVoted; // 記錄誰投過票
    }

    mapping(address => Owner) public owners; // 所有權人名冊
    address[] public ownerList;              // 用於計算總人數
    uint256 public totalShares;              // 總持分 (基數通常為 10000)
    
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    // 事件：通知前端更新
    event ProposalCreated(uint256 id, string description);
    event Voted(uint256 proposalId, address voter, uint256 share);
    event ProposalPassed(uint256 id, bool status);

    // 建構子：初始化 DAO
    constructor() {
        // 為了測試，預設部署者為第一位屋主，擁有 60% 持分 (6000/10000)
        // 實務上這裡會依據「土地登記簿謄本」輸入所有地址
        _addOwner(msg.sender, 6000);
    }

    // 內部功能：新增屋主 (僅供測試用，實務上需有權限控管)
    function addOwner(address _owner, uint256 _share) external {
        _addOwner(_owner, _share);
    }

    function _addOwner(address _owner, uint256 _share) internal {
        require(!owners[_owner].exists, "Owner already exists");
        owners[_owner] = Owner(_share, true);
        ownerList.push(_owner);
        totalShares += _share;
    }

    // 功能 1: 發起修繕提案
    function createProposal(string memory _description) external {
        require(owners[msg.sender].exists, "Only owners can propose");
        
        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.description = _description;
        
        emit ProposalCreated(proposalCount, _description);
    }

    // 功能 2: 投票 (Yes)
    function vote(uint256 _proposalId) external {
        require(owners[msg.sender].exists, "Not an owner");
        Proposal storage p = proposals[_proposalId];
        require(!p.hasVoted[msg.sender], "Already voted");
        require(!p.passed, "Proposal already passed");

        // 記錄投票
        p.hasVoted[msg.sender] = true;
        p.voteCount += 1; // 人數 +1
        p.voteShareWeight += owners[msg.sender].share; // 權重 + 持分

        emit Voted(_proposalId, msg.sender, owners[msg.sender].share);

        // 檢查是否符合《民法》820條
        checkConsensus(_proposalId);
    }

    // 邏輯核心：檢查共識 (雙重過半)
    function checkConsensus(uint256 _proposalId) internal {
        Proposal storage p = proposals[_proposalId];
        
        uint256 totalOwners = ownerList.length;
        
        // 條件 A: 同意人數過半 ( > 50% )
        bool conditionA = p.voteCount * 2 > totalOwners;
        
        // 條件 B: 同意持分合計過半 ( > 50% )
        bool conditionB = p.voteShareWeight * 2 > totalShares;

        if (conditionA && conditionB) {
            p.passed = true;
            emit ProposalPassed(_proposalId, true);
        }
    }

    // 讀取提案資訊 (供前端使用)
    function getProposal(uint256 _id) external view returns (
        string memory description,
        uint256 voteCount,
        uint256 voteShareWeight,
        bool passed,
        bool executed
    ) {
        Proposal storage p = proposals[_id];
        return (p.description, p.voteCount, p.voteShareWeight, p.passed, p.executed);
    }
}
