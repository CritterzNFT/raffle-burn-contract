// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./mock/CheatCodes.sol";
import "./mock/DummyERC721.sol";
import "./mock/DummyERC20.sol";
import "../src/RaffleBurn.sol";
import "forge-std/console.sol";

abstract contract RaffleBurnHelper is CheatCodesDSTest {
    RaffleBurn rb;

    DummyERC721 nft1;
    DummyERC721 nft2;
    DummyERC721 nft3;

    DummyERC20 t1;
    DummyERC20 t2;
    DummyERC20 t3;

    uint256 constant PRICE = 100e18;
    uint256 constant DURATION = 100;
    uint256 constant MAX_ALLOWANCE = 2**256 - 1;

    uint256 constant NFT1_MINTS = 3;
    uint256 constant NFT2_MINTS = 100;
    uint256 constant NFT3_MINTS = 0;
    uint256 constant T1_ISSUANCE = PRICE * type(uint96).max;
    uint256 constant T2_ISSUANCE = PRICE * 10;
    uint256 constant T3_ISSUANCE = 0;

    address a1 = 0x0000000000000000000000000000000000000001;
    address a2 = 0x0000000000000000000000000000000000000002;
    address a3 = 0x0000000000000000000000000000000000000003;
    address dead = address(0xdead);

    function setUp() public {
        nft1 = new DummyERC721();
        nft2 = new DummyERC721();
        nft3 = new DummyERC721();
        t1 = new DummyERC20();
        t2 = new DummyERC20();
        t3 = new DummyERC20();
        rb = new RaffleBurn();
        mintTokens();
    }

    function mintTokens() public {
        nft1.mint(address(this), NFT1_MINTS);
        nft1.mint(a1, NFT1_MINTS);
        nft1.mint(a2, NFT1_MINTS);
        nft1.mint(a3, NFT1_MINTS);
        nft2.mint(address(this), NFT2_MINTS);
        nft2.mint(a1, NFT2_MINTS);
        nft2.mint(a2, NFT2_MINTS);
        nft2.mint(a3, NFT2_MINTS);
        nft3.mint(address(this), NFT3_MINTS);
        nft3.mint(a1, NFT3_MINTS);
        nft3.mint(a2, NFT3_MINTS);
        nft3.mint(a3, NFT3_MINTS);
        t1.mint(address(this), T1_ISSUANCE);
        t1.mint(a1, T1_ISSUANCE);
        t1.mint(a2, T1_ISSUANCE);
        t1.mint(a3, T1_ISSUANCE);
        t2.mint(address(this), T2_ISSUANCE);
        t2.mint(a1, T2_ISSUANCE);
        t2.mint(a2, T2_ISSUANCE);
        t2.mint(a3, T2_ISSUANCE);
        t3.mint(address(this), T3_ISSUANCE);
        t3.mint(a1, T3_ISSUANCE);
        t3.mint(a2, T3_ISSUANCE);
        t3.mint(a3, T3_ISSUANCE);
    }

    function createDummyRaffle(address prizeToken, address paymentToken)
        public
        returns (uint256 raffleId)
    {
        DummyERC721(prizeToken).setApprovalForAll(address(rb), true);
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 0));
        raffleId = rb.createRaffle(
            prizeToken,
            tokenIds,
            paymentToken,
            uint48(block.timestamp),
            uint48(block.timestamp + DURATION),
            PRICE
        );
    }
}

contract CreateRaffleTest is RaffleBurnHelper {
    function testCreateRaffle() public {
        nft1.setApprovalForAll(address(rb), true);
        uint96[] memory tokenIds = new uint96[](2);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 2));
        tokenIds[1] = uint96(nft1.tokenOfOwnerByIndex(address(this), 1));
        uint256 raffleId = rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t1),
            uint48(block.timestamp),
            uint48(block.timestamp + 100),
            100e18
        );

        // check raffleId
        assertEq(raffleId, 0);

        // check raffle data
        (
            address paymentToken,
            uint96 seed,
            uint48 startTimestamp,
            uint48 endTimestamp,
            uint256 ticketPrice,
            bytes32 requestId
        ) = rb.raffles(raffleId);
        assertEq(paymentToken, address(t1));
        assertEq(seed, 0);
        assertEq(startTimestamp, uint48(block.timestamp));
        assertEq(endTimestamp, uint48(block.timestamp + 100));
        assertEq(ticketPrice, 100e18);
        assertEq(requestId, bytes32(0));

        for (uint96 i = 0; i < tokenIds.length; i++) {
            // prize token should be owned by contract
            assertEq(nft1.ownerOf(tokenIds[i]), address(rb));

            // check prize data
            (
                address tokenAddress,
                uint96 tokenId,
                address owner,
                bool claimed
            ) = rb.rafflePrizes(raffleId, i);
            assertEq(tokenAddress, address(nft1));
            assertEq(tokenId, tokenIds[i]);
            assertEq(owner, address(this));
            assertTrue(!claimed);
        }
    }

    function testRaffleIdIncrement() public {
        uint256 raffleId1 = createDummyRaffle(address(nft1), address(t1));
        uint256 raffleId2 = createDummyRaffle(address(nft2), address(t1));
        uint256 raffleId3 = createDummyRaffle(address(nft1), address(t1));
        assertEq(raffleId1, 0);
        assertEq(raffleId2, 1);
        assertEq(raffleId3, 2);
    }

    function testPrizeNotApproved() public {
        uint96[] memory tokenIds = new uint96[](2);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 2));
        tokenIds[1] = uint96(nft1.tokenOfOwnerByIndex(address(this), 1));
        cheats.expectRevert(
            bytes("ERC721: transfer caller is not owner nor approved")
        );
        rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t1),
            uint48(block.timestamp),
            uint48(block.timestamp + 100),
            100e18
        );
    }

    function testInvalidPrizeToken() public {
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 0));
        cheats.expectRevert(bytes("prizeToken cannot be null"));
        rb.createRaffle(
            address(0),
            tokenIds,
            address(t2),
            uint48(0),
            uint48(block.timestamp),
            100e18
        );
    }

    function testInvalidPaymentToken() public {
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 1));
        cheats.expectRevert(bytes("paymentToken cannot be null"));
        rb.createRaffle(
            address(nft3),
            tokenIds,
            address(0),
            uint48(0),
            uint48(block.timestamp),
            100e18
        );
    }

    function testInvalidEndTimestamp() public {
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 2));
        cheats.expectRevert(bytes("endTimestamp must be in the future"));
        rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t3),
            uint48(block.timestamp),
            uint48(block.timestamp),
            100e18
        );
    }

    function testInvalidTicketPrice() public {
        uint96[] memory tokenIds = new uint96[](1);
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 2));
        cheats.expectRevert(bytes("ticketPrice must be greater than 0"));
        rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t3),
            uint48(block.timestamp),
            uint48(block.timestamp + DURATION),
            0
        );
    }

    function testInvalidTokenIds() public {
        uint96[] memory tokenIds = new uint96[](3);
        // create with token not owned by creator
        tokenIds[0] = uint96(nft1.tokenOfOwnerByIndex(address(this), 2));
        tokenIds[1] = uint96(nft1.tokenOfOwnerByIndex(address(this), 1));
        tokenIds[2] = uint96(nft1.tokenOfOwnerByIndex(a1, 2));
        cheats.expectRevert(
            bytes("ERC721: transfer caller is not owner nor approved")
        );
        rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t3),
            uint48(block.timestamp),
            uint48(block.timestamp + DURATION),
            1e18
        );

        // create with duplicate tokens
        tokenIds[2] = uint96(nft1.tokenOfOwnerByIndex(address(this), 1));
        cheats.expectRevert(
            bytes("ERC721: transfer caller is not owner nor approved")
        );
        rb.createRaffle(
            address(nft1),
            tokenIds,
            address(t3),
            uint48(block.timestamp),
            uint48(block.timestamp + DURATION),
            1e18
        );
    }
}

contract BuyTicketsTest is RaffleBurnHelper {
    function testBuyTickets(uint256 allowance, uint96 ticketCount) public {
        cheats.assume(allowance >= ticketCount * PRICE);
        uint256 raffleId = createDummyRaffle(address(nft1), address(t1));
        t1.approve(address(rb), allowance);
        rb.buyTickets(raffleId, ticketCount);
        assertEq(t1.balanceOf(dead), PRICE * ticketCount);
    }

    function testCannotBuyTicketsAllowance(
        uint256 allowance,
        uint96 ticketCount
    ) public {
        cheats.assume(allowance < ticketCount * PRICE);
        uint256 raffleId = createDummyRaffle(address(nft1), address(t1));
        t1.approve(address(rb), allowance);
        cheats.expectRevert(bytes("ERC20: insufficient allowance"));
        rb.buyTickets(raffleId, ticketCount);
    }

    function testCannotBuyTicketsIssuance(uint96 ticketCount) public {
        // spend more than the issuance
        cheats.assume(T2_ISSUANCE < ticketCount * PRICE);
        uint256 raffleId = createDummyRaffle(address(nft1), address(t2));
        t2.approve(address(rb), MAX_ALLOWANCE);
        cheats.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        rb.buyTickets(raffleId, ticketCount);
    }
}

contract InitializeSeedTest is RaffleBurnHelper {
    function testInitializeSeed() public {
        uint256 raffleId = createDummyRaffle(address(nft1), address(t1));
        t1.approve(address(rb), MAX_ALLOWANCE);
        cheats.warp(block.timestamp + DURATION + 1);
        rb.initializeSeed(raffleId);
    }

    function testCannotInitializeSeed() public {
        uint256 raffleId = createDummyRaffle(address(nft1), address(t1));
        t1.approve(address(rb), MAX_ALLOWANCE);
        // initialize too early
        cheats.warp(block.timestamp + DURATION);
        cheats.expectRevert(bytes("Raffle has not ended"));
        rb.initializeSeed(raffleId);
    }
}

contract ClaimPrizeTest is RaffleBurnHelper {
    function testClaimPrize() public {
        uint256 raffleId = createDummyRaffle(address(nft1), address(t1));
        t1.approve(address(rb), MAX_ALLOWANCE);
        rb.buyTickets(raffleId, 5);
        cheats.warp(block.timestamp + DURATION + 1);
        rb.initializeSeed(raffleId);
        uint256 prizeIndex = 0;
        uint256 ticketId = rb.getWinnerTicketId(raffleId, prizeIndex);
        address winner = rb.getWinner(raffleId, prizeIndex);
        uint256 ticketPurchaseIndex = rb.getTicketPurchaseIndex(
            raffleId,
            ticketId
        );
        rb.claimPrize(winner, raffleId, prizeIndex, ticketPurchaseIndex);
        assertEq(nft1.ownerOf(0), winner);
    }
}
