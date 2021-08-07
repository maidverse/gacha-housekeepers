import hardhat from "hardhat";

async function main() {
    console.log("deploy start")

    const TestLPToken = await hardhat.ethers.getContractFactory("TestLPToken")
    const testLPToken = await TestLPToken.deploy()
    console.log(`TestLPToken address: ${testLPToken.address}`)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
