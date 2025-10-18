import { ethers } from "hardhat";

async function main() {
  // Retrieve the deployer's wallet address
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account :", deployer.address);

  // NFT Contract
  const Contract = await ethers.getContractFactory("PaymentGatewayAerodromeRouter")
  // const contract = await Contract.deploy(
  //   '0xb4a911eC34eDaaEFC393c52bbD926790B9219df4', // IDRT Address
  //   '0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4', // Uniswap Router Address
  //   [
  //     '0xb6bba1c552245e4277f5712dad9db8e7f09acbfc', 
  //     '0xe4ab69c077896252fafbd49efd26b5d171a32410'
  //   ]
  // )

  const contract = await Contract.deploy(
    '0x18Bc5bcC660cf2B9cE3cd51a404aFe1a0cBD3C22', // BASE IDRX Address
    // '0x01D40099fCD87C018969B0e8D4aB1633Fb34763C', // Aerodome Unoversal Router // Base
    '0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43', // Aerodome Router Address  // Base
    // '0x2626664c2603336E57B271c5C0b26F421741e481', // Uniswap Router Address // Base
    // '0xE592427A0AEce92De3Edee1F18E0157C05861564',
    // '0x3a63171DD9BebF4D07BC782FECC7eb0b890C2A45', // Velodrome Router LISK
    [
      '0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34', // BASE
      '0x2ae3f1ec7f1f5012cfeab0185bfc7aa3cf0dec22', // BASE
      '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf', // BASE
      '0x4200000000000000000000000000000000000006', // BASE
      '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913', // BASE
      '0x0555e30da8f98308edb960aa94c0db47230d2b9c', // BASE
      // '0x4200000000000000000000000000000000000006', // LISK
      // '0x03c7054bcb39f7b2e5b2c7acb37583e32d70cfa3', // LISK
      // '0xac485391eb2d7d88253a7f1ef18c37f4242d1a24', // LISK
      // '0x43f2376d5d03553ae72f4a8093bbe9de4336eb08', // LISK
    ],
    // [ // Initial fees
    //   3000, 500, 3000, 500, 1000, 3000
    // ],
    [ // Initial stable (false = volatile, true = stable; adjust berdasarkan pool Aerodrome)
      false, false, false, false,  false, false  // USDC true karena stable pair
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

// Deployer Address       : 0xE6A7d99011257AEc28Ad60EFED58A256c4d5Fea3
// IDRT Address           : 0xb4a911eC34eDaaEFC393c52bbD926790B9219df4
// PG Address MAIN        : 0xe12471376774990223DBEfD9Ce37d00F182B8108
// PG V3 Address MAIN     : 0xC2Bbc9b56e496fA23e543018f7d0ED360453C3C6
// PG Aerodome Address    : 0xd002E6E1D1c9fFc150DB0d59EAE2dEc9521d9c3F // BASE
// PG Velodrome Address   : 0x0B841687C751bE4Db897a1B0EC24418294CEfad2 // LISK
// PG LiFi Address        : 0x2CADBCcaA7989fB52B1Cc65569ee5e61A9E4F8eB // BASE
// PG Uniswap Address     : 0x463Cd1fc6dD2590808e3C4B5C351aA6A2EBF765f // BASE
// PG Aerodome Address    : 0x86b15744F1CC682e8a7236Bb7B2d02dA957958aD // LISK
// PG Aerodome Universal  : 0xF5475B736870929f9fb44CDEF5fa7A0544C64D28
// PG Address TEST        : 0xF043b0b91C8F5b6C2DC63897f1632D6D15e199A9

// Uniswap Router BASE    : 0x2626664c2603336E57B271c5C0b26F421741e481
// Uniswap Router LISK    : 0x1b35fbA9357fD9bda7ed0429C8BbAbe1e8CC88fc
// Velodrome Router OP    : 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858 && 0x9c12939390052919af3155f41bf4160fd3666a6f 
// Velodrome Router LISK  : 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858