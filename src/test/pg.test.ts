import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { MockERC20, MockUniswapV2Router, PaymentGateway } from "../../typechain-types";

describe("PaymentGateway (TypeScript)", function () {
    // --- Variabel Test ---
    let owner: SignerWithAddress;
    let sender: SignerWithAddress;
    let recipient: SignerWithAddress;

    let idrx: MockERC20;
    let usdt: MockERC20;
    let usdc: MockERC20;
    let mockRouter: MockUniswapV2Router;
    let PaymentGateway: PaymentGateway;

    // --- Konstanta ---
    const EXCHANGE_RATE = 100;
    const DECIMALS = 18;
    const parseUnits = (value: string | number) => ethers.parseUnits(value.toString(), DECIMALS);

    // --- Setup (beforeEach) ---
    beforeEach(async function () {
        [owner, sender, recipient] = await ethers.getSigners();

        const MockERC20Factory = await ethers.getContractFactory("MockERC20");
        idrx = await MockERC20Factory.deploy("IDRX Token", "IDRX");
        usdt = await MockERC20Factory.deploy("Tether", "USDT");
        usdc = await MockERC20Factory.deploy("USD Coin", "USDC");

        const idrxAddress = await idrx.getAddress();

        const MockUniswapV2RouterFactory = await ethers.getContractFactory("MockUniswapV2Router");
        mockRouter = await MockUniswapV2RouterFactory.deploy(idrxAddress);
        const routerAddress = await mockRouter.getAddress();

        const PaymentGatewayFactory = await ethers.getContractFactory("PaymentGateway");
        PaymentGateway = await PaymentGatewayFactory.deploy(
            idrxAddress,
            await usdt.getAddress(),
            await usdc.getAddress(),
            routerAddress
        );

        await idrx.mint(routerAddress, parseUnits(1_000_000));
    });

    // --- Test Cases ---

    describe("Deployment", function () {
        it("Should set the right owner and token addresses", async function () {
            expect(await PaymentGateway.owner()).to.equal(owner.address);
            expect(await PaymentGateway.idrxToken()).to.equal(await idrx.getAddress());
            expect(await PaymentGateway.usdtToken()).to.equal(await usdt.getAddress());
            expect(await PaymentGateway.uniswapRouter()).to.equal(await mockRouter.getAddress());
        });
    });

    describe("Transfers without Swap", function () {
        it("Should transfer IDRX successfully if sender has enough balance", async function () {
            const amount = parseUnits(100);
            const contractAddress = await PaymentGateway.getAddress();

            await idrx.mint(sender.address, amount);
            await idrx.connect(sender).approve(contractAddress, amount);

            // ✅ Simpan transaksi dalam satu variabel
            const tx = PaymentGateway.connect(sender).transfer(recipient.address, amount);

            // ✅ Periksa semua ekspektasi pada transaksi yang sama
            await expect(tx)
                .to.changeTokenBalances(idrx, [sender, recipient], [-amount, amount]);
            await expect(tx)
                .to.emit(PaymentGateway, "TransferFromDuitku")
                .withArgs(sender.address, recipient.address, amount, false, ethers.ZeroAddress, 0);
        });
    });

    describe("Transfers with Swap", function () {
        it("Should use USDT to swap for IDRX if IDRX balance is zero", async function () {
            const amountToSend = parseUnits(500);
            const usdtNeeded = amountToSend / BigInt(EXCHANGE_RATE);
            const contractAddress = await PaymentGateway.getAddress();

            await usdt.mint(sender.address, usdtNeeded);
            await usdt.connect(sender).approve(contractAddress, usdtNeeded);

            // ✅ Simpan transaksi dalam satu variabel
            const tx = PaymentGateway.connect(sender).transfer(recipient.address, amountToSend);
            const usdtAddress = await usdt.getAddress();

            // ✅ Periksa semua ekspektasi pada transaksi yang sama
            await expect(tx).to.changeTokenBalances(usdt, [sender], [-usdtNeeded]);
            await expect(tx).to.changeTokenBalances(idrx, [recipient], [amountToSend]);
            await expect(tx)
                .to.emit(PaymentGateway, "TransferFromDuitku")
                .withArgs(sender.address, recipient.address, amountToSend, true, usdtAddress, usdtNeeded);
        });

        it("Should use partial IDRX and swap the rest from USDC", async function () {
            const partialIdrx = parseUnits(200);
            const amountToSend = parseUnits(1000);
            const neededFromSwap = amountToSend - partialIdrx;
            const usdcNeeded = neededFromSwap / BigInt(EXCHANGE_RATE);
            const contractAddress = await PaymentGateway.getAddress();
            const usdcAddress = await usdc.getAddress();

            await idrx.mint(sender.address, partialIdrx);
            await usdc.mint(sender.address, usdcNeeded);
            await idrx.connect(sender).approve(contractAddress, partialIdrx);
            await usdc.connect(sender).approve(contractAddress, usdcNeeded);

            const tx = PaymentGateway.connect(sender).transfer(recipient.address, amountToSend);

            await expect(tx).to.changeTokenBalances(idrx, [sender, recipient], [-partialIdrx, amountToSend]);
            await expect(tx).to.changeTokenBalances(usdc, [sender], [-usdcNeeded]);
            await expect(tx)
                .to.emit(PaymentGateway, "TransferFromDuitku")
                .withArgs(sender.address, recipient.address, amountToSend, true, usdcAddress, usdcNeeded);
        });

        it("Should prioritize USDT over USDC for swapping", async function () {
            const amountToSend = parseUnits(500);
            const usdtNeeded = amountToSend / BigInt(EXCHANGE_RATE);
            const contractAddress = await PaymentGateway.getAddress();

            await usdt.mint(sender.address, usdtNeeded);
            await usdc.mint(sender.address, parseUnits(100));
            await usdt.connect(sender).approve(contractAddress, usdtNeeded);
            await usdc.connect(sender).approve(contractAddress, parseUnits(100));

            // ✅ Simpan transaksi dalam satu variabel
            const tx = PaymentGateway.connect(sender).transfer(recipient.address, amountToSend);

            // ✅ Periksa semua ekspektasi pada transaksi yang sama
            await expect(tx).to.changeTokenBalances(usdt, [sender], [-usdtNeeded]);
            await expect(tx).to.changeTokenBalances(usdc, [sender], [0]);
        });
    });

    describe("Failure Cases", function () {
        it("Should revert if all balances (IDRX, USDT, USDC) are insufficient", async function () {
            const amount = parseUnits(1000);
            await expect(
                PaymentGateway.connect(sender).transfer(recipient.address, amount)
            ).to.be.revertedWith("Insufficient balance in USDT/USDC or approval not set");
        });

        it("Should revert if balance is sufficient but approval is not given", async function () {
            const amount = parseUnits(100);
            await idrx.mint(sender.address, amount);

            // ✅ Gunakan revertedWithCustomError untuk menangkap error dari OpenZeppelin versi baru
            // Argumen pertama adalah objek kontrak yang MENDIFINISIKAN error (yaitu token IDRX)
            // Argumen kedua adalah nama error sebagai string
            await expect(
                PaymentGateway.connect(sender).transfer(recipient.address, amount)
            ).to.be.revertedWithCustomError(idrx, "ERC20InsufficientAllowance");
        });

        it("Should revert for zero amount transfer", async function () {
            await expect(
                PaymentGateway.connect(sender).transfer(recipient.address, 0)
            ).to.be.revertedWith("Transfer amount must be greater than zero");
        });
    });
});