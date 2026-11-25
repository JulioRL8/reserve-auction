// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

contract ReserveAuction {
    error InvalidConfiguration();
    error AuctionClosed();
    error BidTooLow();
    error AuctionOpen();
    error AlreadySettled();
    error NothingToWithdraw();
    error InvalidRecipient();
    error TransferFailed();

    address public immutable seller;
    bytes32 public immutable lot;
    uint256 public immutable reserve;
    uint256 public immutable closesAt;
    address public winner;
    uint256 public winningBid;
    bool public settled;

    mapping(address account => uint256) public credit;

    event BidPlaced(address indexed bidder, uint256 amount);
    event Settled(address indexed winner, uint256 amount);
    event Withdrawn(address indexed account, address indexed recipient, uint256 amount);

    constructor(bytes32 lotDigest, uint256 minimumBid, uint64 duration) {
        if (lotDigest == bytes32(0)) revert InvalidConfiguration();
        if (minimumBid == 0) revert InvalidConfiguration();
        if (duration == 0) revert InvalidConfiguration();
        seller = msg.sender;
        lot = lotDigest;
        reserve = minimumBid;
        closesAt = block.timestamp + duration;
    }

    function bid() external payable {
        if (block.timestamp >= closesAt) revert AuctionClosed();
        if (msg.value < reserve) revert BidTooLow();
        if (msg.value <= winningBid) revert BidTooLow();
        if (winningBid != 0) credit[winner] += winningBid;

        winner = msg.sender;
        winningBid = msg.value;
        emit BidPlaced(msg.sender, msg.value);
    }

    function settle() external {
        if (block.timestamp < closesAt) revert AuctionOpen();
        if (settled) revert AlreadySettled();

        settled = true;
        if (winningBid != 0) credit[seller] += winningBid;
        emit Settled(winner, winningBid);
    }

    function withdraw(address payable recipient) external {
        if (recipient == address(0)) revert InvalidRecipient();
        uint256 amount = credit[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        credit[msg.sender] = 0;
        emit Withdrawn(msg.sender, recipient, amount);
        (bool sent,) = recipient.call{value: amount}("");
        if (!sent) revert TransferFailed();
    }
}
