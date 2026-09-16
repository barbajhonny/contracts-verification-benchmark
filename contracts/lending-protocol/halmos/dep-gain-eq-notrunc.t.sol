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

    /// @notice Helper function defined inside the test contract to compute userA's net worth 
    /// and prevent "Stack too deep" compiler errors.
    function _getNetWorth(
        LendingProtocol protocol,
        MockERC20 t0,
        MockERC20 t1,
        address userA,
        uint256 price0,
        uint256 price1
    ) internal view returns (uint256) {
        address tok0Addr = address(protocol.tok0());
        address tok1Addr = address(protocol.tok1());

        return 
            (t0.balanceOf(userA) * price0) +
            (t1.balanceOf(userA) * price1) +
            (protocol.credit(tok0Addr, userA) * price0 * protocol.XR(tok0Addr) / 1e6) +
            (protocol.credit(tok1Addr, userA) * price1 * protocol.XR(tok1Addr) / 1e6) -
            (protocol.debit(tok0Addr, userA) * price0) -
            (protocol.debit(tok1Addr, userA) * price1);
    }

    /// @notice Property: dep-gain-eq-notrunc
    function check_dep_gain_eq_notrunc(
        address userA, 
        uint256 amt, 
        uint256 idx, 
        uint256 price0, 
        uint256 price1
    ) public {

        vm.assume(userA != address(0));
        
        MockERC20 t0 = new MockERC20();
        MockERC20 t1 = new MockERC20();
        LendingProtocol protocol = new LendingProtocol(IERC20(address(t0)), IERC20(address(t1)));

        address T = (idx == 0) ? address(protocol.tok0()) : address(protocol.tok1());

        // Assume exact arithmetic
        vm.assume((amt * 1e6) % protocol.XR(T) == 0);

        t0.mint(userA, 100_000);
        t1.mint(userA, 100_000);

        vm.prank(userA);
        t0.approve(address(protocol), 100_000);
        vm.prank(userA);
        t1.approve(address(protocol), 100_000);

        uint256 netWorthBefore = _getNetWorth(protocol, t0, t1, userA, price0, price1);

        vm.prank(userA);
        protocol.deposit(amt, T);

        uint256 netWorthAfter = _getNetWorth(protocol, t0, t1, userA, price0, price1);

        assert(netWorthBefore == netWorthAfter);
    }
}