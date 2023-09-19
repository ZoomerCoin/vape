// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "@chainlink/interfaces/VRFV2WrapperInterface.sol";

import {VapeGame} from "../src/VapeGame.sol";

contract TestZoomer is ERC20 {
    constructor() ERC20("ZoomerCoin", "ZOOMER") {
        _mint(msg.sender, 69000000000 ether);
    }
}

contract TestLink is ERC20 {
    constructor() ERC20("ChainLink", "LINK") {
        _mint(msg.sender, 1000000000 ether);
    }

    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success) {
        return true;
    }
}

contract VapeGameTest is Test {
    VapeGame vape;
    TestZoomer zoomer;
    TestLink link;
    address ALICE = address(1);
    address BOB = address(2);
    address VRF_WRAPPER = address(3);

    function setUp() public {
        vm.deal(ALICE, 1 ether);
        vm.deal(BOB, 1 ether);
        zoomer = new TestZoomer();
        zoomer.transfer(ALICE, 10000 ether);
        link = new TestLink();
        vape = new VapeGame(24 hours, address(zoomer), address(link), VRF_WRAPPER);
        link.transfer(address(vape), 1000 ether);
        vape.startGame();
    }

    function test_takeAVapeHit_failsIfBelowMinInvest() public {
        uint256 min = vape.minInvest();
        vm.expectRevert("ETH value below min invest");
        vm.prank(ALICE);
        vape.takeAVapeHit{value: min - 1}();
    }

    function test_takeAVapeHit_failsIfTimePassed() public {
        vm.warp(block.timestamp + 86401);
        uint256 min = vape.minInvest();
        vm.expectRevert("Time is over, pot can be claimed by winner.");
        vm.prank(ALICE);
        vape.takeAVapeHit{value: min}();
    }

    function test_takeAVapeHit_failsIfBelowMinZoomer() public {
        zoomer.transfer(BOB, 9999 ether);
        uint256 min = vape.minInvest();
        vm.expectRevert("You need at least 10k ZOOMER to play the game.");
        vm.prank(BOB);
        vape.takeAVapeHit{value: min}();
    }

    function test_takeAVapeHit_works() public {
        uint256 min = vape.minInvest();
        assertEq(vape.balanceOf(ALICE), 0);
        vm.prank(ALICE);
        vape.takeAVapeHit{value: min}();
        assertEq(vape.balanceOf(ALICE) > 0, true);
    }

    function test_e2eWorks() public {
        vm.mockCall(
            VRF_WRAPPER,
            abi.encodeWithSelector(VRFV2WrapperInterface.calculateRequestPrice.selector),
            abi.encode(2 ether)
        );

        for (uint256 i = 1; i <= 10; i++) {
            zoomer.transfer(vm.addr(i), 10000 ether);
            uint256 min = vape.minInvest();
            vm.deal(vm.addr(i), 1 ether);
            vm.prank(vm.addr(i));
            vape.takeAVapeHit{value: min}();
            emit log_named_uint("getMyDividend", vape.getMyDividend(vm.addr(i)));
            assertEq(vape.getMyDividend(vm.addr(i)) > vape.getMyDividend(vm.addr(i + 1)), true);
        }

        uint256 before;
        for (uint256 i = 1; i <= 10; i++) {
            before = (vm.addr(i)).balance;
            vm.prank(vm.addr(i));
            vape.payMyDividend();
            assertEq((vm.addr(i)).balance > before, true);
        }
        // emit log_named_uint("balance", address(vape).balance);
        // emit log_named_uint("potValueETH", vape.potValueETH());
        // emit log_named_uint("totalDividendsValueETH", vape.totalDividendsValueETH());
        // emit log_named_uint("collectedFee", vape.collectedFee());
        // emit log_named_uint("minInvest", vape.minInvest());
        // emit log_named_uint("vapeTokenPrice", vape.vapeTokenPrice());
        // emit log_named_uint("lastPurchasedTime", vape.lastPurchasedTime());
        // emit log_named_address("lastPurchasedAddress", vape.lastPurchasedAddress());
        // emit log_named_uint("vapeBalance", vape.balanceOf(address(this)));

        vm.warp(block.timestamp + vape.GAME_TIME() + 1);

        emit log_named_uint("link balance", link.balanceOf(address(vape)));
        before = vm.addr(10).balance;
        vape.takeTheLastHit();
        assertEq(vm.addr(10).balance > before, true);
    }
}
