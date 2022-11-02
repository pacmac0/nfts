// We are going to skimp a bit on these tests...

import { assert, expect } from "chai"
import { network, deployments, ethers } from "hardhat"
import { developmentChains, networkConfig } from "../../helper-hardhat-config"
import { RandomNft, VRFCoordinatorV2Mock, Address } from "../../typechain-types"

!developmentChains.includes(network.name)
	? describe.skip
	: describe("Random NFT Unit Tests", function () {
			let randomNft: RandomNft, deployer: Address, vrfCoordinatorV2Mock: VRFCoordinatorV2Mock

			beforeEach(async () => {
				const accounts = await ethers.getSigners()
				deployer = accounts[0]
				await deployments.fixture(["randomNft"])
				vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
				randomNft = await ethers.getContract("RandomNFT")
			})

			describe("Constructor", function () {
				it("initializes the contract correctly", async function () {
					const isInitialized = await randomNft.getInitialized()
					assert.equal(isInitialized, true)
					const mintFee = networkConfig[network.config.chainId!]["mintFee"]
					const contractMintFee = await randomNft.getMintFee()
					assert.equal(contractMintFee.toString(), mintFee)
					// hardcode URIs for testing, using the hardcoded once since we do not upload ourselfs to pinata
					const tokenUris = [
						"ipfs://QmaVkBn2tKmjbhphU7eyztbvSQU5EXDdqRyXZtRhSGgJGo",
						"ipfs://QmYQC5aGZu2PTH8XzbJrbDnvhj3gVs7ya33H9mqUNvST3d",
						"ipfs://QmZYmH5iDbD6v3U2ixoVAjioSzvWJszDzYdbeCLquGSpVm",
					]
					for (const uriIndex in tokenUris) {
						const contractTokenUri = await randomNft.getTokenUri(uriIndex)
						assert.equal(contractTokenUri, tokenUris[uriIndex])
					}
					// continue testing init. values
				})
			})
			describe("requestNFT", function () {
				it("reverts if minimum fee is not payed", async function () {
					await expect(randomNft.requestNFT()).to.be.revertedWith(
						"RandomNFT__NotEnoughPayed"
					)
				})
				it("adds emits NFT requested event", async function () {
					const contractMintFee = await randomNft.getMintFee()
					await expect(
						randomNft.requestNFT({ value: contractMintFee.toString() })
					).to.emit(randomNft, "NftRequested")
				})
			})
			describe("fulfillRandomWords", function () {
				it("mints NFT and increases token counter", async function () {
					await new Promise<void>(async (resolve, reject) => {
						randomNft.once("NftMinted", async () => {
							console.log("NftMinted event fired!")
							try {
								const tokenCounter = await randomNft.getTokenCounter()
								assert.equal(tokenCounter.toString(), "1")
								const nftOwner = await randomNft.ownerOf(0)
								assert.equal(nftOwner, deployer.address)
								resolve()
							} catch (e) {
								console.log(e)
								reject(e)
							}
						})
						try {
							const fee = await randomNft.getMintFee()
							const requestNftResponse = await randomNft.requestNFT({
								value: fee.toString(),
							})
							const requestNftReceipt = await requestNftResponse.wait(1)
							const tx = await vrfCoordinatorV2Mock.fulfillRandomWords(
								requestNftReceipt.events![1].args!.requestId,
								randomNft.address
							)
							/* log all emited events, for debuging
							const receipt = await tx.wait()
							for (const event of receipt.events) {
								console.log(`Event ${event.event} with args ${event.args}`)
							}
							*/
						} catch (e) {
							console.log(e)
							reject(e)
						}
					})
				})
			})
	  })
