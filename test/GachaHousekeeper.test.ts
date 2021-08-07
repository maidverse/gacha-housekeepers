import { expect } from "chai";
import { ecsign } from "ethereumjs-util";
import { BigNumber, constants } from "ethers";
import { defaultAbiCoder, hexlify, keccak256, toUtf8Bytes } from "ethers/lib/utils";
import { waffle } from "hardhat";
import GachaHousekeeperArtifact from "../artifacts/contracts/GachaHousekeeper.sol/GachaHousekeeper.json";
import TestLPTokenArtifact from "../artifacts/contracts/test/TestLPToken.sol/TestLPToken.json";
import { GachaHousekeeper, TestLPToken } from "../typechain";
import { expandTo18Decimals } from "./shared/utils/number";
import { getERC721ApprovalDigest } from "./shared/utils/standard";

const { deployContract } = waffle;

describe("GachaHousekeeper", () => {
    let testLPToken: TestLPToken;
    let gachaHousekeeper: GachaHousekeeper;

    const provider = waffle.provider;
    const [admin, other] = provider.getWallets();

    beforeEach(async () => {

        testLPToken = await deployContract(
            admin,
            TestLPTokenArtifact,
            []
        ) as TestLPToken;

        gachaHousekeeper = await deployContract(
            admin,
            GachaHousekeeperArtifact,
            [testLPToken.address]
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

        it("mint, powerOf", async () => {

            const id = BigNumber.from(0);
            const power = BigNumber.from(12);

            await expect(gachaHousekeeper.mint(power))
                .to.emit(gachaHousekeeper, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)
            expect(await gachaHousekeeper.powerOf(id)).to.eq(power)
            expect(await gachaHousekeeper.totalSupply()).to.eq(BigNumber.from(1))
            expect(await gachaHousekeeper.tokenURI(id)).to.eq(`https://api.maidcoin.org/gachahousekeeper/${id}`)
        })

        it("support, powerOf", async () => {

            const id = BigNumber.from(0);
            const power = BigNumber.from(12);
            const token = BigNumber.from(100);

            await testLPToken.mint(admin.address, token);
            await testLPToken.approve(gachaHousekeeper.address, token);

            await expect(gachaHousekeeper.mint(power))
                .to.emit(gachaHousekeeper, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)
            await expect(gachaHousekeeper.support(id, token))
                .to.emit(gachaHousekeeper, "Support")
                .withArgs(id, token)
            expect(await gachaHousekeeper.powerOf(id)).to.eq(power.add(token.mul(await gachaHousekeeper.lpTokenToHousekeeperPower()).div(expandTo18Decimals(1))))
        })

        it("desupport, powerOf", async () => {

            const id = BigNumber.from(0);
            const power = BigNumber.from(12);
            const token = BigNumber.from(100);

            await testLPToken.mint(admin.address, token);
            await testLPToken.approve(gachaHousekeeper.address, token);

            await expect(gachaHousekeeper.mint(power))
                .to.emit(gachaHousekeeper, "Transfer")
                .withArgs(constants.AddressZero, admin.address, id)
            await expect(gachaHousekeeper.support(id, token))
                .to.emit(gachaHousekeeper, "Support")
                .withArgs(id, token)
            expect(await gachaHousekeeper.powerOf(id)).to.eq(power.add(token.mul(await gachaHousekeeper.lpTokenToHousekeeperPower()).div(expandTo18Decimals(1))))
            await expect(gachaHousekeeper.desupport(id, token))
                .to.emit(gachaHousekeeper, "Desupport")
                .withArgs(id, token)
            expect(await gachaHousekeeper.powerOf(id)).to.eq(power)
        })

        it("permit", async () => {

            const id = BigNumber.from(0);

            await expect(gachaHousekeeper.mint(BigNumber.from(12)))
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
