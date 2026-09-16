// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import "target/{{VERSION}}.sol";

interface IHalmosVM {
    function assume(bool condition) external;
    function prank(address msgSender) external;
}

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract LendingProtocolTest {
    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @notice Property: dep-tokens
    function check_dep_tokens_try_catch(address userA, uint256 amt, uint256 idx) public {

        vm.assume(userA != address(0));

        MockERC20 t0 = new MockERC20();
        MockERC20 t1 = new MockERC20();
        LendingProtocol protocol = new LendingProtocol(IERC20(address(t0)), IERC20(address(t1)));

        address T = (idx == 0) ? address(protocol.tok0()) : address(protocol.tok1());
        IERC20 tokenT = IERC20(T);
        MockERC20 mockT = MockERC20(T);

        mockT.mint(userA, amt);

        vm.prank(userA);
        mockT.approve(address(protocol), amt);

        uint256 protoBalBefore = tokenT.balanceOf(address(protocol));
        uint256 userBalBefore = tokenT.balanceOf(userA);
        
        vm.prank(userA);
        try protocol.deposit(amt, T) {            
            assert(tokenT.balanceOf(address(protocol)) - protoBalBefore == amt);
            assert(userBalBefore - tokenT.balanceOf(userA) == amt);
        } catch {}

    }
}