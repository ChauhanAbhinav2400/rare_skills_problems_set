pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenWrapper is ERC20 {

  IERC20Metadata internal immutable token;
  using SafeERC20 for IERC20Metadata; 

  event Wrap(address indexed from, uint256 amount);
  event Unwrap(address indexed to, uint256 amount);

  constructor ( address _token) ERC20("Ether", "ETH") {
    token = IERC20Metadata(_token);
  }

  function decimals() public view override returns(uint8) {
    try token.decimals() returns (uint8 d){
        return d;
    }catch{
 return 0;
    } 
   
  }


function symbol() public view override returns (string memory) {
    (bool ok , bytes memory data) = address(token).staticcall(abi.encodeWithSignature("symbol()"));
    if(ok){
        string memory sym = abi.decode(data, (string));
        return string(abi.encodePacked("w",sym));
    }else{
        return "w";
    }
}

function name() public view override returns (string memory) {
    (bool ok , bytes memory data) = address(token).staticcall(abi.encodeWithSignature("name()"));
    if(ok){
        string memory naam = abi.decode(data, (string));
        return string(abi.encodePacked("Wrapped"," ", naam));
    }else{
        return "Wrapped";
    }
}

function wrap(uint256 amount) external{
    require(amount > 0 , "Amount must be greater than 0");
    token.safeTransferFrom(msg.sender , address(this), amount);
    _mint(msg.sender , amount);
    emit Wrap(msg.sender, amount);
}

function unwrap(uint256 amount) external {
    require(amount > 0 , "Amount must be greater than 0");
    _burn(msg.sender , amount);
    token.safeTransfer(msg.sender , amount);
    emit Unwrap(msg.sender, amount);

}
}