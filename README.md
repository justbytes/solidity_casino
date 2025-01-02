## Solidity Lottery

A project built with foundry that utilizes Chainlink VRF and Chainlink Automation to create a decentralized lottery.

# Running locally

If you want to deploy the contract to a local anvil network you need to change make a change to the VRFCoordinatorV2_5Mock.sol file. Open the file then ctl + click the SubscriptionAPI to navigate to the file. Then find the createSubscribtion function and remove the `-1` from the block.number.

subId should look like this

```
subId = uint256(keccak256(abi.encodePacked(msg.sender, blockhash(block.number), address(this), currentSubNonce)));
```

## Deployed Contract

```
Sepolia: 0xd27595a93b73f0Af6A4AEe5d49bcB4994CA46C9D
```
