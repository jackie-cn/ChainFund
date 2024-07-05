-include .env

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
DEFAULT_ANVIL_RPC_URL :=  http://127.0.0.1:8545
# Clean the repo
clean  :; forge clean

# Remove modules
# 
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# I dont use the lastest openzeppelin version because they use solidity^V0.8.20, maybe not work in other chian,such as bsc
install :; forge install smartcontractkit/chainlink-brownie-contracts --no-commit && forge install openzeppelin/openzeppelin-contracts@v4.9.4 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test

coverage :; forge coverage --report debug > coverage-report.txt

coveragetofile :; forge coverage --report debug > coverage-report.txt

snapshot :; forge snapshot

format :; forge fmt

deploy-anvil:
	forge script ./script/DeployCrowedFund.s.sol --rpc-url ${DEFAULT_ANVIL_RPC_URL} --private-key ${DEFAULT_ANVIL_KEY} --broadcast

deploy-verify-speolia:
	forge script ./script/DeployCrowdfundingPlatform.s.sol --rpc-url ${SPEOLIA_RPC_URL} --private-key ${DEPLOY_PRIVATE_KEY} --broadcast --verify -vvvv --legacy --etherscan-api-key ${ETH_API_KEY}

run-onchainTestScript:
	forge script ./script/OnchainInteract.s.sol --rpc-url ${SPEOLIA_RPC_URL} --broadcast -vvvv --legacy