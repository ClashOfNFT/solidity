// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

/**
 * @dev Interface for Admin
 * This realize multi-sign audit
 */
interface IAdmin {
    function mustAudited(address to) external view;
    function mustMaster(address addr) external view;
    function isMaster(address addr) external view returns (bool);
    function isAdmin(address addr) external view returns (bool);
    function isAuditor(address addr) external view returns (bool);
    function inAddress(address addr) external view returns (bool);
    function audit(bytes memory bkdata, string memory descr) external;
    function auditMsg(address from, address to) external view returns(bytes32);
    function checkSignature(bytes32 message, bytes[] memory signatures) external view returns (bool);
    function addressToString(address _address) external pure returns(string memory);
}