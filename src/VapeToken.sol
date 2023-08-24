// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/ERC20.sol";

contract VapeToken is ERC20 {
    mapping(address => uint256) paidDividends;

    address payable owner;
    address payable public rewardsContract;

    uint256 immutable public MIN_INVEST_TICK = 0.00067 ether;

    uint256 public devFund = 200 ether; //dev fund value = 200vape
    uint256 public potValueETH = 0;
    uint256 public totalDividendsValueETH = 0;

    uint256 public collectedFee = 0; //accumulated eth fee
    uint256 public minInvest = 0.00067 ether;
    uint256 public vapeTokenPrice = 0.00067 ether;

    uint256 public lastPurchasedTime;
    address payable public lastPurchasedAddress;

    bool public isPaused = false;

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner.");
        _;
    }

    modifier notPaused() {
        require(!isPaused, "Contract is paused.");
        _;
    }

    constructor(address _rewardsContract) ERC20("Vape", "VAPE") {
        owner = payable(msg.sender);
        lastPurchasedTime = block.timestamp;
        _mint(owner, devFund);
        rewardsContract = payable(_rewardsContract);
    }

    function pause() public onlyOwner {
        isPaused = true;
    }

    function unpause() public onlyOwner {
        isPaused = false;
    }

    function takeAVapeHit() public payable notPaused {
        require(msg.value >= minInvest, "ETH value below min invest");
        require((block.timestamp - lastPurchasedTime) <= 86400, "Time is over, pot can be claimed by winner.");

        uint256 amount = (msg.value * 85000) / 100000; // 10% for stakers and 5% for fees = 85% for pot + dividend
        uint256 rewards = (msg.value * 10000) / 100000; // 10% for stakers
        uint256 fee = msg.value - (amount + rewards);

        // rewardsContract.transfer(rewards); // 10% for stakers transferred to rewards contract

        collectedFee += fee;
        potValueETH += amount / 2;
        totalDividendsValueETH += amount / 2;

        uint256 vapetokenvalue = (amount * 1e18) / vapeTokenPrice;

        lastPurchasedTime = block.timestamp;
        lastPurchasedAddress = payable(msg.sender);

        minInvest = minInvest + (MIN_INVEST_TICK * 2);
        vapeTokenPrice = vapeTokenPrice + MIN_INVEST_TICK;

        _mint(msg.sender, vapetokenvalue);
    }

    function getMyDividend(address useraddress) public view returns (uint256) {
        uint256 userbalance = balanceOf(useraddress);

        uint256 share = (totalDividendsValueETH * userbalance) / totalSupply() - paidDividends[useraddress];
        return share;
    }

    function payMyDividend() public {
        require(getMyDividend(msg.sender) > 0, "No dividend for payout");
        uint256 remainingDividend = getMyDividend(msg.sender);
        paidDividends[msg.sender] += remainingDividend;
        payable(msg.sender).transfer(remainingDividend);
    }

    function paydDevFee() public onlyOwner {
        owner.transfer(collectedFee);
        collectedFee = 0;
    }

    function takeTheLastHit() public notPaused {
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
        return collectedFee;
    }

    function getLastPurchasedTime() public view returns (uint256) {
        return lastPurchasedTime;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require((msg.sender == owner || from == address(0)), "You are not the owner, only owner can transfer tokens.");
    }
}
