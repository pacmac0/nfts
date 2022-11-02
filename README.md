# NFT projects
This is an intermideat project to learn some more solidity functionalities and concepts specifically about NFTs.

### Goal:
- Build three types of NFT contracts.
  1. Basic NFT
    - Just the very basic NFT functionality utilizing openzeppelin
  2. Random NFT stored on IPFS
    - an NFT similar to before but stored on IPFS that
      - charges a purchase fee + withdraw for owner
      - Randomly gives 1 of 3 options with some probability
      - Keeps track of created NFTs
    - __Possible addition:__ Add maximum amount of mints and amount of each type
  3. SVG NFT stored on chain
    - make the SVG dependent on current ETH/USD price
      - Depending on Conversion rate a different image URI is being returned by the contracts tokenURI function. the actual URI is stored in the contract. The Token is just a mapping index in the contract.


### Notes:



### Set-up dependencie
```
yarn add --dev hardhat
yarn add --dev @nomiclabs/hardhat-ethers@npm:hardhat-deploy-ethers ethers @nomiclabs/hardhat-etherscan @nomiclabs/hardhat-waffle chai ethereum-waffle hardhat hardhat-contract-sizer hardhat-deploy hardhat-gas-reporter prettier prettier-plugin-solidity solhint solidity-coverage dotenv @typechain/ethers-v5 @typechain/hardhat @types/chai @types/node ts-node typechain typescript
```

### Further Resources
- [Chainlink VRF](https://docs.chain.link/docs/vrf/v2/introduction/)
  
### Useful comands:
- yarn hardhat deploy
- yarn lint (script comand)
- yarn format
- yarn coverage
- yarn test
- yarn debug (my own custome test for debuging)
- hh node (start dev blockchain, that keep running)
