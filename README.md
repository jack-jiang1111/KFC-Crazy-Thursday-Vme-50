# KFC Crazy Thursday Smart Contract

This smart contract implements a popular meme from Chinese internet culture: "KFC Crazy Thursday, V me 50." Crazy Thursday refers to a recurring promotion by KFC, which means that every Thursday, KFC offers significant discounts. On this day, KFC also gives out some special coupons, making it quite an exciting promotion with big discounts. For example, a combination of Original Recipe Chicken and Crispy Golden Chicken is only 9.9 yuan.

As a result, every Thursday, people will post in groups or on their social media feeds, writing short essays about their desire to eat KFC, often playing up their situations or being humorous, attempting to get a free meal. Each Thursday, various creative and quirky texts are created, giving rise to the "Crazy Thursday" meme.

In fact, every business, when facing a period of consumer stagnation, will try to come up with special days, offering coupons or promotions to attract more customers. KFC is doing just that.
<p align="center">
  <img src= "https://github.com/jack-jiang1111/KFC-Crazy-Thursday-Vme-50/blob/main/image/VME50.jpg"/>
</p>


## How to Use

Before Thursday, participants can enter the lottery system by paying a small gas fee. Every Thursday, the system will randomly select a winner from the list of participants and transfer all the ETH in the smart contract to the winner.

![DEMO](https://github.com/jack-jiang1111/KFC-Crazy-Thursday-Vme-50/blob/main/image/DEMO.PNG)

## Technology

This smart contract utilizes Chainlink VRF to randomly select a winner and Chainlink Keepers to trigger the lottery function every week. Simply deploy the contract on Thursday, and it will continue running as long as there are sufficient funds in the lottery system and a Chainlink subscription.

## Deployment

1. **Deploy the Contract**: Deploy the contract to the Ethereum network on Thursday.
2. **Enter the Lottery**: Participants enter the lottery by sending a small amount of ETH to the contract.
3. **Random Selection**: Every Thursday, the contract uses Chainlink VRF to randomly select a winner.
4. **Winner Announcement**: The winner receives all the ETH in the contract.

## Prerequisites

- An Ethereum wallet (e.g., MetaMask)
- ETH for gas fees
- A Chainlink subscription

## License

This project is licensed under the MIT License.
