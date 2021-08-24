import { expect } from "chai";
import { ecsign } from "ethereumjs-util";
import { BigNumber, constants } from "ethers";
import { defaultAbiCoder, hexlify, keccak256, toUtf8Bytes } from "ethers/lib/utils";
import { waffle } from "hardhat";
import GachaHousekeepersArtifact from "../artifacts/contracts/GachaHousekeepers.sol/GachaHousekeepers.json";
import MaidCoinArtifact from "../artifacts/contracts/MaidCoin.sol/MaidCoin.json";
import TestLPTokenArtifact from "../artifacts/contracts/test/TestLPToken.sol/TestLPToken.json";
import TestRNGArtifact from "../artifacts/contracts/test/TestRNG.sol/TestRNG.json";
import { GachaHousekeepers, MaidCoin, MockSushiToken, TestLPToken, TestRNG } from "../typechain";
import { expandTo18Decimals } from "./shared/utils/number";
import { getERC20ApprovalDigest, getERC721ApprovalDigest } from "./shared/utils/standard";
import MockSushiTokenArtifact from "../artifacts/contracts/test/MockSushiToken.sol/MockSushiToken.json";

const { deployContract } = waffle;

describe("GachaHousekeepers", () => {
    let maidCoin: MaidCoin;
    let testLPToken: TestLPToken;
    let rng: TestRNG;
    let sushi: MockSushiToken;
    let gachaHousekeepers: GachaHousekeepers;

    const provider = waffle.provider;
    const [admin, other] = provider.getWallets();

    beforeEach(async () => {

        maidCoin = await deployContract(
            admin,
            MaidCoinArtifact,
            []
        ) as MaidCoin;

        testLPToken = await deployContract(
            admin,
            TestLPTokenArtifact,
            []
        ) as TestLPToken;

        rng = await deployContract(
            admin,
            TestRNGArtifact,
            []
        ) as TestRNG;

        sushi = await deployContract(
            admin,
            MockSushiTokenArtifact,
            []
        ) as MockSushiToken;

        gachaHousekeepers = await deployContract(
            admin,
            GachaHousekeepersArtifact,
            [maidCoin.address, testLPToken.address, rng.address, sushi.address]
        ) as GachaHousekeepers;
    })

    context("new GachaHousekeepers", async () => {
        it("name, symbol, DOMAIN_SEPARATOR, PERMIT_TYPEHASH", async () => {
            const name = await gachaHousekeepers.name()
            expect(name).to.eq("MaidCoin Gacha Housekeepers")
            expect(await gachaHousekeepers.symbol()).to.eq("GHSKP")
            expect(await gachaHousekeepers.DOMAIN_SEPARATOR()).to.eq(
                keccak256(
                    defaultAbiCoder.encode(
                        ["bytes32", "bytes32", "bytes32", "uint256", "address"],
                        [
                            keccak256(
                                toUtf8Bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                            ),
                            keccak256(toUtf8Bytes(name)),
                            keccak256(toUtf8Bytes("1")),
                            31337,
                            gachaHousekeepers.address
                        ]
                    )
                )
            )
            expect(await gachaHousekeepers.PERMIT_TYPEHASH()).to.eq(
                keccak256(toUtf8Bytes("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)"))
            )
        })

        it("changeLPTokenToHousekeeperPower", async () => {
            expect(await gachaHousekeepers.lpTokenToHousekeeperPower()).to.eq(BigNumber.from(1))
            await expect(gachaHousekeepers.changeLPTokenToHousekeeperPower(BigNumber.from(2)))
                .to.emit(gachaHousekeepers, "ChangeLPTokenToHousekeeperPower")
                .withArgs(BigNumber.from(2))
            expect(await gachaHousekeepers.lpTokenToHousekeeperPower()).to.eq(BigNumber.from(2))
        })

        it("mint", async () => {

            const id = BigNumber.from(0);

            await maidCoin.approve(gachaHousekeepers.address, expandTo18Decimals(1));
            await expect(gachaHousekeepers.mint())
                .to.emit(gachaHousekeepers, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)
            console.log((await gachaHousekeepers.powerOf(id)).toString());
            expect(await gachaHousekeepers.totalSupply()).to.eq(BigNumber.from(1))
            expect(await gachaHousekeepers.tokenURI(id)).to.eq(`https://api.maidcoin.org/gachahousekeepers/${id}`)
        })

        it("mint with permit", async () => {

            const id = BigNumber.from(0);

            const nonce = await maidCoin.nonces(admin.address)
            const deadline = constants.MaxUint256
            const digest = await getERC20ApprovalDigest(
                maidCoin,
                { owner: admin.address, spender: gachaHousekeepers.address, value: expandTo18Decimals(1) },
                nonce,
                deadline
            )

            const { v, r, s } = ecsign(Buffer.from(digest.slice(2), "hex"), Buffer.from(admin.privateKey.slice(2), "hex"))

            await expect(gachaHousekeepers.mintWithPermit(deadline, v, r, s))
                .to.emit(gachaHousekeepers, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)
            console.log((await gachaHousekeepers.powerOf(id)).toString());
            expect(await gachaHousekeepers.totalSupply()).to.eq(BigNumber.from(1))
            expect(await gachaHousekeepers.tokenURI(id)).to.eq(`https://api.maidcoin.org/gachahousekeepers/${id}`)
        })

        it("support, powerOf", async () => {

            const id = BigNumber.from(0);
            const token = BigNumber.from(100);

            await testLPToken.mint(admin.address, token);
            await testLPToken.approve(gachaHousekeepers.address, token);

            await maidCoin.approve(gachaHousekeepers.address, expandTo18Decimals(1));
            await expect(gachaHousekeepers.mint())
                .to.emit(gachaHousekeepers, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)
            console.log((await gachaHousekeepers.powerOf(id)).toString());
            await expect(gachaHousekeepers.support(id, token))
                .to.emit(gachaHousekeepers, "Support")
                .withArgs(id, token)
        })

        it("desupport, powerOf", async () => {

            const id = BigNumber.from(0);
            const token = BigNumber.from(100);

            await testLPToken.mint(admin.address, token);
            await testLPToken.approve(gachaHousekeepers.address, token);

            await maidCoin.approve(gachaHousekeepers.address, expandTo18Decimals(1));
            await expect(gachaHousekeepers.mint())
                .to.emit(gachaHousekeepers, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)
            console.log((await gachaHousekeepers.powerOf(id)).toString());
            await expect(gachaHousekeepers.support(id, token))
                .to.emit(gachaHousekeepers, "Support")
                .withArgs(id, token)
            await expect(gachaHousekeepers.desupport(id, token))
                .to.emit(gachaHousekeepers, "Desupport")
                .withArgs(id, token)
        })

        it("permit", async () => {

            const id = BigNumber.from(0);

            await maidCoin.approve(gachaHousekeepers.address, expandTo18Decimals(1));
            await expect(gachaHousekeepers.mint())
                .to.emit(gachaHousekeepers, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)

            const nonce = await gachaHousekeepers.nonces(id)
            const deadline = constants.MaxUint256
            const digest = await getERC721ApprovalDigest(
                gachaHousekeepers,
                { spender: other.address, id },
                nonce,
                deadline
            )

            const { v, r, s } = ecsign(Buffer.from(digest.slice(2), "hex"), Buffer.from(admin.privateKey.slice(2), "hex"))

            await expect(gachaHousekeepers.permit(other.address, id, deadline, v, hexlify(r), hexlify(s)))
                .to.emit(gachaHousekeepers, "Approval")
                .withArgs(admin.address, other.address, id)
            expect(await gachaHousekeepers.getApproved(id)).to.eq(other.address)
            expect(await gachaHousekeepers.nonces(id)).to.eq(BigNumber.from(1))
        })
    })
})
