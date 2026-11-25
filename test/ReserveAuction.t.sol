// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {ReserveAuction} from "../src/ReserveAuction.sol";
import {TestBase} from "./TestBase.sol";

contract ReserveAuctionTest is TestBase {
    ReserveAuction private auction;
    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);
    bytes32 private constant LOT = keccak256("lot-001");

    function setUp() public {
        auction = new ReserveAuction(LOT, 1 ether, 1 hours);
        vm.deal(ALICE, 10 ether);
        vm.deal(BOB, 10 ether);
    }

    function testRejectsEmptyLotDigest() public {
        vm.expectRevert(ReserveAuction.InvalidConfiguration.selector);
        new ReserveAuction(bytes32(0), 1, 1);
    }

    function testRejectsZeroReserve() public {
        vm.expectRevert(ReserveAuction.InvalidConfiguration.selector);
        new ReserveAuction(LOT, 0, 1);
    }

    function testRejectsZeroDuration() public {
        vm.expectRevert(ReserveAuction.InvalidConfiguration.selector);
        new ReserveAuction(LOT, 1, 0);
    }

    function testBiddingAndSettlement() public {
        vm.prank(ALICE);
        vm.expectRevert(ReserveAuction.BidTooLow.selector);
        auction.bid{value: 1 ether - 1}();
        vm.prank(ALICE);
        auction.bid{value: 1 ether}();
        vm.prank(BOB);
        vm.expectRevert(ReserveAuction.BidTooLow.selector);
        auction.bid{value: 1 ether}();
        vm.prank(BOB);
        auction.bid{value: 2 ether}();
        vm.prank(BOB);
        auction.bid{value: 3 ether}();
        assertEq(auction.credit(ALICE), 1 ether);
        assertEq(auction.credit(BOB), 2 ether);
        assertEq(auction.winner(), BOB);

        vm.prank(ALICE);
        auction.withdraw(payable(ALICE));
        assertEq(ALICE.balance, 10 ether);

        vm.expectRevert(ReserveAuction.AuctionOpen.selector);
        auction.settle();
        vm.warp(auction.closesAt());
        vm.prank(ALICE);
        vm.expectRevert(ReserveAuction.AuctionClosed.selector);
        auction.bid{value: 4 ether}();
        vm.prank(ALICE);
        auction.settle();
        assertEq(auction.credit(address(this)), 3 ether);
        vm.expectRevert(ReserveAuction.AlreadySettled.selector);
        auction.settle();
    }

    function testEmptyAuctionSettlesWithoutCredit() public {
        vm.warp(auction.closesAt());
        auction.settle();
        assertTrue(auction.settled());
        assertEq(auction.winner(), address(0));
        assertEq(auction.credit(address(this)), 0);
    }

    function testWithdrawalChecksAndRollback() public {
        vm.expectRevert(ReserveAuction.InvalidRecipient.selector);
        auction.withdraw(payable(address(0)));
        vm.expectRevert(ReserveAuction.NothingToWithdraw.selector);
        auction.withdraw(payable(ALICE));

        vm.prank(ALICE);
        auction.bid{value: 1 ether}();
        vm.warp(auction.closesAt());
        auction.settle();

        vm.expectRevert(ReserveAuction.TransferFailed.selector);
        auction.withdraw(payable(address(this)));
        assertEq(auction.credit(address(this)), 1 ether);
        auction.withdraw(payable(BOB));
        assertEq(auction.credit(address(this)), 0);
        assertEq(BOB.balance, 11 ether);
    }

    function testFuzzConservesBidFunds(uint96 rawFirst, uint96 rawIncrement) public {
        uint256 first = 1 ether + uint256(rawFirst);
        uint256 second = first + 1 + uint256(rawIncrement);
        vm.deal(ALICE, first);
        vm.deal(BOB, second);
        vm.prank(ALICE);
        auction.bid{value: first}();
        vm.prank(BOB);
        auction.bid{value: second}();

        vm.warp(auction.closesAt());
        auction.settle();
        assertEq(address(auction).balance, auction.credit(ALICE) + auction.credit(address(this)));
        assertEq(auction.credit(ALICE), first);
        assertEq(auction.credit(address(this)), second);
    }
}
