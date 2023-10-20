// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "@chainlink/interfaces/VRFV2WrapperInterface.sol";

import {VapeGame} from "../src/VapeGame.sol";
import {TestNFT} from "./TestNFT.sol";

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
    TestNFT nft;
    address ALICE = address(1);
    address BOB = address(2);
    address VRF_WRAPPER = address(3);
    uint256 MIN_ZOOMER = 10000000 ether;

    function setUp() public {
        vm.deal(ALICE, 1 ether);
        vm.deal(BOB, 1 ether);
        zoomer = new TestZoomer();
        zoomer.transfer(ALICE, MIN_ZOOMER);
        nft = new TestNFT();
        link = new TestLink();
        address[] memory nfts = new address[](1);
        nfts[0] = address(nft);
        vape = new VapeGame(24 hours, address(zoomer), nfts, address(link), VRF_WRAPPER);
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

    function test_takeAVapeHit_failsIfBelowMinZoomerAndNoNFT() public {
        zoomer.transfer(BOB, 9999 ether);
        uint256 min = vape.minInvest();
        vm.expectRevert("You need at least MIN_ZOOMER or a whitelisted NFT to play the game.");
        vm.prank(BOB);
        vape.takeAVapeHit{value: min}();
    }

    function test_takeAVapeHit_worksWithZoomer() public {
        uint256 min = vape.minInvest();
        assertEq(vape.balanceOf(ALICE), 0);
        vm.prank(ALICE);
        vape.takeAVapeHit{value: min}();
        assertEq(vape.balanceOf(ALICE) > 0, true);
    }

    function test_takeAVapeHit_worksWithNFT() public {
        uint256 min = vape.minInvest();
        nft.mint(BOB, 9);
        assertEq(vape.balanceOf(BOB), 0);
        vm.prank(BOB);
        vape.takeAVapeHit{value: min}();
        assertEq(vape.balanceOf(BOB) > 0, true);
    }

    function test_e2eWorks(uint256 randomWord) public {
        vm.mockCall(
            VRF_WRAPPER,
            abi.encodeWithSelector(VRFV2WrapperInterface.calculateRequestPrice.selector),
            abi.encode(2 ether)
        );

        for (uint256 i = 1; i <= 10; i++) {
            zoomer.transfer(vm.addr(i), MIN_ZOOMER);
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

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;
        vm.prank(VRF_WRAPPER);
        vape.rawFulfillRandomWords(0, randomWords);
    }
}
