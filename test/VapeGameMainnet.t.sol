// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "@chainlink/interfaces/VRFV2WrapperInterface.sol";
import "forge-std/StdUtils.sol";

import {VapeGame} from "../src/VapeGame.sol";

contract VapeGameForkTest is Test {
    uint256 mainnetFork;

    VapeGame vape = VapeGame(payable(0x0D6dC2a36C5c3EbD6F9B67Afd18b31C0074089E5));
    ERC20 zoomer = ERC20(0x0D505C03d30e65f6e9b4Ef88855a47a89e4b7676);
    address ALICE = address(42);
    address ZOOMER_WHALE = 0x5A9e792143bf2708b4765C144451dCa54f559a19;
    address ZOOMER_OWNER = 0xFaDede2cFbfA7443497acacf76cFc4Fe59112DbB;

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL, 18391633);
        vm.deal(ALICE, 1 ether);
        uint256 minZoomer = vape.MIN_ZOOMER();
        vm.prank(ZOOMER_WHALE);
        zoomer.transfer(ALICE, minZoomer);
        assertEq(zoomer.balanceOf(ALICE), minZoomer);
        vm.prank(ZOOMER_OWNER);
        vape.startGame();
        assertEq(vape.isPaused(), false);
    }

    function test_hitAndEndGame() public {
        uint256 min = vape.minInvest();
        vm.prank(ALICE);
        vape.takeAVapeHit{value: min}();
        vm.warp(block.timestamp + vape.GAME_TIME() + 1);
        vm.prank(ALICE);
        vape.takeTheLastHit();
    }
}
