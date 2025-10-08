import { ethers } from "hardhat";

async function main() {
  // Retrieve the deployer's wallet address
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account :", deployer.address);

  // NFT Contract
  const Contract = await ethers.getContractFactory("FileNFT")
  const contract = await Contract.deploy()
  const contractAddress = await contract.getAddress()

  console.log("Contract deployed to  :", contractAddress);
}

// Run the main function and catch any errors
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// Deploying contracts with the account : 0xd61ff783Ebc96892E878592cA1D629eFEACBC207
// BASE Contract deployed to            : 0xF8A962bF39e7eCE30C432aC565dB8df9708aD082
// BASE SEPOLIA Contract deployed to    : 0x371bD1EaBF3A98fc736a6c813a52FD060B998DDE
// BASE SEPOLIA Contract deployed to    : 0x143E0293E0a2E44935893A9912776DDB9b20462B
