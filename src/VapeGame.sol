// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/ERC20.sol";

contract VapeGame is ERC20 {
    mapping(address => uint256) paidDividends;

    address payable public owner;

    uint256 public immutable MIN_INVEST_TICK = 0.001 ether;

    uint256 public devFund = 200 ether; //dev fund value = 200vape
    uint256 public potValueETH = 0;
    uint256 public totalDividendsValueETH = 0;

    uint256 public collectedFee = 0; //accumulated eth fee
    uint256 public minInvest = 0.01 ether;
    uint256 public vapeTokenPrice = 0.01 ether;

    uint256 public lastPurchasedTime;
    address payable public lastPurchasedAddress;

    ERC20 public zoomer;
    uint256 public numHits = 0;
    uint256 public immutable ZOOMER_HITS = 50;
    uint256 public immutable MIN_ZOOMER = 10000 ether;
    uint256 public immutable GAME_TIME = 24 hours;

    bool public isPaused = true;

    event TookAHit(address indexed user, uint256 amount, uint256 vapeTokenValue);
    event GotDividend(address indexed user, uint256 amount);
    event TookTheLastHit(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner.");
        _;
    }

    modifier notPaused() {
        require(!isPaused, "Contract is paused.");
        _;
    }

    constructor(address _zoomer) ERC20("Vape", "VAPE") {
        owner = payable(msg.sender);
        zoomer = ERC20(_zoomer);
        lastPurchasedTime = block.timestamp;
        _mint(owner, devFund);
    }

    function startGame() public onlyOwner {
        isPaused = false;
        lastPurchasedTime = block.timestamp;
    }

    function hasEnoughZoomer(address user) public view returns (bool) {
        return zoomer.balanceOf(user) >= MIN_ZOOMER;
    }

    function takeAVapeHit() public payable notPaused {
        require(msg.value >= minInvest, "ETH value below min invest");
        require((block.timestamp - lastPurchasedTime) <= GAME_TIME, "Time is over, pot can be claimed by winner.");
        if (numHits < ZOOMER_HITS) {
            require(hasEnoughZoomer(msg.sender), "You need at least 10k ZOOMER to play the game.");
        }

        numHits++;

        uint256 amount = (msg.value * 95000) / 100000; // 5% fee
        uint256 fee = msg.value - amount;

        collectedFee += fee;
        potValueETH += amount / 2;
        totalDividendsValueETH += amount / 2;

        uint256 vapetokenvalue = (amount * 1e18) / vapeTokenPrice;

        lastPurchasedTime = block.timestamp;
        lastPurchasedAddress = payable(msg.sender);

        minInvest = minInvest + MIN_INVEST_TICK;
        vapeTokenPrice = vapeTokenPrice + MIN_INVEST_TICK;

        _mint(msg.sender, vapetokenvalue);
        emit TookAHit(msg.sender, amount, vapetokenvalue);
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
        emit GotDividend(msg.sender, remainingDividend);
    }

    function paydDevFee() public onlyOwner {
        owner.transfer(collectedFee);
        collectedFee = 0;
    }

    function takeTheLastHit() public notPaused {
        require((block.timestamp >= lastPurchasedTime), "No.");
        require((block.timestamp - lastPurchasedTime) > GAME_TIME, "Time is not over yet, countdown still running.");
        lastPurchasedAddress.transfer(potValueETH);
        potValueETH = 0;
        isPaused = true;
        emit TookTheLastHit(msg.sender, potValueETH);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require((msg.sender == owner || from == address(0)), "You are not the owner, only owner can transfer tokens.");
    }
}
