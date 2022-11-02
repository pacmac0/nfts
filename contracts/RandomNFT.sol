// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

// Imports
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

// Errors
error RandomNFT__NotEnoughPayed();
error RandomNFT__RangeOutOfBounds();
error RandomNFT__AlreadyInitialized();

contract RandomNFT is ERC721URIStorage, VRFConsumerBaseV2, Ownable {
	enum NftType {
		PUG,
		SHIBA_INU,
		ST_BERNARD
	}

	// Chainlink VRF Variables
	VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
	bytes32 private i_keyHash;
	uint64 private i_subscriptionId;
	uint32 private i_callbackGasLimit;
	uint16 private constant REQUEST_CONFIRMATIONS = 3;
	uint32 private constant NUMWORDS = 1;
	// VRF Helper
	mapping(uint256 => address) public s_requestIdToSender;

	// NFT Variables
	uint256 internal constant MAX_PROBABILITY_VALUE = 100;
	uint256 public immutable i_mintFee;
	uint256 public s_tokenCounter;
	string[] internal s_tokenUris;
	bool private s_initialized; // imutable is an issue here!! Can't be set this way then

	// Events
	event NftRequested(uint256 indexed requestId, address requester);
	event NftMinted(uint256 indexed tokenId, uint256 Type, address owner);

	// functions
	constructor(
		address vrfCoordinatorV2,
		bytes32 keyHash, // gasLane
		uint64 subscriptionId,
		uint32 callbackGasLimit,
		uint256 mintFee,
		string[3] memory tokenUris
	) ERC721("Random Puppy Token", "RPT") VRFConsumerBaseV2(vrfCoordinatorV2) {
		i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
		i_keyHash = keyHash;
		i_subscriptionId = subscriptionId;
		i_callbackGasLimit = callbackGasLimit;

		i_mintFee = mintFee;
		_initializeContract(tokenUris);
	}

	function _initializeContract(string[3] memory tokenUris) private {
		if (s_initialized) {
			revert RandomNFT__AlreadyInitialized();
		}
		s_tokenUris = tokenUris;
		s_initialized = true;
	}

	// 1 step of random process, get random word
	function requestNFT() public payable returns (uint256 requestId) {
		// check Fee payed
		if (msg.value < i_mintFee) {
			revert RandomNFT__NotEnoughPayed();
		}
		// VRF call
		requestId = i_vrfCoordinator.requestRandomWords(
			i_keyHash,
			i_subscriptionId,
			REQUEST_CONFIRMATIONS,
			i_callbackGasLimit,
			NUMWORDS
		);
		// create helper mapping for second step
		s_requestIdToSender[requestId] = msg.sender;
		emit NftRequested(requestId, msg.sender);
	}

	function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
		address nftOwner = s_requestIdToSender[requestId];
		uint256 modRndmProb = randomWords[0] % MAX_PROBABILITY_VALUE;
		NftType nftType = getTypeFromModdedRndmProb(modRndmProb);
		uint256 tokenId = s_tokenCounter;
		s_tokenCounter = s_tokenCounter + 1;
		_safeMint(nftOwner, tokenId);
		_setTokenURI(tokenId, s_tokenUris[uint256(nftType)]);
		emit NftMinted(tokenId, uint256(nftType), nftOwner);
	}

	function getTypeFromModdedRndmProb(uint256 modRndmProb) internal returns (NftType) {
		uint256[3] memory nftProbabilityRanges = getProbabilityArray();
		uint256 lowerBound = 0;
		for (uint256 i = 0; i < nftProbabilityRanges.length; i++) {
			if (modRndmProb >= lowerBound && modRndmProb < nftProbabilityRanges[i]) {
				return NftType(i);
			}
			lowerBound = nftProbabilityRanges[i];
		}
		revert RandomNFT__RangeOutOfBounds();
	}

	function withdraw() public onlyOwner {
		uint256 amount = address(this).balance;
		(bool success, ) = payable(msg.sender).call{value: amount}("");
		require(success, "Withdraw failed");
	}

	function getProbabilityArray() public pure returns (uint256[3] memory) {
		return [10, 30, MAX_PROBABILITY_VALUE];
	}

	function getMintFee() public view returns (uint256) {
		return i_mintFee;
	}

	function getTokenUri(uint256 index) public view returns (string memory) {
		return s_tokenUris[index];
	}

	function getInitialized() public view returns (bool) {
		return s_initialized;
	}

	function getTokenCounter() public view returns (uint256) {
		return s_tokenCounter;
	}
}
