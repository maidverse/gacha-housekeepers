import { expect } from "chai";
import { ecsign } from "ethereumjs-util";
import { BigNumber, constants } from "ethers";
import { defaultAbiCoder, hexlify, keccak256, toUtf8Bytes } from "ethers/lib/utils";
import { waffle } from "hardhat";
import GachaHousekeeperArtifact from "../artifacts/contracts/GachaHousekeeper.sol/GachaHousekeeper.json";
import MaidCoinArtifact from "../artifacts/contracts/MaidCoin.sol/MaidCoin.json";
import TestLPTokenArtifact from "../artifacts/contracts/test/TestLPToken.sol/TestLPToken.json";
import TestRNGArtifact from "../artifacts/contracts/test/TestRNG.sol/TestRNG.json";
import { GachaHousekeeper, MaidCoin, TestLPToken, TestRNG } from "../typechain";
import { expandTo18Decimals } from "./shared/utils/number";
import { getERC20ApprovalDigest, getERC721ApprovalDigest } from "./shared/utils/standard";

const { deployContract } = waffle;

describe("GachaHousekeeper", () => {
    let maidCoin: MaidCoin;
    let testLPToken: TestLPToken;
    let rng: TestRNG;
    let gachaHousekeeper: GachaHousekeeper;

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

        gachaHousekeeper = await deployContract(
            admin,
            GachaHousekeeperArtifact,
            [maidCoin.address, testLPToken.address, rng.address]
        ) as GachaHousekeeper;
    })

    context("new GachaHousekeeper", async () => {
        it("name, symbol, DOMAIN_SEPARATOR, PERMIT_TYPEHASH", async () => {
            const name = await gachaHousekeeper.name()
            expect(name).to.eq("GachaHousekeeper")
            expect(await gachaHousekeeper.symbol()).to.eq("GHSKP")
            expect(await gachaHousekeeper.DOMAIN_SEPARATOR()).to.eq(
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
                            gachaHousekeeper.address
                        ]
                    )
                )
            )
            expect(await gachaHousekeeper.PERMIT_TYPEHASH()).to.eq(
                keccak256(toUtf8Bytes("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)"))
            )
        })

        it("changeLPTokenToHousekeeperPower", async () => {
            expect(await gachaHousekeeper.lpTokenToHousekeeperPower()).to.eq(BigNumber.from(1))
            await expect(gachaHousekeeper.changeLPTokenToHousekeeperPower(BigNumber.from(2)))
                .to.emit(gachaHousekeeper, "ChangeLPTokenToHousekeeperPower")
                .withArgs(BigNumber.from(2))
            expect(await gachaHousekeeper.lpTokenToHousekeeperPower()).to.eq(BigNumber.from(2))
        })

        it("mint", async () => {

            const id = BigNumber.from(0);

            await maidCoin.approve(gachaHousekeeper.address, expandTo18Decimals(1));
            await expect(gachaHousekeeper.mint())
                .to.emit(gachaHousekeeper, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)
            console.log((await gachaHousekeeper.powerOf(id)).toString());
            expect(await gachaHousekeeper.totalSupply()).to.eq(BigNumber.from(1))
            expect(await gachaHousekeeper.tokenURI(id)).to.eq(`https://api.maidcoin.org/gachahousekeepers/${id}`)
        })

        it("mint with permit", async () => {

            const id = BigNumber.from(0);

            const nonce = await maidCoin.nonces(admin.address)
            const deadline = constants.MaxUint256
            const digest = await getERC20ApprovalDigest(
                maidCoin,
                { owner: admin.address, spender: gachaHousekeeper.address, value: expandTo18Decimals(1) },
                nonce,
                deadline
            )

            const { v, r, s } = ecsign(Buffer.from(digest.slice(2), "hex"), Buffer.from(admin.privateKey.slice(2), "hex"))

            await expect(gachaHousekeeper.mintWithPermit(deadline, v, r, s))
                .to.emit(gachaHousekeeper, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)
            console.log((await gachaHousekeeper.powerOf(id)).toString());
            expect(await gachaHousekeeper.totalSupply()).to.eq(BigNumber.from(1))
            expect(await gachaHousekeeper.tokenURI(id)).to.eq(`https://api.maidcoin.org/gachahousekeepers/${id}`)
        })

        it("support, powerOf", async () => {

            const id = BigNumber.from(0);
            const token = BigNumber.from(100);

            await testLPToken.mint(admin.address, token);
            await testLPToken.approve(gachaHousekeeper.address, token);

            await maidCoin.approve(gachaHousekeeper.address, expandTo18Decimals(1));
            await expect(gachaHousekeeper.mint())
                .to.emit(gachaHousekeeper, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)
            console.log((await gachaHousekeeper.powerOf(id)).toString());
            await expect(gachaHousekeeper.support(id, token))
                .to.emit(gachaHousekeeper, "Support")
                .withArgs(id, token)
        })

        it("desupport, powerOf", async () => {

            const id = BigNumber.from(0);
            const token = BigNumber.from(100);

            await testLPToken.mint(admin.address, token);
            await testLPToken.approve(gachaHousekeeper.address, token);

            await maidCoin.approve(gachaHousekeeper.address, expandTo18Decimals(1));
            await expect(gachaHousekeeper.mint())
                .to.emit(gachaHousekeeper, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)
            console.log((await gachaHousekeeper.powerOf(id)).toString());
            await expect(gachaHousekeeper.support(id, token))
                .to.emit(gachaHousekeeper, "Support")
                .withArgs(id, token)
            await expect(gachaHousekeeper.desupport(id, token))
                .to.emit(gachaHousekeeper, "Desupport")
                .withArgs(id, token)
        })

        it("permit", async () => {

            const id = BigNumber.from(0);

            await maidCoin.approve(gachaHousekeeper.address, expandTo18Decimals(1));
            await expect(gachaHousekeeper.mint())
                .to.emit(gachaHousekeeper, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)

            const nonce = await gachaHousekeeper.nonces(id)
            const deadline = constants.MaxUint256
            const digest = await getERC721ApprovalDigest(
                gachaHousekeeper,
                { spender: other.address, id },
                nonce,
                deadline
            )

            const { v, r, s } = ecsign(Buffer.from(digest.slice(2), "hex"), Buffer.from(admin.privateKey.slice(2), "hex"))

            await expect(gachaHousekeeper.permit(other.address, id, deadline, v, hexlify(r), hexlify(s)))
                .to.emit(gachaHousekeeper, "Approval")
                .withArgs(admin.address, other.address, id)
            expect(await gachaHousekeeper.getApproved(id)).to.eq(other.address)
            expect(await gachaHousekeeper.nonces(id)).to.eq(BigNumber.from(1))
        })
    })
})
