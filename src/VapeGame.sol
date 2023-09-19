// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/ERC20.sol";
import "@chainlink/shared/access/ConfirmedOwner.sol";
import "@chainlink/vrf/VRFV2WrapperConsumerBase.sol";

contract VapeGame is ERC20, VRFV2WrapperConsumerBase, ConfirmedOwner {
    mapping(address => uint256) paidDividends;

    uint256 public immutable MIN_INVEST_TICK = 0.001 ether;

    uint256 public devFund = 200 ether; //dev fund value = 200vape
    uint256 public potValueETH = 0;
    uint256 public lottoValueETH = 0;
    uint256 public totalDividendsValueETH = 0;
    uint256 public finalPotValueETH = 0;
    uint256 public finalLottoValueETH = 0;

    uint256 public collectedFee = 0; //accumulated eth fee
    uint256 public minInvest = 0.01 ether;
    uint256 public vapeTokenPrice = 0.01 ether;

    uint256 public lastPurchasedTime;
    address payable public lastPurchasedAddress;
    mapping(uint256 => address) public hitters;

    ERC20 public zoomer;
    uint256 public numHits = 0;
    uint256 public immutable ZOOMER_HITS = 50;
    uint256 public immutable MIN_ZOOMER = 10000 ether;
    uint256 public immutable GAME_TIME;

    uint32 callbackGasLimit = 100000;
    uint32 numWords = 1;
    uint16 requestConfirmations = 3;
    address public linkAddress;

    bool public isPaused = true;

    event TookAHit(address indexed user, uint256 amount, uint256 vapeTokenValue);
    event GotDividend(address indexed user, uint256 amount);
    event TookTheLastHit(address indexed user, uint256 amount);
    event LottoWon(address indexed user, uint256 amount);

    modifier notPaused() {
        require(!isPaused, "Contract is paused.");
        _;
    }

    constructor(uint256 _gameTime, address _zoomer, address _linkAddress, address _vrfV2Wrapper)
        ERC20("Vape", "VAPE")
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(_linkAddress, _vrfV2Wrapper)
    {
        GAME_TIME = _gameTime;
        zoomer = ERC20(_zoomer);
        lastPurchasedTime = block.timestamp;
        linkAddress = _linkAddress;
        _mint(owner(), devFund);
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

        hitters[numHits] = msg.sender;
        numHits++;

        uint256 amount = (msg.value * 90000) / 100000; // 10% removed: 5% for random winner, 5% for dev fund
        uint256 lotto = (msg.value - amount) / 2;
        uint256 fee = msg.value - amount - lotto;

        collectedFee += fee;
        lottoValueETH += lotto;
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
        payable(owner()).transfer(collectedFee);
        collectedFee = 0;
    }

    function takeTheLastHit() public notPaused {
        require((block.timestamp >= lastPurchasedTime), "No.");
        require((block.timestamp - lastPurchasedTime) > GAME_TIME, "Time is not over yet, countdown still running.");
        lastPurchasedAddress.transfer(potValueETH);
        emit TookTheLastHit(lastPurchasedAddress, potValueETH);
        finalPotValueETH = potValueETH;
        potValueETH = 0;
        isPaused = true;
        requestRandomness(callbackGasLimit, requestConfirmations, numWords);
    }

    function fulfillRandomWords(uint256, /*_requestId*/ uint256[] memory _randomWords) internal override {
        uint256 randomnumber = _randomWords[0] % numHits;
        address winner = hitters[randomnumber];
        payable(winner).transfer(lottoValueETH);
        emit LottoWon(winner, lottoValueETH);
        finalLottoValueETH = lottoValueETH;
        lottoValueETH = 0;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require((msg.sender == owner() || from == address(0)), "You are not the owner, only owner can transfer tokens.");
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }
}
