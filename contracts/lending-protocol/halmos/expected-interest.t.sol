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

    /// @notice Helper function to handle deposit setup and avoid stack-too-deep
    function _setupDeposit(
        LendingProtocol protocol,
        address userA,
        uint256 depositAmt,
        address tokenAddr
    ) internal {
        MockERC20 mockT = MockERC20(tokenAddr);
        mockT.mint(userA, depositAmt);
        vm.prank(userA);
        mockT.approve(address(protocol), depositAmt);
        vm.prank(userA);
        protocol.deposit(depositAmt, tokenAddr);
    }

    /// @notice Property: expected-interest failure in buggy version
    /// Protocol A: user borrows amt1 on tok0 (1 borrower in array).
    /// Protocol B: user borrows amt1 on tok0 AND amt2 on tok1
    function check_expected_interest_bug(
        address userA, 
        uint256 depositAmt, 
        uint256 amt1, 
        uint256 amt2
    ) public {

        vm.assume(userA != address(0));

        // Initialize protocol A and protocol B
        MockERC20 tok0A = new MockERC20();
        MockERC20 tok1A = new MockERC20();
        LendingProtocol protocolA = new LendingProtocol(IERC20(address(tok0A)), IERC20(address(tok1A)));

        MockERC20 tok0B = new MockERC20();
        MockERC20 tok1B = new MockERC20();
        LendingProtocol protocolB = new LendingProtocol(IERC20(address(tok0B)), IERC20(address(tok1B)));

        address t0A = address(protocolA.tok0());
        address t1A = address(protocolA.tok1());
        address t0B = address(protocolB.tok0());
        address t1B = address(protocolB.tok1());

        _setupDeposit(protocolA, userA, depositAmt, t0A);
        _setupDeposit(protocolA, userA, depositAmt, t1A);

        _setupDeposit(protocolB, userA, depositAmt, t0B);
        _setupDeposit(protocolB, userA, depositAmt, t1B);

        // Protocol A: User borrows amt1 on tok0A (borrowers array length becomes 1)
        vm.prank(userA);
        protocolA.borrow(amt1, t0A);

        // Protocol B: User borrows amt1 on tok0B (borrowers length = 1) 
        // and then borrows amt2 on tok1B (borrowers length becomes 2 )
        vm.prank(userA);
        protocolB.borrow(amt1, t0B);
        vm.prank(userA);
        protocolB.borrow(amt2, t1B);

        // Trigger interest accrual on both protocols
        protocolA.accrueInt();
        protocolB.accrueInt();

        // Calculate interest accrued specifically on tok0 for both protocols
        uint256 interestA = protocolA.getUpdatedSumDebits(t0A) - amt1;
        uint256 interestB = protocolB.getUpdatedSumDebits(t0B) - amt1;

        assert(interestA == interestB);
    }
}