const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")


!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Raffle Unit Tests", function () {
          let raffle, raffleContract, vrfCoordinatorV2Mock, interval, player // , deployer
          let fundAmount = ethers.utils.parseEther("0.1")
          beforeEach(async () => {
              accounts = await ethers.getSigners() // could also do with getNamedAccounts
              //   deployer = accounts[0]
              player = accounts[1]
              await deployments.fixture(["mocks", "raffle"]) // Deploys modules with the tags "mocks" and "raffle"
              vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock") // Returns a new connection to the VRFCoordinatorV2Mock contract
              raffleContract = await ethers.getContract("Raffle") // Returns a new connection to the Raffle contract
              raffle = raffleContract.connect(player) // Returns a new instance of the Raffle contract connected to player
              interval = await raffle.getInterval()
          })
          

          describe("constructor", function () {
              it("initializes the raffle correctly", async () => {
                  // Ideally, we'd separate these out so that only 1 assert per "it" block
                  // And ideally, we'd make this check everything
                  const raffleState = (await raffle.getRaffleState()).toString()
                  // Comparisons for Raffle initialization:
                  assert.equal(raffleState, "0")
                  assert.equal(
                      interval.toString(),
                      networkConfig[network.config.chainId]["keepersUpdateInterval"]
                  )
              })
          })

          describe("enterRaffle", function () {
              it("records player when they enter", async () => {
                  raffle = raffleContract.connect(accounts[1])
                  await raffle.enterRaffle()
                  const contractPlayer = await raffle.getPlayer(0)
                  assert.equal(accounts[1].address, contractPlayer)
              })
              it("Reenter a raffle", async () => {
                raffle = raffleContract.connect(accounts[1])
                //console.log("what's raffle?",raffle)
                console.log("what's account",accounts[1].address)
                //console.log("what's 
                console.log("what's the version before?",await raffle.gethasEntered(accounts[1].address));
                await raffle.enterRaffle();
                console.log("what's the version after?",await raffle.gethasEntered(accounts[1].address));
                await expect(raffle.enterRaffle()).to.be.revertedWith( // is reverted as raffle is calculating
                    "Raffle__PlayerHasEntered()"
                )
            })
              it("emits event on enter", async () => {
                  player = accounts[3]
                  raffle = raffleContract.connect(player)
                  await expect(raffle.enterRaffle()).to.emit( // emits RaffleEnter event if entered to index player(s) address
                      raffle,
                      "RaffleEnter"
                  )
              })
              it("doesn't allow entrance/fund when raffle is calculating", async () => {
                  raffle = raffleContract.connect(accounts[4])
                  await raffle.enterRaffle()
                  await raffle.fund({value: 1000000000000})
                  // for a documentation of the methods below, go here: https://hardhat.org/hardhat-network/reference
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  // we pretend to be a keeper for a second
                  await raffle.performUpkeep([]) // changes the state to calculating for our comparison below
                  raffle = raffleContract.connect(accounts[5])
                  await expect(raffle.enterRaffle()).to.be.revertedWith( // is reverted as raffle is calculating
                      "Raffle__RaffleNotOpen"
                  )
                  await expect(raffle.fund()).to.be.revertedWith( // is reverted as raffle is calculating
                    "Raffle__RaffleNotOpen"
                )
              })
              it("Test the number of players ", async () => {
                assert.equal(await raffle.getNumberOfPlayers(), 0)
                raffle = raffleContract.connect(accounts[1])
                await raffle.enterRaffle()
                assert.equal(await raffle.getNumberOfPlayers(), 1)
                raffle = raffleContract.connect(accounts[2])
                await raffle.enterRaffle()
                assert.equal(await raffle.getNumberOfPlayers(), 2)
                raffle = raffleContract.connect(accounts[3])
                await raffle.enterRaffle()
                assert.equal(await raffle.getNumberOfPlayers(), 3)
                raffle = raffleContract.connect(accounts[4])
                await raffle.enterRaffle()
                assert.equal(await raffle.getNumberOfPlayers(), 4)
            })
          })
          describe("fundRaffle", function () {
            it("check how much they fund", async () => {
                raffle = raffleContract.connect(accounts[19])
                await raffle.fund({value: fundAmount})
                const endingBalance = await raffleContract.provider.getBalance(raffleContract.address)
                // the max number represent in javascript is 2^53, but a typical number in solidity is 2^256,
                // so we either use string to get this big number
                assert.equal((fundAmount).toString(),endingBalance.toString());
            })
        })
          describe("checkUpkeep", function () {
              it("returns false if people haven't sent any ETH", async () => {
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const { upkeepNeeded } = await raffle.callStatic.checkUpkeep("0x") // upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers)
                  assert(!upkeepNeeded)
              })
              it("returns false if raffle isn't open", async () => {
                 raffle = raffleContract.connect(accounts[6])
                  await raffle.enterRaffle()
                  await raffle.fund({value: 100000000000})
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  await raffle.performUpkeep([]) // changes the state to calculating
                  const raffleState = await raffle.getRaffleState() // stores the new state
                  const { upkeepNeeded } = await raffle.callStatic.checkUpkeep("0x") // upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers)
                  assert.equal(raffleState.toString() == "1", upkeepNeeded == false)
              })
              it("returns false if enough time hasn't passed", async () => {
                  raffle = raffleContract.connect(accounts[7])
                  await raffle.enterRaffle()
                  await network.provider.send("evm_increaseTime", [interval.toNumber() - 5]) // use a higher number here if this test fails
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const { upkeepNeeded } = await raffle.callStatic.checkUpkeep("0x") // upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers)
                  assert(!upkeepNeeded)
              })
              it("returns true if enough time has passed, has players, eth, and is open", async () => {
                 raffle = raffleContract.connect(accounts[8])
                  await raffle.enterRaffle()
                  await raffle.fund({value: 100000000000})
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const { upkeepNeeded } = await raffle.callStatic.checkUpkeep("0x") // upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers)
                  assert(upkeepNeeded)
              })
          })

          describe("performUpkeep", function () {
              it("can only run if checkupkeep is true", async () => {
                  raffle = raffleContract.connect(accounts[9])
                  await raffle.enterRaffle()
                  await raffle.fund({value: 100000000000})
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const tx = await raffle.performUpkeep("0x") 
                  assert(tx)
              })
              it("reverts if checkup is false", async () => {
                  await expect(raffle.performUpkeep("0x")).to.be.revertedWith( 
                      "Raffle__UpkeepNotNeeded"
                  )
              })
              it("updates the raffle state and emits a requestId", async () => {
                  // Too many asserts in this test!
                  raffle = raffleContract.connect(accounts[10])
                  await raffle.enterRaffle()
                  await raffle.fund({value: 100000000000})
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
                  const txResponse = await raffle.performUpkeep("0x") // emits requestId
                  const txReceipt = await txResponse.wait(1) // waits 1 block
                  const raffleState = await raffle.getRaffleState() // updates state
                  const requestId = txReceipt.events[1].args.requestId
                  assert(requestId.toNumber() > 0)
                  assert(raffleState == 1) // 0 = open, 1 = calculating
              })
          })
          describe("fulfillRandomWords", function () {
              beforeEach(async () => {
                  raffle = raffleContract.connect(accounts[11])
                  await raffle.enterRaffle()
                  await raffle.fund({value: 100000000000})
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.request({ method: "evm_mine", params: [] })
              })
              it("can only be called after performupkeep", async () => {
                  await expect(
                      vrfCoordinatorV2Mock.fulfillRandomWords(0, raffle.address) // reverts if not fulfilled
                  ).to.be.revertedWith("nonexistent request")
                  await expect(
                      vrfCoordinatorV2Mock.fulfillRandomWords(1, raffle.address) // reverts if not fulfilled
                  ).to.be.revertedWith("nonexistent request")
              })
              it("Check get num words", async() =>{
                  assert(raffle.getNumWords(),1);
              })
              it("Check request confirmation", async()=>{
                  assert(raffle.getRequestConfirmations(),3);
              })

            // This test is too big...
            // This test simulates users entering the raffle and wraps the entire functionality of the raffle
            // inside a promise that will resolve if everything is successful.
            // An event listener for the WinnerPicked is set up
            // Mocks of chainlink keepers and vrf coordinator are used to kickoff this winnerPicked event
            // All the assertions are done once the WinnerPicked event is fired
              it("picks a winner, resets, and sends money", async () => {
                  const additionalEntrances = 3 // to test
                  const startingIndex = 12
                  let startingBalance
                  for (let i = startingIndex; i < startingIndex + additionalEntrances; i++) { // i = 2; i < 5; i=i+1
                      raffle = raffleContract.connect(accounts[i]) // Returns a new instance of the Raffle contract connected to player 
                      await raffle.enterRaffle()
                  }
                  // put value as a string since javascript doesn't support number over 53 bits
                  await raffle.fund({value: "1000000000000000000"})
                  const startingTimeStamp = await raffle.getLastTimeStamp() // stores starting timestamp (before we fire our event)

                  // This will be more important for our staging tests...
                  await new Promise(async (resolve, reject) => {
                      raffle.once("WinnerPicked", async () => { // event listener for WinnerPicked
                          console.log("WinnerPicked event fired!")
                          // assert throws an error if it fails, so we need to wrap
                          // it in a try/catch so that the promise returns event
                          // if it fails.
                          try {
                              // Now lets get the ending values...
                              const recentWinner = await raffle.getRecentWinner()
                              const raffleState = await raffle.getRaffleState()
                              const winnerBalance = await accounts[12].getBalance()
                              const endingTimeStamp = await raffle.getLastTimeStamp()
                              await expect(raffle.getPlayer(0)).to.be.reverted
                              // Comparisons to check if our ending values are correct:
                              assert.equal(recentWinner.toString(), accounts[12].address)
                              assert.equal(raffleState, 0)
                              assert.equal(
                                  winnerBalance.toString(), 
                                  startingBalance // startingBalance + ( (raffleEntranceFee * additionalEntrances) + raffleEntranceFee )
                                      .add(
                                        await raffle.getWinningMoney()
                                      )
                                      .toString()
                              )
                              assert(endingTimeStamp > startingTimeStamp)
                              resolve() // if try passes, resolves the promise 
                          } catch (e) { 
                              reject(e) // if try fails, rejects the promise
                          }
                      })

                      // kicking off the event by mocking the chainlink keepers and vrf coordinator
                      try {
                        const tx = await raffle.performUpkeep("0x")
                        const txReceipt = await tx.wait(1)
                        startingBalance = await accounts[12].getBalance()
                        await vrfCoordinatorV2Mock.fulfillRandomWords(
                            txReceipt.events[1].args.requestId,
                            raffle.address
                        )
                      } catch (e) {
                          reject(e)
                      }
                  })
              })
          })
      })

      // run a single test: npx hardhat test --grep fulfill