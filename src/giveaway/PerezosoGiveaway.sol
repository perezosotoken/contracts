
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PerezosoGiveaway is ReentrancyGuard {
    enum GiveawayState {
        active,
        inactive
    }

    IERC20 private _token;
    
    uint256 public maxTicket;
    uint256 public ENTRY_FEE;
    uint256 public PRIZE;
    address[] public currentPlayers;
    uint256 public giveawayCount = 0;
    address[] winners;
    address public owner;
    address public recievingWallet;
    uint256 public hour;
    uint256 public minute;
    uint256 public totalRewardDistributed;

    Leaderboard[] public leaderboard;

    struct Leaderboard {
        address winner;
        uint256 prize;
        uint256 timestamp;
    }

    GiveawayState public giveaway_state = GiveawayState.active;

    constructor(
        IERC20 _tokenContract,
        address _recievingWallet,
        uint256 _entryfee,
        uint256 _prize,
        uint256 _hour,
        uint256 _minutes,
        uint256 _maxTicket
    ) {
        _token = _tokenContract;
        owner = msg.sender;
        recievingWallet = _recievingWallet;
        ENTRY_FEE = _entryfee;
        PRIZE = _prize;
        hour = _hour;
        minute = _minutes;
        maxTicket = _maxTicket;
    }

    modifier toBeInState(GiveawayState status) {
        require(giveaway_state == status, "Not in needed state");
        _;
    }

    modifier onlyAtGiveAwayTime() {
        require(
            (block.timestamp % 86400) / 3600 == hour &&
                ((block.timestamp % 3600) / 60) == minute,
            "Can not execute at this time"
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function setPayoutTime(uint256 _hour, uint256 _minute) public onlyOwner {
        hour = _hour;
        minute = _minute;
    }

    function EnterGiveaway(uint256 _tickets)
        public
        toBeInState(GiveawayState.active)
        nonReentrant
    {
        require(
            _tickets <= maxTicket,
            "Ticket entered is above maximum ticket"
        );
        uint256 priceToPay = _tickets * (ENTRY_FEE * (10**18));
        require(
            priceToPay <= _token.balanceOf(msg.sender),
            "Your balance is not enough!"
        );
        for (uint256 i = 0; i < _tickets; i++) {
            currentPlayers.push(msg.sender);
        }
        _token.transferFrom(msg.sender, recievingWallet, priceToPay);
    }

    function getWinner()
        external
        onlyAtGiveAwayTime
        nonReentrant
        returns (address)
    {
        require(currentPlayers.length != 0, "No players available");

        uint256 randomNumber = generateUniqueNumber() % currentPlayers.length;
        address winner = currentPlayers[randomNumber];

        bool success = _token.transfer(winner, (PRIZE * (10**18)));
        require(success, "Prize transfer failed");
        winners.push(winner);
        delete currentPlayers;
        giveawayCount += 1;
        totalRewardDistributed += PRIZE;
        Leaderboard memory newEntry = Leaderboard(
            winner,
            PRIZE,
            block.timestamp
        );
        leaderboard.push(newEntry);
        return winner;
    }

    function setGiveawayState(GiveawayState state) public onlyOwner {
        giveaway_state = state;
    }

    function setRecievingWallet(address _wallet) public onlyOwner {
        recievingWallet = _wallet;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    function setEntryFee(uint256 entryfee) public onlyOwner {
        ENTRY_FEE = entryfee;
    }

    function setMaxTicket(uint256 _maxTicket) public onlyOwner {
        maxTicket = _maxTicket;
    }

    function setPrize(uint256 _prize) public onlyOwner {
        PRIZE = _prize;
    }

    function generateUniqueNumber() private view returns (uint256) {
        uint256 uniqueNumber = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    currentPlayers.length,
                    msg.sender
                )
            )
        );
        return uniqueNumber;
    }

    function getCurrentPlayers() public view returns (address[] memory) {
        return currentPlayers;
    }

    function getCurrentGiveawayCount() public view returns (uint256) {
        return giveawayCount;
    }

    function getAllWiners() public view returns (address[] memory) {
        return winners;
    }

     function getLeaderboard() public view returns (Leaderboard[] memory) {
        return leaderboard;
    }

    function getMaxTicket() public view returns (uint256) {
        return maxTicket;
    }

    function getIERC20Token() public view returns (IERC20) {
        return _token;
    }

    function updateERC20Token(IERC20 _tokenContract) public onlyOwner {
        _token = _tokenContract;
    }

    function withdrawERC20Token(address _to) public onlyOwner {
        _token.transfer(_to, _token.balanceOf(address(this)));
    }
}