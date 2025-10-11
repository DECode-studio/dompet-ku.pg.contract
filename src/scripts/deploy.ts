import { ethers } from "hardhat";

async function main() {
  // Retrieve the deployer's wallet address
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account :", deployer.address);

  // NFT Contract
  const Contract = await ethers.getContractFactory("PaymentGateway")
  // const contract = await Contract.deploy(
  //   '0xb4a911eC34eDaaEFC393c52bbD926790B9219df4', // IDRT Address
  //   '0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4', // Uniswap Router Address
  //   [
  //     '0xb6bba1c552245e4277f5712dad9db8e7f09acbfc', 
  //     '0xe4ab69c077896252fafbd49efd26b5d171a32410'
  //   ]
  // )

  const contract = await Contract.deploy(
    '0x18Bc5bcC660cf2B9cE3cd51a404aFe1a0cBD3C22', // IDRT Address
    '0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24', // Uniswap Router Address
    [
      '0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34', 
      '0x2ae3f1ec7f1f5012cfeab0185bfc7aa3cf0dec22',
      '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf',
      '0x4200000000000000000000000000000000000006',
      '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913', 
      '0x0555e30da8f98308edb960aa94c0db47230d2b9c',
    ]
  )
  const contractAddress = await contract.getAddress()

  console.log("Contract deployed to  :", contractAddress);
}

// Run the main function and catch any errors
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// IDRT Address     : 0xb4a911eC34eDaaEFC393c52bbD926790B9219df4
// PG Address MAIN  : 0xe76aC6d60DC29D4438552fC2418a77Ab19d5ABd6
// PG Address TEST  : 0xF043b0b91C8F5b6C2DC63897f1632D6D15e199A9
