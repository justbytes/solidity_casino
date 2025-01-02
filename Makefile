-include .env

.PHONY: all test deploy build

build :; forge build

test :; forge test

install :; forge install cyfrin/foundry-devops --no-commit && forge install smartcontractkit/chainlink-brownie-contracts --no-commit && forge install foundry-rs/forge-std --no-commit && forge install transmissions11/solmate --no-commit

test-sepolia :; forge test --fork-url $(SEPOLIA_RPC_URL) -vvvv

test-anvil :; forge test --fork-url $(LOCAL_RPC_URL) -vvvv

deploy-sepolia :; @forge script script/DeployRaffle.s.sol --rpc-url $(SEPOLIA_RPC_URL) --account $(SEP_ACCOUNT) --sender $(SEP_SENDER) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-anvil :; @forge script script/DeployRaffle.s.sol --broadcast -vvvv
