//SPDX-License-Identifier  :    MIT
pragma solidity ^0.8.26;

contract Account {

address owner ;

constructor (address _owner) payable {
    owner = _owner;
}

function withdraw() external {
    require(msg.sender == owner , "Not Owner");
    (bool ok , ) = owner.call{value:address(this).balance}("");
    require(ok);
}
}

contract AccountMaker {
    function makeAccount(address owner) external payable returns(address walletAddr) {
     bytes32 salt = bytes32(uint256(uint160(owner)));
     Account account = new Account{salt:salt, value : msg.value}(owner);
     walletAddr = address(account);
     return walletAddr;
    }

   function computeAddress(address owner) external view returns(address wltadr) {
   bytes32 salt = bytes32(uint256(uint160(owner)));
   bytes memory  bytecode  = abi.encodePacked(type(Account).creationCode,
   abi.encode(owner)
   );
   bytes32  hash = keccak256(
    abi.encodePacked(
    bytes1(0xff),
    address(this),
    salt,
    keccak256(bytecode))
   );
   wltadr = address(uint160(uint256(hash)));
   }

}