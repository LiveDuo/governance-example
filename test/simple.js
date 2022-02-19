const { ethers, upgrades } = require('hardhat')
const { expect } = require('chai')
const { fromBn } = require('evm-bn')

const secondsInDay = 24 * 60 * 60
const secondsInBock = 17

const blockNumberAfterDays = (days) => Math.round(days * secondsInDay / secondsInBock)

// Governance Parameters
const QUORUM_PERCENTAGE = 4 // percentage
const VOTING_PERIOD = 5 // blocks
const VOTING_DELAY = 1 // block
const TIMELOCK_DELAY = 1 // seconds
const EQUALIBRIUM_BLOCK = blockNumberAfterDays(180) // periods

const ProposalState = [
	'Pending',
	'Active',
	'Canceled',
	'Defeated',
	'Succeeded',
	'Queued',
	'Expired',
	'Executed'
]

const OptionTypes = [
	'Single',
	'Address',
	'UNumber',
	'Number',
	'Boolean'
]

describe('Compound Governance', () => {

	let governanceToken, governor

	before(async () => {
		
		// get owner account
		const [owner] = await ethers.getSigners()

		// deploy governance token
		const GovernanceToken = await ethers.getContractFactory('GovernanceToken', owner)
		governanceToken = await upgrades.deployProxy(GovernanceToken, [], { initializer: 'initialize' })

		await governanceToken.connect(owner).delegate(owner.address)

		// deploy timelock
		const GovernanceTimeLock = await ethers.getContractFactory('GovernanceTimeLock')
		const governanceTimeLock = await GovernanceTimeLock.deploy(TIMELOCK_DELAY, [], [])

		// deploy governor
		const GovernorContract = await ethers.getContractFactory('GovernorContract')
		governor = await GovernorContract.deploy(governanceToken.address, governanceTimeLock.address, QUORUM_PERCENTAGE, VOTING_PERIOD, VOTING_DELAY, EQUALIBRIUM_BLOCK)

		// get governance roles
		const proposerRole = await governanceTimeLock.PROPOSER_ROLE()
		const executorRole = await governanceTimeLock.EXECUTOR_ROLE()

		// set governance roles
		await governanceTimeLock.connect(owner).grantRole(proposerRole, governor.address)
		await governanceTimeLock.connect(owner).grantRole(executorRole, ethers.constants.AddressZero)

		// transfer ownership to governor contract
		const transferOwnershipTx = await governanceToken.connect(owner).transferOwnership(governanceTimeLock.address)
		await transferOwnershipTx.wait()

		// check voting power
		const ballotWeightAt0 = await governor.getBallotWeightFromBlockNumber(0)
		expect(parseFloat(fromBn(ballotWeightAt0))).to.equal(0)
		
		const totalVotes = await governanceToken.totalSupply()
		expect(parseFloat(fromBn(totalVotes))).to.equal(1000000)

	})

	it('Should deploy, propose and execute a proposal', async () => {
		
		// const eventFilterPropose = governor.filters.ProposalCreated()
		// const events = await governor.queryFilter(eventFilterPropose)
		// const proposalIds = events.map(e => e.args.proposalId._hex)
		// const proposal = await governor._proposalsExtended(proposalIds[0])
		// console.log(proposal)

		console.log()
		console.log('Creating Proposal')
		const description = 'Proposal #2: Create DAI bond!'
		const functionEncoded = governanceToken.interface.encodeFunctionData('createAnotherBond', [true])
		const proposeTx = await governor.proposeMultipleOptions([governanceToken.address], [0], [functionEncoded], description, OptionTypes.indexOf('Boolean'))
		const tx = await proposeTx.wait()
		const proposalId = tx.events[0].args.proposalId
		const proposalStateIdBefore = await governor.state(proposalId)
		console.log('-> Proposal State:', ProposalState[proposalStateIdBefore])
		console.log()

		console.log('Adding Options to Proposal')
		await governor.addOptionToProposal(proposalId, 'Vote true', true)
		await governor.addOptionToProposal(proposalId, 'Vote false', false)
		const proposalOptionCount = await governor.proposalOptionCount(proposalId)
		console.log('-> Proposal Option Count:', proposalOptionCount.toString())
		console.log()

		console.log('Mining 1 block')
		await network.provider.send('evm_mine')

		await governor.castVote(proposalId, 1) // voting option 1
		
		const proposalStateId = await governor.state(proposalId)
		console.log('-> Proposal State:', ProposalState[proposalStateId])
		console.log()

		console.log('Mining 3 blocks')
		await network.provider.send('evm_mine')
		await network.provider.send('evm_mine')
		await network.provider.send('evm_mine')

		const proposalStateIdAfter = await governor.state(proposalId)
		console.log('-> Proposal State:', ProposalState[proposalStateIdAfter])

		const votes = await governor.optionVotes(proposalId)
		const votesString = votes[0].map((v, i) => `${votes[1][i]} (${Math.floor(ethers.utils.formatUnits(v, 18))})`).join(', ')
		console.log('-> Proposals:', votesString)

		const proposalSucceededOption = await governor.optionSucceeded(proposalId)
		console.log('-> Proposal Option Succeeded:', proposalSucceededOption.toString())
		console.log('-> Encoded Function:', functionEncoded)
		console.log()

		const descriptionHash = ethers.utils.id(description)
		const functionEncodedParameter = await governor.getCalldatas(proposalId, [functionEncoded])
			.then(x => x[0])

		await governor.queue([governanceToken.address], [0], [functionEncodedParameter], descriptionHash)
		await governor.execute([governanceToken.address], [0], [functionEncodedParameter], descriptionHash)

		const result = await governanceToken.started()
		console.log('Executing Proposal')
		console.log('-> Function Result:', result.toString())
		console.log()
	})
})
