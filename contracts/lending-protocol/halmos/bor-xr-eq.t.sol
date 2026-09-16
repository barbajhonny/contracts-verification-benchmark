// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.2;

import "target/{{VERSION}}.sol";

interface IHalmosVM {
    function assume(bool condition) external;
    function prank(address msgSender) external;
}

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 amount) external { balanceOf[to] += amount; }
    function transfer(address to, uint256 amount) external returns (bool) { return true; }
    function transferFrom(address f, address t, uint256 a) external returns (bool) { return true; }
    function approve(address s, uint256 a) external returns (bool) { return true; }
}

contract LendingProtocolTest {
    IHalmosVM constant vm = IHalmosVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @notice Property: bor-xr-eq
    function check_bor_xr_eq(address userA, uint256 amt, uint256 idx) public {
       
        vm.assume(userA != address(0));

        MockERC20 t0 = new MockERC20();
        MockERC20 t1 = new MockERC20();
        LendingProtocol p = new LendingProtocol(IERC20(address(t0)), IERC20(address(t1)));

        address T = (idx == 0) ? address(p.tok0()) : address(p.tok1());
        address O = (idx == 0) ? address(p.tok1()) : address(p.tok0());

        // Setup initial balances 
        t0.mint(userA, 1_000_000);
        t1.mint(userA, 1_000_000);
        vm.prank(userA); 
        p.deposit(500_000, address(p.tok0()));
        vm.prank(userA); 
        p.deposit(500_000, address(p.tok1()));

        vm.assume(p.reserves(T) >= amt);

        uint256 xrT_before = p.XR(T);
        uint256 xrO_before = p.XR(O);

        vm.prank(userA);
        p.borrow(amt, T);

        assert(p.XR(T) == xrT_before);
        assert(p.XR(O) == xrO_before);
    }
}