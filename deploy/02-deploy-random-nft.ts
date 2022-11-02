import {
	developmentChains,
	VERIFICATION_BLOCK_CONFIRMATIONS,
	networkConfig,
} from "../helper-hardhat-config"
import verify from "../utils/verify"
import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { storeImages, storeTokeUriMetadata } from "../utils/uploadToPinata"
import { Contract } from "ethers"

const SUBSCRIPTION_FUND_AMOUNT = "1000000000000000000000"
const imagesLocation = "../images/randomNft/"

let tokenUris = [
	"ipfs://QmaVkBn2tKmjbhphU7eyztbvSQU5EXDdqRyXZtRhSGgJGo",
	"ipfs://QmYQC5aGZu2PTH8XzbJrbDnvhj3gVs7ya33H9mqUNvST3d",
	"ipfs://QmZYmH5iDbD6v3U2ixoVAjioSzvWJszDzYdbeCLquGSpVm",
]

const metadataTemplate = {
	name: "",
	description: "",
	image: "",
	attributes: [
		{
			trait_type: "Cuteness",
			value: 100,
		},
	],
}

const deployRandomNft: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
	const { deployments, getNamedAccounts, network, ethers } = hre
	const { deploy, log } = deployments
	const { deployer } = await getNamedAccounts()
	const chainId = network.config.chainId!

	let vrfCoordinatorV2Mock: Contract | undefined
	let vrfCoordinatorV2Address: string | undefined
	let subscriptionId: string | undefined

	// Handle resources, upload to IPFS
	if (process.env.UPLOAD_TO_PINATA == "true") {
		tokenUris = await handleTokenUris() // TODO create Pinata account and store API key in .env file
	}
	// deploy mocks if local dev chain
	if (chainId == 31337) {
		log("Creating VRF mock subscription...")
		// create VRFV2 Subscription on local mock
		vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
		vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address
		const transactionResponse = await vrfCoordinatorV2Mock.createSubscription()
		const transactionReceipt = await transactionResponse.wait()
		subscriptionId = transactionReceipt.events[0].args.subId
		// Fund the subscription
		// Our mock makes it so we don't actually have to worry about sending fund
		await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, SUBSCRIPTION_FUND_AMOUNT)
		log("VRF mock subscription added!")
	} else {
		// main- or testnet
		vrfCoordinatorV2Address = networkConfig[chainId].vrfCoordinatorV2
		subscriptionId = networkConfig[chainId].subscriptionId
	}
	// deploy NFT contract
	const waitBlockConfirmations = developmentChains.includes(network.name)
		? 1
		: VERIFICATION_BLOCK_CONFIRMATIONS

	log("----------------------------------------------------")
	const args = [
		vrfCoordinatorV2Address,
		networkConfig[chainId]["gasLane"],
		subscriptionId,
		networkConfig[chainId]["callbackGasLimit"],
		networkConfig[chainId]["mintFee"],
		tokenUris,
	]

	const randomNftContract = await deploy("RandomNFT", {
		from: deployer,
		args: args,
		log: true,
		waitConfirmations: waitBlockConfirmations,
	})
	// Add consumer for VRF
	if (chainId == 31337) {
		log("Adding consumer...")
		await vrfCoordinatorV2Mock!.addConsumer(subscriptionId, randomNftContract.address)
		log("Consumer was added!")
	} else {
		// TODO for local network the raffle contract needed to be added as a consumer,
		// maybe this can be done in the web-interface for test-net or has to be added here
	}

	// Verify the deployment
	if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
		log("Verifying...")
		await verify(randomNftContract.address, args)
	}
}

// helper functions TODO
async function handleTokenUris() {
	tokenUris = []
	const { responses: imgUploadResponses, files } = await storeImages(imagesLocation)
	for (const imgUploadResponsIndex in imgUploadResponses) {
		let tokenUriMetadata = { ...metadataTemplate }
		tokenUriMetadata.name = files[imgUploadResponsIndex].replace(".png", "")
		tokenUriMetadata.description = `an addorable ${tokenUriMetadata.name} pup!`
		tokenUriMetadata.image = `ipfs://${imgUploadResponses[imgUploadResponsIndex].IpfsHash}` // add image IPFS address
		console.log(`Uploading ${tokenUriMetadata.name}...`)
		const metadatastoringResponse = await storeTokeUriMetadata(tokenUriMetadata)
		tokenUris.push(`ipfs://${metadatastoringResponse!.IpfsHash}`)
	}
	console.log(`Following TokeURIs uploaded:`)
	console.log(tokenUris)
	return tokenUris
}

export default deployRandomNft
deployRandomNft.tags = ["all", "randomNft"]
