// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./FT20.sol";

/**
 * @dev Token RON for ClashOfNFT
 * Unlock as planned for group
 */
contract RON is FT20 {
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
        DAO,
        PrivateSales,
        Liquid,
        IDO
    }

    /**
     * @dev Constructor init the unlock config
     */
    constructor() ERC20("ClashOfNFT RON", "RON") ERC20Permit("ClashOfNFT RON") {
        startTime = block.timestamp;
        groupUnlockConfs[UnlockGroup.Reward] = UnlockConf(50, 0, 0, 104);
        groupLabels[UnlockGroup.Reward] = "Reward";
        groupUnlockConfs[UnlockGroup.Team] = UnlockConf(10, 0, 52, 104);
        groupLabels[UnlockGroup.Team] = "Team";
        groupUnlockConfs[UnlockGroup.DAO] = UnlockConf(15, 100, 0, 1);
        groupLabels[UnlockGroup.DAO] = "DAO";
        groupUnlockConfs[UnlockGroup.PrivateSales] = UnlockConf(5, 50, 1, 104);
        groupLabels[UnlockGroup.PrivateSales] = "Private Sales";
        groupUnlockConfs[UnlockGroup.Liquid] = UnlockConf(15, 100, 0, 1);
        groupLabels[UnlockGroup.Liquid] = "Liquid";
        groupUnlockConfs[UnlockGroup.IDO] = UnlockConf(5, 100, 0, 1);
        groupLabels[UnlockGroup.IDO] = "IDO";
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
        return 100000000000000000;
    }

    /**
     * @dev Get group unlockable amounts
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