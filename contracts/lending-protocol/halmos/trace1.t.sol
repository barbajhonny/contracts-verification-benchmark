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

    /// @notice Property: trace1
    function check_trace1(address userA, address userB) public {

        vm.assume(userA != address(0));
        vm.assume(userB != address(0));
        vm.assume(userA != userB);

        MockERC20 tok0 = new MockERC20();
        MockERC20 tok1 = new MockERC20();
        LendingProtocol protocol = new LendingProtocol(IERC20(address(tok0)), IERC20(address(tok1)));

        address T0 = address(protocol.tok0());
        address T1 = address(protocol.tok1());
        MockERC20 mockT0 = MockERC20(T0);
        MockERC20 mockT1 = MockERC20(T1);

        // Step 1: A deposits 50 units of T0
        mockT0.mint(userA, 50);
        vm.prank(userA);
        mockT0.approve(address(protocol), 50);
        vm.prank(userA);
        protocol.deposit(50, T0);

        // Step 2: B deposits 50 units of T1
        mockT1.mint(userB, 50);
        vm.prank(userB);
        mockT1.approve(address(protocol), 50);
        vm.prank(userB);
        protocol.deposit(50, T1);

        // Step 3: B borrows 30 units of T0
        vm.prank(userB);
        protocol.borrow(30, T0);

        // (1) Contract reserves: 20 units of T0, 50 units of T1
        assert(protocol.reserves(T0) == 20);
        assert(protocol.reserves(T1) == 50);

        // (2) User A state: 50 credits of T0, 0 debits
        assert(protocol.credit(T0, userA) == 50);
        assert(protocol.credit(T1, userA) == 0);
        assert(protocol.getAccruedDebt(T0, userA) == 0);
        assert(protocol.getAccruedDebt(T1, userA) == 0);

        // (3) User B state: 50 credits of T1, 30 debits of T0
        assert(protocol.credit(T1, userB) == 50);
        assert(protocol.credit(T0, userB) == 0);
        assert(protocol.getAccruedDebt(T0, userB) == 30);
        assert(protocol.getAccruedDebt(T1, userB) == 0);
    }
}