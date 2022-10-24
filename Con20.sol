// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./FT20.sol";

/**
 * @dev Token CON for ClashOfNFT
 * Unlock as planned for group
 */
contract CON is FT20 {
    mapping(UnlockGroup => UnlockConf) public groupUnlockConfs;
    mapping(UnlockGroup => uint256) public unlockedAmounts; // group => unlocked amount 
    mapping(UnlockGroup => string) public groupLabels; // group => group label

    /**
     * @dev Unlock group enum
     */
    enum UnlockGroup {
        None,
        Reward,
        Team,
        Ecological,
        Airdrop
    }

    /**
     * @dev Constructor init the unlock config
     */
    constructor() ERC20("ClashOfNFT CON", "CON") ERC20Permit("ClashOfNFT CON") {
        startTime = block.timestamp;
        groupUnlockConfs[UnlockGroup.Reward] = UnlockConf(75, 0, 0, 104);
        groupLabels[UnlockGroup.Reward] = "Reward";
        groupUnlockConfs[UnlockGroup.Team] = UnlockConf(10, 0, 52, 104);
        groupLabels[UnlockGroup.Team] = "Team";
        groupUnlockConfs[UnlockGroup.Ecological] = UnlockConf(12, 100, 0, 1);
        groupLabels[UnlockGroup.Ecological] = "Ecological";
        groupUnlockConfs[UnlockGroup.Airdrop] = UnlockConf(3, 50, 1, 52);
        groupLabels[UnlockGroup.Airdrop] = "Airdrop";
    }

    /**
     * @dev set decimals 9
     */
    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    /**
     * @dev Max Token Supply
     */
    function maxSupply() public pure override returns (uint256) {
        return 500000000000000000;
    }

    /**
     * @dev Get group unlockable amounts
     * 10 of total, unlocked within 104 weeks 
     */
    function unlockableOfGroup(UnlockGroup group) public view returns (uint256) {
        UnlockConf memory conf = groupUnlockConfs[group];
        return unlockable(unlockedAmounts[group], conf.percentTotal, conf.percentInit, conf.weekStart, conf.weekAll);
    }

    /**
     * @dev unlock group token to an address
     * Multiple administrator signatures are required
     */
    function unlockGroupTo(UnlockGroup group, address account, uint256 amount) public onlyAuditor {
        require(group != UnlockGroup.None);
        uint256 maxAmount = unlockableOfGroup(group);
        require(amount <= maxAmount, "Amount insufficient");
        bytes memory bkdata = abi.encodeWithSignature("_unlockTo(address,uint256)", account, amount);
        string memory descr = string(abi.encodePacked(symbol(), " unlock ", groupLabels[group], " ", Strings.toString(amount / (10 ** decimals())), " to ", addressToString(account)));
        Admin.audit(bkdata, descr);
        unlockedAmounts[group] += amount;
    }

    /**
     * @dev unlock reward token to an address
     * Multiple administrator signatures are required
     */
    function unlockRewardTo(address account, uint256 amount) public onlyAuditor {
        unlockGroupTo(UnlockGroup.Reward, account, amount);
    }

}