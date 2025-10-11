import { ethers } from "hardhat";

async function main() {
  // Retrieve the deployer's wallet address
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account :", deployer.address);

  // NFT Contract
  const Contract = await ethers.getContractFactory("PaymentGatewayAerodrome")
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
    '0x2626664c2603336E57B271c5C0b26F421741e481', // Uniswap Router Address
    [
      '0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34',
      '0x2ae3f1ec7f1f5012cfeab0185bfc7aa3cf0dec22',
      '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf',
      '0x4200000000000000000000000000000000000006',
      '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913',
      '0x0555e30da8f98308edb960aa94c0db47230d2b9c',
    ],
    [ // Initial fees (harus 6 items juga, adjust berdasarkan pool V3 di Uniswap)
      3000, // 0.3% untuk token 1
      500, // 0.05% untuk token 2
      3000, // dst...
      500,
      1000, // 0.1% untuk USDC (cocok pair stable)
      3000
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

// Deployer Address   : 0xE6A7d99011257AEc28Ad60EFED58A256c4d5Fea3
// IDRT Address       : 0xb4a911eC34eDaaEFC393c52bbD926790B9219df4
// PG Address MAIN    : 0xe12471376774990223DBEfD9Ce37d00F182B8108
// PG V3 Address MAIN : 0xC2Bbc9b56e496fA23e543018f7d0ED360453C3C6
// PG Address TEST    : 0xF043b0b91C8F5b6C2DC63897f1632D6D15e199A9
