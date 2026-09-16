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

    /// @notice Property: bor-tokens
    function check_bor_tokens(address userA, uint256 amt, uint256 idx) public {
        vm.assume(userA != address(0));
        
        MockERC20 t0 = new MockERC20();
        MockERC20 t1 = new MockERC20();
        LendingProtocol p = new LendingProtocol(IERC20(address(t0)), IERC20(address(t1)));

        address T = (idx == 0) ? address(p.tok0()) : address(p.tok1());
        IERC20 tokenT = IERC20(T);

        // 4. Setup initial balances
        t0.mint(userA, 1_000_000);
        t1.mint(userA, 1_000_000);
        
        vm.prank(userA);
        t0.approve(address(p), 1_000_000);
        vm.prank(userA);
        t1.approve(address(p), 1_000_000);

        vm.prank(userA); 
        p.deposit(500_000, address(p.tok0()));
        vm.prank(userA); 
        p.deposit(500_000, address(p.tok1()));

        vm.assume(tokenT.balanceOf(address(p)) >= amt);

        uint256 protoBalBefore = tokenT.balanceOf(address(p));
        uint256 userBalBefore = tokenT.balanceOf(userA);

        vm.prank(userA);
        p.borrow(amt, T);

        // (1) The T balance of the LendingProtocol is decreased by amt
        assert(protoBalBefore - tokenT.balanceOf(address(p)) == amt);
        
        // (2) The T balance of A is incremented by amt
        assert(tokenT.balanceOf(userA) - userBalBefore == amt);
    }
}