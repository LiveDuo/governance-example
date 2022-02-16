require('@nomiclabs/hardhat-waffle')
require('@openzeppelin/hardhat-upgrades')

module.exports = {
	solidity: {
		version: '0.8.4',
		settings: {
			optimizer: {
				enabled: true,
				runs: 400,
			},
		},
	}
}
