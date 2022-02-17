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

    struct ProposalOption {
        uint256 forVotes;
        string description;
    }

    struct ProposalVote {
        ProposalOption[] options;
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
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

    function proposalOptionVotes(uint256 proposalId)
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

        if (proposalvote.options.length > 0) {

            if (support == uint8(VoteType.Against)) { // against
                proposalvote.againstVotes += weight;
            } else if (proposalvote.options.length > support) { // for
                proposalvote.options[support].forVotes += weight;
                proposalvote.forVotes += weight;
            } else { // abstain
                proposalvote.abstainVotes += weight;
            }

        } else {

            if (support == uint8(VoteType.Against)) {
                proposalvote.againstVotes += weight;
            } else if (support == uint8(VoteType.For)) {
                proposalvote.forVotes += weight;
            } else if (support == uint8(VoteType.Abstain)) {
                proposalvote.abstainVotes += weight;
            } else {
                revert("GovernorVotingSimple: invalid value for enum VoteType");
            }
        }
    }

    function addOptionToProposal(uint256 proposalId, string memory description)
        public
    {
        ProposalVote storage proposal = _proposalVotes[proposalId];
        if (proposal.options.length == 0) {
            ProposalOption memory againstOption = ProposalOption(0, "Against");
            proposal.options.push(againstOption);
        }
        ProposalOption memory option = ProposalOption(0, description);
        proposal.options.push(option);
    }

    function proposalOptionCount(uint256 proposalId)
        public
        view
        returns (uint256)
    {
        return _proposalVotes[proposalId].options.length;
    }
}
