// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

// Imports
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "base64-sol/base64.sol";
import "hardhat/console.sol";

// Errors
error ERC721Metadata__URI_QueryFor_NonExistentToken();

contract DynamicSvgNft is ERC721, Ownable {
	uint256 private s_tokenCounter;
	// could optionally be made imutable, if image changing functionality is not wanted
	string private s_lowImageURI;
	string private s_highImageURI;

	mapping(uint256 => int256) private s_tokenIdToHighValues;
	AggregatorV3Interface internal immutable i_priceFeed;

	// Events
	event CreatedNFT(uint256 indexed tokenId, int256 highValue);

	constructor(
		address priceFeedAddress,
		string memory lowSvg,
		string memory highSvg
	) ERC721("Dynamic SVG NFT", "DSN") {
		s_tokenCounter = 0;
		i_priceFeed = AggregatorV3Interface(priceFeedAddress);
		s_lowImageURI = svgToImageURI(lowSvg);
		s_highImageURI = svgToImageURI(highSvg);
		// setLowSVG(lowSvg);
		// setHighSVG(highSvg);
	}

	function mintNFT(int256 highValue) public {
		_safeMint(msg.sender, s_tokenCounter);
		s_tokenIdToHighValues[s_tokenCounter] = highValue;
		s_tokenCounter = s_tokenCounter + 1;
		emit CreatedNFT(s_tokenCounter, highValue);
	}

	// can be also done of chain to safe some gas
	function svgToImageURI(string memory svg) public pure returns (string memory) {
		// example:
		// '<svg width="500" height="500" viewBox="0 0 285 350" fill="none" xmlns="http://www.w3.org/2000/svg"><path fill="black" d="M150,0,L75,200,L225,200,Z"></path></svg>'
		// would return ""
		string memory baseURL = "data:image/svg+xml;base64,";
		string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
		return string(abi.encodePacked(baseURL, svgBase64Encoded));
	}

	function _baseURI() internal pure override returns (string memory) {
		return "data:application/json;base64,";
	}

	// return different iamge URI depending on the ETH/USD price feed. Making the NFT "interactive"
	function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
		if (!_exists(tokenId)) {
			// _exists() derived from ERC721
			revert ERC721Metadata__URI_QueryFor_NonExistentToken();
		}
		(, int256 price, , , ) = i_priceFeed.latestRoundData();
		string memory imageURI = s_lowImageURI;
		if (price >= s_tokenIdToHighValues[tokenId]) {
			imageURI = s_highImageURI;
		}
		return
			string(
				abi.encodePacked(
					_baseURI(),
					Base64.encode(
						bytes(
							abi.encodePacked(
								'{"name":"',
								name(), // You can add whatever name here, name() also from ERC721
								'", "description":"An NFT that changes based on the Chainlink Feed", ',
								'"attributes": [{"trait_type": "coolness", "value": 100}], "image":"',
								imageURI,
								'"}'
							)
						)
					)
				)
			);
	}

	function getLowSVG() public view returns (string memory) {
		return s_lowImageURI;
	}

	function getHighSVG() public view returns (string memory) {
		return s_highImageURI;
	}

	function getPriceFeed() public view returns (AggregatorV3Interface) {
		return i_priceFeed;
	}

	function getTokenCounter() public view returns (uint256) {
		return s_tokenCounter;
	}
	// functions to make images/token data exchangable
	//
	// function setLowURI(string memory svgLowURI) public onlyOwner {
	//     s_lowImageURI = svgLowURI;
	// }

	// function setHighURI(string memory svgHighURI) public onlyOwner {
	//     s_highImageURI = svgHighURI;
	// }

	// function setLowSVG(string memory svgLowRaw) public onlyOwner {
	//     string memory svgURI = svgToImageURI(svgLowRaw);
	//     setLowURI(svgURI);
	// }

	// function setHighSVG(string memory svgHighRaw) public onlyOwner {
	//     string memory svgURI = svgToImageURI(svgHighRaw);
	//     setHighURI(svgURI);
	// }
}
