// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract GovernanceToken is Initializable, OwnableUpgradeable, ERC20Upgradeable, ERC20PermitUpgradeable, ERC20VotesUpgradeable {

    bool public started;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {

        __ERC20_init("GovernanceToken", "GT");
        __ERC20Permit_init("GovernanceToken");

        _mint(msg.sender, 500_000 * 1e18);
        _mint(address(this), 500_000 * 1e18);

        __Ownable_init();
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20VotesUpgradeable, ERC20Upgradeable) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20VotesUpgradeable, ERC20Upgradeable) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20VotesUpgradeable, ERC20Upgradeable) {
        super._burn(account, amount);
    }

    function createBond() public onlyOwner {
        started = true;
    }

    function createAnotherBond(bool _started) public onlyOwner {
        started = _started;
    }

}
