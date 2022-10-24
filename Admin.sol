// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./IAdmin.sol";

/**
 * @dev struct of signatures meta
 */
struct SignMeta {
    uint64 id;
    address bkaddr;
    bytes bkdata;
    string descr;
    address[] signed;
}

/**
 * @dev Multi-sign administrator.
 * This contract implements the management of multiple administrator signatures
 * Does not require proxy, is deployed first.
 */
contract Admin is IAdmin {
    address public master; // master

    mapping(address => uint8) public auditors; // auditors
    address[] public _auditors;

    uint256 _signId; // sign id
    mapping(uint256 => uint256) _signs; // signID => index of _signings
    SignMeta[] private _signings; // wait signID

    mapping(address => bool) public addresses; // audited address

    /**
     * @dev Throws if called by any account other than the master.
     */
    modifier onlyMaster() {
        require(isMaster(msg.sender), "Must master");
        _;
    }

    /**
     * @dev Throws if called by any account other than the auditor.
     */
    modifier onlyAuditor() {
        require(isAuditor(msg.sender), "Must auditor");
        _;
    }

    /**
     * @dev Throws if called by any account other than the auditor.
     */
    modifier onlyAdmin() {
        require(address(this) == msg.sender, "Must admin");
        _;
    }

    /**
     * @dev Throws if called by any account other than the auditor.
     */
    modifier onlyInAddress() {
        require(inAddress(msg.sender) || address(this) == msg.sender, "Must in address");
        _;
    }

    /**
     * @dev constructor
     */
    constructor() {
        initMaster(msg.sender);
    }

    /**
     * @dev init the master address.
     * the proxy call
     */
    function initMaster(address addr) public {
        if (master == address(0)) {
            master = addr;
        }
    }

    /**
     * @dev Get wait sign infomation
     */
    function waits() public view returns (SignMeta[] memory) {
        return _signings;
    }

    /**
     * @dev Agreement the sign
     */
    function agree(uint256 signID) public onlyAuditor {
        _agree(signID);
    }

    /**
     * @dev Agreement the sign
     */
    function _agree(uint256 signID) internal {
        SignMeta storage sign = _signings[_signs[signID]];
        require(sign.id == signID);
        if (_addressOf(sign.signed, msg.sender) == -1) {
            sign.signed.push(msg.sender);
        }
        if (_signings[_signs[signID]].signed.length >= (_auditors.length + 1) * 2 / 3) {
            // sign complete
            Address.functionCall(sign.bkaddr, sign.bkdata);
            if (_signs[signID] < _signings.length - 1) {
                // last element replace current
                _signs[_signings[_signings.length - 1].id] = _signs[signID];
                _signings[_signs[signID]] = _signings[_signings.length - 1];
            }
            delete _signs[signID];
            _signings.pop();
        }
    }

    /**
     * @dev Create a signature item
     */
    function audit(bytes memory bkdata, string memory descr) public override onlyInAddress {
        address bkaddr = msg.sender;
        require(Address.isContract(bkaddr), "Must contract");

        uint256 lessCount = (_auditors.length + 1) * 2 / 3;
        if (lessCount <= 1) {
            Address.functionCall(bkaddr, bkdata);
        } else {
            uint256 signID = ++ _signId;
            descr = string(abi.encodePacked(descr, ", ID ", Strings.toString(signID)));
            _signings.push(SignMeta(uint64(signID), bkaddr, bkdata, descr, new address[](0)));
            _signs[signID] = _signings.length - 1;
            _agree(signID);
        }
    }

    /**
     * @dev start transfer auditor
     * if empty auditors success at once
     */
    function updateAuditor(address from, address to) public onlyMaster {
        require(from == address(0) || isAuditor(from), "Address from invalid");
        require(to == address(0) || !isAuditor(to), "Address to invalid");

        bytes memory bkdata = abi.encodeWithSignature("_updateAuditor(address,address)", from, to);
        string memory descr = string(abi.encodePacked("Update auditor ", addressToString(from), " to ", addressToString(to)));
        this.audit(bkdata, descr);
    }

    /**
     * @dev Add a new auditor
     */
    function addAuditor(address addr) public onlyMaster {
        updateAuditor(address(0), addr);
    }

    /**
     * @dev Delete a auditor
     */
    function delAuditor(address addr) public onlyMaster {
        updateAuditor(addr, address(0));
    }

    /**
     * @dev Transfer of authority.
     * At least two people agreed
     */
    function updateAuditor(address from, address to, bytes[] memory signatures) public onlyMaster {
        require(from == address(0) || isAuditor(from), "Address from invalid");
        require(to == address(0) || !isAuditor(to), "Address to invalid");
        checkSignature(auditMsg(from, to), signatures);
        this._updateAuditor(from, to);
    }

    /**
     * @dev Transfer of authority.
     */
    function _updateAuditor(address from, address to) public onlyAdmin {
        if (from == master) {
            master = to;
        } else {
            // delete from address
            if (from != address(0)) {
                uint8 index = auditors[from];
                delete auditors[from];
                
                if (to != address(0)) {
                    // add to address
                    auditors[to] = index;
                    _auditors[index] = to;
                } else {
                    // delete from the array
                    if (index < _auditors.length - 1) {
                        to = _auditors[_auditors.length - 1];
                        auditors[to] = index;
                        _auditors[index] = to;
                    }
                    _auditors.pop();
                }
            } else if (to != address(0)) {
                _auditors.push(to);
                auditors[to] = uint8(_auditors.length - 1);
            }
        }
    }

    /**
     * @dev Get transfer Auditor signature message
     */
    function auditMsg(address from, address to) public view override returns(bytes32) {
        return ECDSA.toEthSignedMessageHash(abi.encode(address(this), "AdminAudit", from, to));
    }

    /**
     * @dev Check signature.
     * Returns a boolean value indicating whether the operation succeeded.
     */
    function checkSignature(bytes32 message, bytes[] memory signatures) public view override returns(bool) {
        uint256 length = _auditors.length * 2 / 3;
        require(signatures.length >= length, "Signature insufficient");
        address[] memory signs = _auditors;
        for (uint256 i = 0; i < length; i++) {
            address recoveredSigner = ECDSA.recover(message, signatures[i]);
            uint256 index = auditors[recoveredSigner];
            require(signs[index] == recoveredSigner, "Signature error");
            signs[index] = address(0);  // Prevent Duplicate signature
        }
        return true;
    }

    /**
     * @dev start transfer address
     * if empty auditors success
     */
    function updateAddress(address from, address to) public onlyMaster {
        require(addresses[from] == true || from == address(0));
        require(addresses[to] == false);

        bytes memory bkdata = abi.encodeWithSignature("_updateAddress(address,address)", from, to);
        string memory descr = string(abi.encodePacked("Update address ", addressToString(from), " to ",addressToString(to)));
        this.audit(bkdata, descr);
    }

    /**
     * @dev Allows the agent to upgrade to the new address
     */
    function updateAddress(address from, address to, bytes[] memory signatures) public onlyMaster {
        require(addresses[from] == true || from == address(0));
        require(addresses[to] == false);
        checkSignature(auditMsg(from, to), signatures);
        this._updateAddress(from, to);
    }

    /**
     * @dev Allows the agent to upgrade to the new address
     */
    function _updateAddress(address from, address to) public onlyAdmin {
        if (from != address(0)) {
            delete addresses[from];
        }
        if (to != address(0)) {
            addresses[to] = true;
        }
    }

    /**
     * @dev Throws If fail the audit.
     */
    function mustAudited(address to) override public view {
        if (_auditors.length > 1) {
            require(addresses[to], "Must audited");
        }
    }

    /**
     * @dev Throws if called by any account other than the master.
     */
    function mustMaster(address addr) override public view {
        require(isMaster(addr), "Must master");
    }

    /**
     * @dev Whether address is master.
     */
    function isMaster(address addr) override public view returns (bool) {
        return master == addr;
    }

    /**
     * @dev Whether address is auditor.
     */
    function isAuditor(address addr) public view override returns (bool) {        
        return isMaster(addr) || _auditors.length > 0 && _auditors[auditors[addr]] == addr;
    }

    /**
     * @dev Whether address is this contract address.
     */
    function isAdmin(address addr) public view override returns (bool) {
        return address(this) == addr;
    }

    /**
     * @dev Whether address in audited address.
     */
    function inAddress(address addr) public view override returns (bool) {
        return addresses[addr];
    }

    /**
     * @dev array indexOf, same as javascript
     * Return -1 if the address not in addresses, else return index
     */
    function _addressOf(address[] memory arr, address addr)
        internal
        pure
        returns (int256)
    {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == addr) {
                return int256(i);
            }
        }
        return -1;
    }

    /**
     * @dev address to string
     */
    function addressToString(address _address) public pure override returns(string memory) {
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