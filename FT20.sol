// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IFT20.sol";
import "./IAdmin.sol";

/**
 * @dev The ERC20 token's parent
 * Add permit approve function, contract use this token can in one step
 * Add token unlock common function
 */
abstract contract FT20 is ERC20Permit, ICoin {

    // The token starting time
    uint256 public startTime;

    /**
     * @dev Unlock config sets
     */
    struct UnlockConf {
        uint8 percentTotal; // Percentage of total
        uint8 percentInit;  // Initial total percentage
        uint8 weekStart;  // unlock start week
        uint8 weekAll; // unlocked number of week
    }

    // The administrator contract address
    IAdmin constant public Admin = IAdmin(address(0x32a5D69F59dE8271cF5fB9F613d5487a713924b8));

    /**
     * @dev Max Token Supply
     */
    function maxSupply() virtual public pure returns (uint256);

    /**
     * @dev Throws if called by any account other than the auditor.
     */
    modifier onlyAdmin() {
        require(Admin.isAdmin(msg.sender), "Must admin");
        _;
    }

    /**
     * @dev Throws if called by any account other than the auditor.
     */
    modifier onlyAuditor() {
        require(Admin.isAuditor(msg.sender), "Must auditor");
        _;
    }

    /**
     * @dev Throws if called by any account other than the auditor.
     */
    modifier onlyMaster() {
        Admin.mustMaster(msg.sender);
        _;
    }

    /**
     * @dev unlock token to an address
     * unlock is mint
     */
    // function _unlockTo(address account, uint256 amount) public onlyAdmin {
    //     _mint(account, amount);
    // }

    /**
     * @dev token unlock total amount
     * {percentInit}% unlocked, after {weekStart} weeks, the remaining tokens will be released within {weekAll} weeks 
     */ 
    function unlockable(uint256 unlocked, uint8 percentTotal, uint8 percentInit, uint8 weekStart, uint8 weekAll) public view virtual returns (uint256) {
        require(weekAll > 0, "weekAll not be zero");
        uint256 total = (maxSupply() * percentTotal) / 100;
        if (total > unlocked) {
            uint256 week = (block.timestamp - startTime) / 86400 / 7 + 1;
            uint256 amount = (total * percentInit) / 100;
            if (week > weekStart) {
                amount += (week - weekStart) * (total * (100 - percentInit)) / 100 / weekAll;
                if (amount > total) {
                    amount = total;
                }
            }
            if (amount > unlocked) {
                return amount - unlocked;
            }
        }
        return 0;
    }

    /**
     * @dev Approve for contract
     */
    function permit(address owner, address spender, uint256 amount, bytes memory signature) public override {
        // signature check
        bytes32 digest = ECDSA.toEthSignedMessageHash(bytes(permitMsg(owner, spender, amount)));
        address recoveredSigner = ECDSA.recover(digest, signature);
        require(recoveredSigner == owner, "signature error");

        _useNonce(owner);
        _approve(owner, spender, amount);
    }

    /**
     * @dev Get approve signature message
     */
    function permitMsg(address owner, address spender, uint256 amount) public view returns(string memory) {
        return string(abi.encodePacked("Approve ", Strings.toString(amount / (10 ** decimals())), " ", symbol(), "(", addressToString(address(this)), ") to ", addressToString(spender), " with ", Strings.toString(nonces(owner) + 1)));
    }

    /**
     * @dev Address to string
     */
    function addressToString(address _address) public pure returns(string memory) {
       bytes32 _bytes = bytes32(uint256(uint160(_address)));
       bytes memory HEX = "0123456789abcdef";
       bytes memory _string = new bytes(42);
       _string[0] = '0';
       _string[1] = 'x';
       for(uint i = 0; i < 20; i++) {
           _string[2+i*2] = HEX[uint8(_bytes[i + 12] >> 4)];
           _string[3+i*2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
       }
       return string(_string);
    }
}
