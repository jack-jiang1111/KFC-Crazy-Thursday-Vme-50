const { ethers } = require("hardhat")

async function main() {
    const raffle = await ethers.getContract("Raffle")
    const accounts = await ethers.getSigners()

    // Simulate multiple accounts entering the raffle
    for (let i = 0; i < 5; i++) {
        const account = accounts[i]
        console.log(`Account ${i+1}: ${account.address} is entering the raffle`)
        const tx = await raffle.connect(account).enterRaffle() // Adjust the amount as needed
        //let winner_money = await raffle.connect(account).getWinningMoney();
        //console.log(winner_money)
        await tx.wait()
    }

    console.log("All accounts have entered the raffle")

    // Simulate multiple accounts funding the raffle
    for (let i = 5; i < 8; i++) {
        const account = accounts[i]
        console.log(`Account ${i+1}: ${account.address} is funding the raffle`)
        const tx = await raffle.connect(account).fund({ value: ethers.utils.parseEther("1") }) // Adjust the amount as needed
        await tx.wait()
    }
    
    console.log("All accounts have funded the raffle")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
