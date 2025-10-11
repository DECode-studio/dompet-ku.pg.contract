import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { MockERC20, MockAerodromeSwapRouter, PaymentGatewayAerodrome } from "../../typechain-types";

describe("PaymentGateway (TypeScript)", function () {

    let owner: SignerWithAddress;
    let sender: SignerWithAddress;
    let recipient: SignerWithAddress;
    let nonOwner: SignerWithAddress;

    let idrx: MockERC20;
    let usdt: MockERC20;
    let usdc: MockERC20;
    let dai: MockERC20;
    let mockRouter: MockAerodromeSwapRouter;
    let gateway: PaymentGatewayAerodrome;

    const EXCHANGE_RATE = 100;
    const DECIMALS = 18;
    const parseUnits = (value: string | number) => ethers.parseUnits(value.toString(), DECIMALS);


    beforeEach(async function () {
        [owner, sender, recipient, nonOwner] = await ethers.getSigners();

        const MockERC20Factory = await ethers.getContractFactory("MockERC20");
        idrx = await MockERC20Factory.deploy("IDRX Token", "IDRX");
        usdt = await MockERC20Factory.deploy("Tether", "USDT");
        usdc = await MockERC20Factory.deploy("USD Coin", "USDC");
        dai = await MockERC20Factory.deploy("DAI Stablecoin", "DAI");

        const MockAerodromeSwapRouterFactory = await ethers.getContractFactory("MockAerodromeSwapRouter");
        mockRouter = await MockAerodromeSwapRouterFactory.deploy(await idrx.getAddress());

        const PaymentGateway = await ethers.getContractFactory("PaymentGatewayAerodrome");
        gateway = await PaymentGateway.deploy(
            await idrx.getAddress(),
            await mockRouter.getAddress(),
            [await usdt.getAddress(), await usdc.getAddress()],
            [true, true]
        );

        await idrx.mint(await mockRouter.getAddress(), parseUnits(1_000_000));
    });

    describe("Deployment", function () {
        it("Should set the correct owner, IDRX, and router addresses", async function () {
            expect(await gateway.owner()).to.equal(owner.address);
            expect(await gateway.idrxToken()).to.equal(await idrx.getAddress());
            expect(await gateway.aerodromeRouter()).to.equal(await mockRouter.getAddress());
        });
        it("Should correctly initialize the list of supported tokens", async function () {
            expect(await gateway.isSupportedToken(await usdt.getAddress())).to.be.true;
            expect(await gateway.isSupportedToken(await usdc.getAddress())).to.be.true;
            expect(await gateway.isSupportedToken(await dai.getAddress())).to.be.false;
            expect(await gateway.getSupportedTokensLength()).to.equal(2);
        });
    });

    describe("Direct Transfers (IDRX)", function () {
        it("Should transfer IDRX directly from sender to recipient", async function () {
            const amount = parseUnits(250);
            await idrx.mint(sender.address, amount);
            await idrx.connect(sender).approve(await gateway.getAddress(), amount);

            const tx = gateway.connect(sender).transfer(await idrx.getAddress(), recipient.address, BigInt(amount));

            await expect(tx).to.changeTokenBalances(idrx, [sender, recipient], [-amount, amount]);
            await expect(tx).to.emit(gateway, "PaymentProcessed")
                .withArgs(sender.address, recipient.address, await idrx.getAddress(), amount, amount, false);
        });
    });

    describe("Swap Transfers (Supported Tokens)", function () {
        it("Should swap USDT for IDRX and send to recipient", async function () {
            const amountIn = parseUnits(10);
            const expectedAmountOut = amountIn * BigInt(EXCHANGE_RATE);

            await usdt.mint(sender.address, amountIn);
            await usdt.connect(sender).approve(await gateway.getAddress(), amountIn);

            const tx = gateway.connect(sender).transfer(await usdt.getAddress(), recipient.address, amountIn);

            await expect(tx).to.changeTokenBalances(usdt, [sender], [-amountIn]);
            await expect(tx).to.changeTokenBalances(idrx, [recipient], [expectedAmountOut]);
            await expect(tx).to.emit(gateway, "PaymentProcessed")
                .withArgs(sender.address, recipient.address, await usdt.getAddress(), amountIn, expectedAmountOut, true);
        });
    });

    describe("Admin Functions", function () {
        describe("addSupportedToken", function () {
            it("Should allow owner to add a new supported token", async function () {
                const daiAddress = await dai.getAddress();
                const fee = 1000

                await expect(gateway.connect(owner).addSupportedToken(daiAddress, true))
                    .to.emit(gateway, "SupportedTokenAdded").withArgs(daiAddress, true);

                expect(await gateway.isSupportedToken(daiAddress)).to.be.true;
                expect(await gateway.getSupportedTokensLength()).to.equal(3);
            });

            it("Should prevent non-owner from adding a token", async function () {
                const daiAddress = await dai.getAddress();
                const fee = 1000

                await expect(gateway.connect(nonOwner).addSupportedToken(daiAddress, true))
                    .to.be.revertedWithCustomError(gateway, "OwnableUnauthorizedAccount");
            });

            it("Should revert when adding an already supported token", async function () {
                const usdtAddress = await usdt.getAddress();
                const fee = 1000

                await expect(gateway.connect(owner).addSupportedToken(usdtAddress, true))
                    .to.be.revertedWith("Token already supported");
            });
        });

        describe("removeSupportedToken", function () {
            it("Should allow owner to remove a supported token", async function () {
                const usdtAddress = await usdt.getAddress();
                await expect(gateway.connect(owner).removeSupportedToken(usdtAddress))
                    .to.emit(gateway, "SupportedTokenRemoved").withArgs(usdtAddress);

                expect(await gateway.isSupportedToken(usdtAddress)).to.be.false;
                expect(await gateway.getSupportedTokensLength()).to.equal(1);
            });

            it("Should prevent non-owner from removing a token", async function () {
                await expect(gateway.connect(nonOwner).removeSupportedToken(await usdt.getAddress()))
                    .to.be.revertedWithCustomError(gateway, "OwnableUnauthorizedAccount");
            });

            it("Should revert when removing an unsupported token", async function () {
                await expect(gateway.connect(owner).removeSupportedToken(await dai.getAddress()))
                    .to.be.revertedWith("Token not supported");
            });
        });
    });

    describe("Failure Cases", function () {
        it("Should revert when transferring an unsupported token", async function () {
            await expect(gateway.connect(sender).transfer(await dai.getAddress(), recipient.address, parseUnits(10)))
                .to.be.revertedWith("Token not supported");
        });

        it("Should revert a swap if sender has not approved the token", async function () {
            const amountIn = parseUnits(10);
            await usdt.mint(sender.address, amountIn);

            await expect(gateway.connect(sender).transfer(await usdt.getAddress(), recipient.address, amountIn))
                .to.be.revertedWithCustomError(usdt, "ERC20InsufficientAllowance");
        });

        it("Should revert a direct transfer if sender has not approved IDRX", async function () {
            const amount = parseUnits(100);
            await idrx.mint(sender.address, amount);

            await expect(gateway.connect(sender).transfer(await idrx.getAddress(), recipient.address, amount))
                .to.be.revertedWithCustomError(idrx, "ERC20InsufficientAllowance");
        });

        it("Should revert for zero amount transfer", async function () {
            await expect(gateway.connect(sender).transfer(await idrx.getAddress(), recipient.address, 0))
                .to.be.revertedWith("Transfer amount must be greater than zero");
        });
    });
});