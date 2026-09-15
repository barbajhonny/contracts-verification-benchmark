// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import "target/{{VERSION}}.sol";

interface IHalmosVM {
    function assume(bool condition) external;
    function prank(address msgSender) external;
    function deal(address account, uint256 newBalance) external;
}

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        return true;
    }
}

contract LendingProtocolTest {
    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @notice Property: credits-zero
    function check_credits_zero() public {

        MockERC20 tok0 = new MockERC20();
        MockERC20 tok1 = new MockERC20();
        
        LendingProtocol protocol = new LendingProtocol(IERC20(address(tok0)), IERC20(address(tok1)));

        address t0 = address(protocol.tok0());
        address t1 = address(protocol.tok1());

        if (protocol.sum_credits(t0) == 0) {
            assert(protocol.sum_debits(t0) == 0);
            assert(protocol.reserves(t0) == 0);
        }

        if (protocol.sum_credits(t1) == 0) {
            assert(protocol.sum_debits(t1) == 0);
            assert(protocol.reserves(t1) == 0);
        }
    }
}