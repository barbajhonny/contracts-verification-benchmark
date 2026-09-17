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

    /// @notice Helper to handle mint, approve, and deposit cleanly
    function _deposit(
        LendingProtocol protocol,
        address userA,
        uint256 amount,
        address tokenAddr
    ) internal {
        MockERC20 mockT = MockERC20(tokenAddr);
        mockT.mint(userA, amount);
        vm.prank(userA);
        mockT.approve(address(protocol), amount);
        vm.prank(userA);
        protocol.deposit(amount, tokenAddr);
    }

    /// @notice Property: rdm-tokens
    function check_rdm_tokens(
        address userA,
        uint256 depositAmt,
        uint256 redeemAmt,
        uint256 idx
    ) public {
        vm.assume(userA != address(0));

        // Initialize protocol and tokens
        MockERC20 tok0 = new MockERC20();
        MockERC20 tok1 = new MockERC20();
        LendingProtocol protocol = new LendingProtocol(IERC20(address(tok0)), IERC20(address(tok1)));

        address T = (idx == 0) ? address(protocol.tok0()) : address(protocol.tok1());
        MockERC20 mockT = MockERC20(T);

        _deposit(protocol, userA, depositAmt, T);

        uint256 xrBefore = protocol.XR(T);
        uint256 protocolBalanceBefore = mockT.balanceOf(address(protocol));
        uint256 userBalanceBefore = mockT.balanceOf(userA);

        vm.prank(userA);
        protocol.redeem(redeemAmt, T);
        
        uint256 protocolBalanceAfter = mockT.balanceOf(address(protocol));
        uint256 userBalanceAfter = mockT.balanceOf(userA);

        uint256 expectedTransferAmount = (redeemAmt * xrBefore) / 1e6;

        assert(protocolBalanceAfter == protocolBalanceBefore - expectedTransferAmount);

        assert(userBalanceAfter == userBalanceBefore + expectedTransferAmount);
        
    }
}