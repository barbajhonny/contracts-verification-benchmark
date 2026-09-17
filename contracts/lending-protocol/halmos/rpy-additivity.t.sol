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
        require(balanceOf[to] >= amount, "Insufficient balance");
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

    /// @notice Helper to handle deposit and borrow setup cleanly
    function _setupProtocolWithDebt(
        address userA,
        uint256 depositAmt,
        uint256 borrowAmt,
        uint256 idx
    ) internal returns (LendingProtocol protocol, address targetToken) {
        MockERC20 tok0 = new MockERC20();
        MockERC20 tok1 = new MockERC20();
        protocol = new LendingProtocol(IERC20(address(tok0)), IERC20(address(tok1)));

        targetToken = (idx == 0) ? address(protocol.tok0()) : address(protocol.tok1());
        MockERC20 mockT = MockERC20(targetToken);

        mockT.mint(userA, depositAmt);
        vm.prank(userA);
        mockT.approve(address(protocol), depositAmt);
        vm.prank(userA);
        protocol.deposit(depositAmt, targetToken);

        vm.prank(userA);
        protocol.borrow(borrowAmt, targetToken);
    }

    /// @notice Property: rpy-additivity
    function check_rpy_additivity(
        address userA,
        uint256 depositAmt,
        uint256 borrowAmt,
        uint256 n1,
        uint256 n2,
        uint256 idx
    ) public {
        vm.assume(userA != address(0));
        vm.assume(n1 + n2 <= borrowAmt);

        (LendingProtocol protocolA, address TA) = _setupProtocolWithDebt(userA, depositAmt, borrowAmt, idx);
        (LendingProtocol protocolB, address TB) = _setupProtocolWithDebt(userA, depositAmt, borrowAmt, idx);

        MockERC20 mockTA = MockERC20(TA);
        MockERC20 mockTB = MockERC20(TB);

        // Ensure userA has enough extra minted tokens to perform the repayments
        mockTA.mint(userA, n1 + n2);
        mockTB.mint(userA, n1 + n2);

        // Protocol A: Execute two consecutive repays of n1 and n2 units
        vm.prank(userA);
        mockTA.approve(address(protocolA), n1);
        vm.prank(userA);
        protocolA.repay(n1, TA);

        vm.prank(userA);
        mockTA.approve(address(protocolA), n2);
        vm.prank(userA);
        protocolA.repay(n2, TA);

        // Protocol B: Execute a single equivalent repay of n1 + n2 units
        vm.prank(userA);
        mockTB.approve(address(protocolB), n1 + n2);
        vm.prank(userA);
        protocolB.repay(n1 + n2, TB);

        assert(protocolA.getAccruedDebt(TA, userA) == protocolB.getAccruedDebt(TB, userA));
        assert(protocolA.reserves(TA) == protocolB.reserves(TB));
        assert(mockTA.balanceOf(userA) == mockTB.balanceOf(userA));
        assert(mockTA.balanceOf(address(protocolA)) == mockTB.balanceOf(address(protocolB)));
    }
}