// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "openzeppelin/token/ERC20/ERC20.sol";

contract VapeToken is ERC20 {
    mapping(address => uint256) paidDividends;

    address payable owner;

    uint256 devFund = 200 ether; //dev fund value = 200vape
    uint256 potValueETH = 0;
    uint256 totalDividendsValueETH = 0;

    uint256 ethFee = 0; //accumulated eth fee
    uint256 minInvest = 6700000000000000; // 0.0067 ETH
    uint256 vapeTokenPrice = 6700000000000000; // 0.0067 ETH

    uint256 lastPurchasedTime;
    address payable lastPurchasedAddress;

    bool public isPaused = false;

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner.");
        _;
    }

    modifier notPaused() {
        require(!isPaused, "Contract is paused.");
        _;
    }

    constructor() ERC20("Vape", "VAPE") {
        owner = payable(msg.sender);
        lastPurchasedTime = block.timestamp;
        _mint(owner, devFund);
    }

    function addToPot() public payable notPaused {
        require(msg.value >= minInvest, "ETH value below min invest");
        require((block.timestamp - lastPurchasedTime) <= 86400, "Time is over, pot can be claimed by winner.");

        uint256 amount = (msg.value * 85000) / 100000; // 10% for stakers and 5% for fees = 85% for pot + dividend
        uint256 fee = msg.value - amount;
        ethFee += fee;
        potValueETH += amount / 2;
        totalDividendsValueETH += amount / 2;

        uint256 vapetokenvalue = (amount * 1e18) / vapeTokenPrice;

        lastPurchasedTime = block.timestamp;
        lastPurchasedAddress = payable(msg.sender);

        minInvest = minInvest + 1340000000000000; // 0.00134 ETH
        vapeTokenPrice = vapeTokenPrice + 670000000000000; // 0.0067 ETH

        _mint(msg.sender, vapetokenvalue);
    }

    function getMyDividend(address useraddress) public view returns (uint256) {
        uint256 userbalance = balanceOf(useraddress);

        uint256 share = (totalDividendsValueETH * userbalance) / totalSupply() - paidDividends[useraddress];
        return share;
    }

    function payMyDividend() public notPaused {
        require(getMyDividend(msg.sender) > 0, "No dividend for payout");
        uint256 remainingDividend = getMyDividend(msg.sender);
        paidDividends[msg.sender] += remainingDividend;
        payable(msg.sender).transfer(remainingDividend);
    }

    function paydDevFee() public notPaused {
        require(msg.sender == owner, "You are not the owner.");
        owner.transfer(ethFee);
        ethFee = 0;
    }

    function payPotToWinner() public notPaused {
        require((block.timestamp >= lastPurchasedTime), "No."); //86400
        require((block.timestamp - lastPurchasedTime) > 86400, "Time is not over yet, countdown still running.");
        lastPurchasedAddress.transfer(getETHPotValue());
        potValueETH = 0;
        isPaused = true;
    }

    function getvapeTokenPrice() public view returns (uint256) {
        return vapeTokenPrice;
    }

    function getMinInvest() public view returns (uint256) {
        return minInvest;
    }

    function getETHPotValue() public view returns (uint256) {
        return potValueETH;
    }

    function getEthFeesValue() public view returns (uint256) {
        return ethFee;
    }

    function getLastPurchasedTime() public view returns (uint256) {
        return lastPurchasedTime;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require((msg.sender == owner || from == address(0)), "You are not the owner, only owner can transfer tokens.");
    }
}
