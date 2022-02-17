// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

import "prb-math/contracts/PRBMathSD59x18.sol";

import "./GovernorCountingExtended.sol";

contract GovernorContract is
    Governor,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    using PRBMathSD59x18 for int256;

    uint256 public s_votingDelay;
    uint256 public s_votingPeriod;

    uint256 public s_votingHalfBlock;

    uint256 public blockNumberDeployed;

    address public temporaryManager;

    constructor(
        ERC20Votes _token,
        TimelockController _timelock,
        uint256 _quorumPercentage,
        uint256 _votingPeriod,
        uint256 _votingDelay,
        uint256 _votingHalfBlock
    )
        Governor("GovernorContract")
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorumPercentage)
        GovernorTimelockControl(_timelock)
    {
        s_votingDelay = _votingDelay;
        s_votingPeriod = _votingPeriod;
        s_votingHalfBlock = _votingHalfBlock;

        blockNumberDeployed = block.number;

        temporaryManager = msg.sender;
    }

    function setTemporaryManager(address newManager) public {
        require(temporaryManager == msg.sender, "Not existing manager");
        temporaryManager = newManager;
    }

    function votingDelay() public view override returns (uint256) {
        return s_votingDelay; // 1 = 1 block
    }

    function votingPeriod() public view override returns (uint256) {
        return s_votingPeriod; // 45818 = 1 week
    }

    // The following functions are overrides required by Solidity.

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function getBlockDifference(uint256 blockNumber) public view returns (uint256) {
        if (blockNumber > blockNumberDeployed) {
            return blockNumber - blockNumberDeployed;
        } else {
            return 0;
        }
    }

    function stretchedExponential(int256 x, int256 a, int256 b) internal pure returns (int256) {
        int256 exp = -(PRBMathSD59x18.fromInt(x).div(PRBMathSD59x18.fromInt(a))).pow(PRBMathSD59x18.fromInt(b));
        return PRBMathSD59x18.scale()-PRBMathSD59x18.e().pow(exp);
    }

    function getBallotWeightFromBlockNumber(uint256 blockNumber) public view returns (int256) {
        int256 x = int(getBlockDifference(blockNumber));
        int256 a = PRBMathSD59x18.fromInt(int(s_votingHalfBlock))
            .mul(PRBMathSD59x18.sqrt(PRBMathSD59x18.ln(PRBMathSD59x18.fromInt(2))).inv()).toInt();
        int256 b = 2;
        return stretchedExponential(x, a, b);
    }

    // A = user votes, B = manager votes, a = ballot weight, b = manager weight
    // A + B = (A + B)(a + b) = Aa + Ab + Ba + Bb = [Aa] + [(A+B)b + Ba] <- [user part] + [manager part]
    function getWeightedVotes(address account, uint256 blockNumber, int256 ballotWeight) internal view returns (uint256) {
        uint256 userWeightedVotes = uint(PRBMathSD59x18.fromInt(int(super.getVotes(account, blockNumber))).mul(ballotWeight).toInt());
        if (account == temporaryManager) {
            uint256 totalWeightedVotes = uint(PRBMathSD59x18.fromInt(int(token.totalSupply())).mul(PRBMathSD59x18.scale() - ballotWeight).toInt());
            return totalWeightedVotes + userWeightedVotes;
        } else {
            return userWeightedVotes;
        }
    }

    function getVotes(address account, uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotes)
        returns (uint256)
    {
        int256 ballotWeight = getBallotWeightFromBlockNumber(blockNumber);
        return getWeightedVotes(account, blockNumber, ballotWeight);
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor, IGovernor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
