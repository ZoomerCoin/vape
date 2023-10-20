// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "@chainlink/interfaces/VRFV2WrapperInterface.sol";
import "forge-std/StdUtils.sol";

import {VapeGame} from "../src/VapeGame.sol";

contract VapeGameForkTest is Test {
    uint256 mainnetFork;

    VapeGame vape;
    ERC20 zoomer = ERC20(0x0D505C03d30e65f6e9b4Ef88855a47a89e4b7676);
    ERC20 link = ERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    address ALICE = address(42);
    address ZOOMER_WHALE = 0x5A9e792143bf2708b4765C144451dCa54f559a19;
    address ZOOMER_OWNER = 0xFaDede2cFbfA7443497acacf76cFc4Fe59112DbB;

    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL, 18391633);
        address[] memory nfts = new address[](2);
        nfts[0] = 0xB852c6b5892256C264Cc2C888eA462189154D8d7;
        nfts[1] = 0xFF72F37aA4EAe3B7e1752e25DB85b209f12c1A33;
        vm.prank(ZOOMER_OWNER);
        vape =
        new VapeGame(86400, 0x0D505C03d30e65f6e9b4Ef88855a47a89e4b7676, nfts, 0x514910771AF9Ca656af840dff83E8264EcF986CA, 0x5A861794B927983406fCE1D062e00b9368d97Df6);
        vm.deal(ALICE, 1 ether);
        uint256 minZoomer = vape.MIN_ZOOMER();
        vm.prank(ZOOMER_WHALE);
        link.transfer(address(vape), 2 ether);
        vm.prank(ZOOMER_WHALE);
        zoomer.transfer(ALICE, minZoomer);
        assertEq(zoomer.balanceOf(ALICE), minZoomer);
        vm.prank(ZOOMER_OWNER);
        vape.startGame();
        assertEq(vape.isPaused(), false);
    }

    function test_hitAndEndGameWithDeploy() public {
        uint256 min = vape.minInvest();
        vm.prank(ALICE);
        vape.takeAVapeHit{value: min}();
        vm.warp(block.timestamp + vape.GAME_TIME() + 1);
        emit log_named_uint("balance", address(vape).balance);
        vm.prank(ALICE);
        vape.takeTheLastHit();
    }
}
