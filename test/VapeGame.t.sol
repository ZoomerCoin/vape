// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {VapeGame} from "../src/VapeGame.sol";

contract VapeGameTest is Test {
    VapeGame vape;

    function setUp() public {
        vape = new VapeGame();
        vape.startGame();
    }

    function test_takeAVapeHit_failsIfBelowMinInvest() public {
        vm.expectRevert("ETH value below min invest");
        vape.takeAVapeHit{value: 0.0066 ether}();
    }

    function test_takeAVapeHit_failsIfTimePassed() public {
        vm.warp(block.timestamp + 86401);
        vm.expectRevert("Time is over, pot can be claimed by winner.");
        vape.takeAVapeHit{value: 0.0067 ether}();
    }

    function test_takeAVapeHit_works() public {
        for (uint256 i = 1; i <= 10; i++) {
            vm.prank(vm.addr(i));
            vm.deal(vm.addr(i), 1 ether);
            vape.takeAVapeHit{value: 0.0067 ether + (0.0067 ether * i)}();
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
