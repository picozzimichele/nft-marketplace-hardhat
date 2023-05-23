//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//1:00:32:12

error NftMarketplace__PriceMustBeAboveZero();
error NftMarketplace__NotApprovedForNftMarketplace();
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotOwner();
error NftMarketplace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NftMarketplace__NoProceeds();
error NftMarketplace__TransferFailed();

contract NftMarketplace {
  struct Listing {
    uint256 price;
    address seller;
  }

  event ItemListed(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);

  event ItemBought(address indexed buyer, address indexed nftAddress, uint256 indexed tokenId, uint256 price);

  event ItemCancelled(address indexed owner, address indexed nftAddress, uint256 indexed tokenId);

  // NFT contract address => NTF tokenID => Listing
  mapping(address => mapping(uint256 => Listing)) private s_listings;
  // Seller address => ammount earned
  mapping(address => uint256) private s_proceeds;

  //MODIFIERS
  modifier notListed(
    address nftAddress,
    uint256 tokenId,
    address owner
  ) {
    Listing memory listiedItem = s_listings[nftAddress][tokenId];
    if (listiedItem.price > 0) {
      revert NftMarketplace__AlreadyListed(nftAddress, tokenId);
    }
    _;
  }

  modifier isListed(address nftAddress, uint256 tokenId) {
    Listing memory listiedItem = s_listings[nftAddress][tokenId];
    if (listiedItem.price <= 0) {
      revert NftMarketplace__NotListed(nftAddress, tokenId);
    }
    _;
  }

  modifier isOwner(
    address nftAddress,
    uint256 tokenId,
    address spender
  ) {
    IERC721 nft = IERC721(nftAddress);
    address owner = nft.ownerOf(tokenId);
    if (spender != owner) {
      revert NftMarketplace__NotOwner();
    }
    _;
  }

  //MAIN FUNCTIONS

  /*
    @notice Method to list the NFT for sale on the marketplace
    @param nftAddress - address of the NFT contract
    @param tokenId - ID of the NFT
    @param price - price of the NFT
    @dev - technically the owner of the NFT is still the owner of the NFT, 
    but the NFT is now approved to be sold by the contract
     */
  function listItem(
    address nftAddress,
    uint256 tokenId,
    uint256 price
  ) external notListed(nftAddress, tokenId, msg.sender) isOwner(nftAddress, tokenId, msg.sender) {
    if (price <= 0) {
      revert NftMarketplace__PriceMustBeAboveZero();
    }
    //Owners of the token will still own the NFT but will give the contract Approval to sell it
    IERC721 nft = IERC721(nftAddress);
    if (nft.getApproved(tokenId) != address(this)) {
      revert NftMarketplace__NotApprovedForNftMarketplace();
    }
    s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
    emit ItemListed(msg.sender, nftAddress, tokenId, price);
  }

  function buyItem(address nftAddress, uint256 tokenId) external payable isListed(nftAddress, tokenId) {
    Listing memory listedItem = s_listings[nftAddress][tokenId];
    if (msg.value < listedItem.price) {
      revert NftMarketplace__PriceNotMet(nftAddress, tokenId, listedItem.price);
    }
    // sending money to the user ❌
    // we want the user to withdraw the money ✅
    s_proceeds[listedItem.seller] = s_proceeds[listedItem.seller] + msg.value;
    delete (s_listings[nftAddress][tokenId]);
    IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);
    //check to make sure the NFT was transfered
    emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
  }

  function cancelListing(address nftAddress, uint256 tokenId) external isOwner(nftAddress, tokenId, msg.sender) isListed(nftAddress, tokenId) {
    delete (s_listings[nftAddress][tokenId]);
    emit ItemCancelled(msg.sender, nftAddress, tokenId);
  }

  function updateListing(
    address nftAddress,
    uint256 tokenId,
    uint256 newPrice
  ) external isListed(nftAddress, tokenId) isOwner(nftAddress, tokenId, msg.sender) {
    s_listings[nftAddress][tokenId].price = newPrice;
    emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
  }

  function withdrawProceeds() external {
    uint256 proceeds = s_proceeds[msg.sender];
    if (proceeds <= 0) {
      revert NftMarketplace__NoProceeds();
    }
    s_proceeds[msg.sender] = 0;
    (bool success, ) = payable(msg.sender).call{value: proceeds}("");
    if (!success) {
      revert NftMarketplace__TransferFailed();
    }
  }

  //GETTER FUNCTIONS

  function getListing(address nftAddress, uint256 tokenId) external view returns (Listing memory) {
    return s_listings[nftAddress][tokenId];
  }

  function getProceeds(address seller) external view returns (uint256) {
    return s_proceeds[seller];
  }
}
