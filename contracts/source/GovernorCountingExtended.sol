// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (governance/extensions/GovernorCountingSimple.sol)

pragma solidity ^0.8.0;

// import "../Governor.sol";
import "@openzeppelin/contracts/governance/Governor.sol";

/**
 * @dev Extension of {Governor} for simple, 3 options, vote counting.
 *
 * _Available since v4.3._
 */
abstract contract GovernorCountingSimple is Governor {
    /**
     * @dev Supported vote types. Matches Governor Bravo ordering.
     */
    enum VoteType {
        Against,
        For,
        Abstain
    }

    enum OptionType {
        Single,
        Address,
        UNumber,
        Number,
        Boolean
    }

    struct ProposalOptionData {
        address _address;
        uint256 _unumber;
        int256 _number;
        bool _boolean;
    }

    struct ProposalOption {
        uint256 forVotes;
        string description;
        ProposalOptionData data;
    }

    struct ProposalVote {
        ProposalOption[] options;
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
        uint8 dataType;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => ProposalVote) private _proposalVotes;

    /**
     * @dev See {IGovernor-COUNTING_MODE}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=bravo&quorum=for,abstain";
    }

    /**
     * @dev See {IGovernor-hasVoted}.
     */
    function hasVoted(uint256 proposalId, address account) public view virtual override returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    /**
     * @dev Accessor to the internal vote counts.
     */
    function proposalVotes(uint256 proposalId)
        public
        view
        virtual
        returns (
            uint256 againstVotes,
            uint256 forVotes,
            uint256 abstainVotes
        )
    {
        ProposalVote storage proposalvote = _proposalVotes[proposalId];
        return (proposalvote.againstVotes, proposalvote.forVotes, proposalvote.abstainVotes);
    }

    function optionSucceeded(uint256 proposalId)
        public
        view
        virtual
        returns (uint256)
    {
        ProposalOption[] memory proposalvote = _proposalVotes[proposalId].options;

        uint256 maxVoteWeights = 0;
        uint256 index = 0;

        for (uint i = 0; i < proposalvote.length; i++) {
            if (proposalvote[i].forVotes > maxVoteWeights) {
                maxVoteWeights = proposalvote[i].forVotes;
                index = i;
            }
        }

        return index;
    }

    function proposalDataType(uint256 proposalId) public view returns (uint8) {
        ProposalVote storage proposalvote = _proposalVotes[proposalId];
        return proposalvote.dataType;
    }

    function optionParam(uint256 proposalId, uint256 index) public view returns (ProposalOption memory) {
        ProposalOption[] memory proposalvote = _proposalVotes[proposalId].options;

        if (proposalvote.length == 0) {
            return ProposalOption(0, "", ProposalOptionData(address(0), 0, 0, false));
        } else {
            return proposalvote[index];
        }
    }

    function optionVotes(uint256 proposalId)
        public
        view
        virtual
        returns (
            uint256[] memory,
            string[] memory
        )
    {
        ProposalOption[] storage proposalvote = _proposalVotes[proposalId].options;

        uint256[] memory voteWeights = new uint256[](proposalvote.length);
        for (uint i = 0; i < proposalvote.length; i++) {
            voteWeights[i] = proposalvote[i].forVotes;
        }

        string[] memory votesDescriptions = new string[](proposalvote.length);
        for (uint i = 0; i < proposalvote.length; i++) {
            votesDescriptions[i] = proposalvote[i].description;
        }

        return (voteWeights, votesDescriptions);
    }

    /**
     * @dev See {Governor-_quorumReached}.
     */
    function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalvote = _proposalVotes[proposalId];

        return quorum(proposalSnapshot(proposalId)) <= proposalvote.forVotes + proposalvote.abstainVotes;
    }

    /**
     * @dev See {Governor-_voteSucceeded}. In this module, the forVotes must be strictly over the againstVotes.
     */
    function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
        ProposalVote storage proposalvote = _proposalVotes[proposalId];

        return proposalvote.forVotes > proposalvote.againstVotes;
    }

    /**
     * @dev See {Governor-_countVote}. In this module, the support follows the `VoteType` enum (from Governor Bravo).
     */
    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 weight
    ) internal virtual override {
        ProposalVote storage proposalvote = _proposalVotes[proposalId];

        require(!proposalvote.hasVoted[account], "GovernorVotingSimple: vote already cast");
        proposalvote.hasVoted[account] = true;

        if (proposalvote.dataType == uint8(OptionType.Single)) {

            if (support == uint8(VoteType.Against)) {
                proposalvote.againstVotes += weight;
            } else if (support == uint8(VoteType.For)) {
                proposalvote.forVotes += weight;
            } else if (support == uint8(VoteType.Abstain)) {
                proposalvote.abstainVotes += weight;
            } else {
                revert("GovernorVotingSimple: invalid value for enum VoteType");
            }
        } else {

            if (support == uint8(VoteType.Against)) { // against
                proposalvote.againstVotes += weight;
            } else if (proposalvote.options.length > support) { // for
                proposalvote.options[support].forVotes += weight;
                proposalvote.forVotes += weight;
            } else { // abstain
                proposalvote.abstainVotes += weight;
            }
        }
    }

    function setOptionDataType(uint256 proposalId, uint8 dataType)
        internal
    {
        ProposalVote storage proposal = _proposalVotes[proposalId];
        proposal.dataType = dataType;

        ProposalOptionData memory optionData = ProposalOptionData(address(0), 0, 0, false);

        ProposalOption memory option = ProposalOption(0, "Against", optionData);
        proposal.options.push(option);
    }

    function addOptionToProposal(uint256 proposalId, string memory description, bool boolean)
        public
    {
        ProposalVote storage proposal = _proposalVotes[proposalId];

        require(proposal.dataType == uint8(OptionType.Boolean), "Option should be a boolean");

        ProposalOptionData memory optionData = ProposalOptionData(address(0), 0, 0, boolean);
        proposal.options.push(ProposalOption(0, description, optionData));
    }

    function proposalOptionCount(uint256 proposalId)
        public
        view
        returns (uint256)
    {
        return _proposalVotes[proposalId].options.length;
    }

    function optionSucceededParameters(uint256 proposalId) internal view returns (bytes memory) {

        uint8 dataType = proposalDataType(proposalId);
        uint256 index = optionSucceeded(proposalId);
        ProposalOption memory proposalOption = optionParam(proposalId, index);

        if (dataType == uint8(OptionType.Address)) {
            address param = proposalOption.data._address;
            return abi.encodePacked(param);
        } else if (dataType == uint8(OptionType.UNumber)) {
            uint256 param = proposalOption.data._unumber;
            return abi.encodePacked(param);
        } else if (dataType == uint8(OptionType.Number)) {
            int256 param = proposalOption.data._number;
            return abi.encodePacked(param);
        } else if (dataType == uint8(OptionType.Boolean)) {
            bool param = proposalOption.data._boolean;
            return abi.encodePacked(uint(param ? 1 : 0));
        } else {
            revert("GovernorVotingSimple: invalid value for enum OptionType");
        }
    }

    function optionSucceededCalldatas(uint256 proposalId, bytes[] memory datas) public view returns (bytes[] memory) {
        
        uint8 dataType = proposalDataType(proposalId);
        if (dataType == uint8(OptionType.Single)) {
            return datas;
        }
        
        bytes[] memory calldatas = new bytes[](datas.length);
        
        for (uint y = 0; y < datas.length; y++) {

            bytes memory functionSignature = new bytes(4);
            for (uint i = 0; i < 4; i++) {
                functionSignature[i] = datas[y][i];
            }

            bytes memory functionParameters = new bytes(datas[y].length - 4);
            for (uint i = 0; i < datas[y].length - 4; i++) {
                functionParameters[i] = datas[y][i+4];
            }

            calldatas[y] = abi.encodePacked(functionSignature, optionSucceededParameters(proposalId));
        }

        return calldatas;
    }
}
