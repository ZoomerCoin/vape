// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

import {VapeGame} from "../src/VapeGame.sol";

contract TestZoomer is ERC20 {
    constructor() ERC20("ZoomerCoin", "ZOOMER") {
        _mint(msg.sender, 69000000000 ether);
    }
}

contract VapeGameTest is Test {
    VapeGame vape;
    TestZoomer zoomer;
    address ALICE = address(1);
    address BOB = address(2);

    function setUp() public {
        vm.deal(ALICE, 1 ether);
        vm.deal(BOB, 1 ether);
        zoomer = new TestZoomer();
        zoomer.transfer(ALICE, 10000 ether);
        vape = new VapeGame(address(zoomer));
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
        for (uint256 i = 1; i <= 10; i++) {
            zoomer.transfer(vm.addr(i), 10000 ether);
            uint256 min = vape.minInvest();
            vm.deal(vm.addr(i), 1 ether);
            vm.prank(vm.addr(i));
            vape.takeAVapeHit{value: min}();
            emit log_named_uint("getMyDividend", vape.getMyDividend(vm.addr(i)));
        }
        emit log_named_uint("balance", address(vape).balance);
        emit log_named_uint("potValueETH", vape.potValueETH());
        emit log_named_uint("totalDividendsValueETH", vape.totalDividendsValueETH());
        emit log_named_uint("collectedFee", vape.collectedFee());
        emit log_named_uint("minInvest", vape.minInvest());
        emit log_named_uint("vapeTokenPrice", vape.vapeTokenPrice());
        emit log_named_uint("lastPurchasedTime", vape.lastPurchasedTime());
        emit log_named_address("lastPurchasedAddress", vape.lastPurchasedAddress());
        emit log_named_uint("vapeBalance", vape.balanceOf(address(this)));
    }
}
