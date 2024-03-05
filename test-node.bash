#!/usr/bin/env bash

set -e

NITRO_NODE_VERSION=offchainlabs/nitro-node:v2.1.1-e9d8842-dev
BLOCKSCOUT_VERSION=offchainlabs/blockscout:v1.0.0-c8db5b1
NODE_PATH="/home/celestia/bridge/"
SUCCINCT_REPO_DIR="./succinctx"
SUCCINCT_REPO_URL="https://github.com/succinctlabs/succinctx.git"
BLOBSTREAMX_REPO_DIR="./blobstreamx"
BLOBSTREAMX_REPO_ULR="https://github.com/succinctlabs/blobstreamx.git"
SUCCINCTX_DEPLOYER="da6ed55cb2894ac2c9c10209c09de8e8b9d109b910338d5bf3d747a7e1fc9eb9"
GUARDIAN="0x966e6f22781EF6a6A82BBB4DB3df8E225DfD9488"
CREATE2_SALT=0x7394a2a9e89e7eb9b501f23fea14f96d29ec5dda681e971ed0f042260e447a37
CHAIN_ID=1337
L1_RPC="http://localhost:8545"
ETHERSCAN_API_KEY=''
SUCCINCT_GATEWAY_1337="0xcfeb9268919890ff929006d4a5a748bcb4c505c5"
NEXT_HEADER_VERIFIER="0xf3D1B74d3e062aC91a3b47AC16Ed443034e783cF"
HEADER_RANGE_VERIFIER="0xa4f573595dab0ea9a2c7A81bF08bb170cC6F6e35"

### BlobstreamX

LOCAL_PROVE_MODE=true
LOCAL_RELAY_MODE=false
TENDERMINT_RPC_URL="http://rpc-mocha.pops.one:26657"
SUCCINCT_RPC_URL=local
SUCCINCT_API_KEY="" # Can leave blank for local proving
POST_DELAY_MINUTES=1
# WRAPPER_BINARY=
BLOBSTREAMX_ADDR="0x8FFd044EdDD4B9d04a4a54Ca5a2b0EBb556Ea64c"
NEXT_HEADER_FUNCTION_ID=0xb48af5deaef6d65e4259089cf49641eb8b95163cee15edfee93e27bf0201aef9 # Deployed function id
HEADER_RANGE_FUNCTION_ID=0x5b9022ceb55eaba374a49d5a2ad47104a5d3fb9d518d03724b750af0c65b27ea # Deployed function id of header range
#Next header function id
PROVE_BINARY_0xb48af5deaef6d65e4259089cf49641eb8b95163cee15edfee93e27bf0201aef9="./artifacts/header_range/header_range"
#Header range function id
PROVE_BINARY_0x5b9022ceb55eaba374a49d5a2ad47104a5d3fb9d518d03724b750af0c65b27ea="./artifacts/next_header/next_header"
WRAPPER_BINARY="./artifacts/verifier-build"

mydir=`dirname $0`
cd "$mydir"

if ! which docker-compose > /dev/null; then
    echo == Error! docker-compose not installed
    echo please install docker-compose and have it in PATH
    echo see https://docs.docker.com/compose/install/
    exit 1
fi

if [[ $# -gt 0 ]] && [[ $1 == "script" ]]; then
    shift
    docker-compose run scripts "$@"
    exit $?
fi

num_volumes=`docker volume ls --filter label=com.docker.compose.project=nitro-testnode -q | wc -l`

if [[ $num_volumes -eq 0 ]]; then
    force_init=true
else
    force_init=false
fi

run=true
force_build=false
validate=false
detach=false
blockscout=false
tokenbridge=true
l3node=false
consensusclient=false
redundantsequencers=0
dev_build_nitro=false
dev_build_blockscout=false
batchposters=1
devprivkey=b6b15c8cb491557369f3c7d2c287b053eb229daa9c22138887752191c9520659
l1chainid=1337
while [[ $# -gt 0 ]]; do
    case $1 in
        --init)
            if ! $force_init; then
                echo == Warning! this will remove all previous data
                read -p "are you sure? [y/n]" -n 1 response
                if [[ $response == "y" ]] || [[ $response == "Y" ]]; then
                    force_init=true
                    echo
                else
                    exit 0
                fi
            fi
            shift
            ;;
        --dev)
            shift
            if [[ $# -eq 0 || $1 == -* ]]; then
                # If no argument after --dev, set both flags to true
                dev_build_nitro=true
                dev_build_blockscout=true
            else
                while [[ $# -gt 0 && $1 != -* ]]; do
                    if [[ $1 == "nitro" ]]; then
                        dev_build_nitro=true
                    elif [[ $1 == "blockscout" ]]; then
                        dev_build_blockscout=true
                    fi
                    shift
                done
            fi
            ;;
        --build)
            force_build=true
            shift
            ;;
        --validate)
            validate=true
            shift
            ;;
        --blockscout)
            blockscout=true
            shift
            ;;
        --no-tokenbridge)
            tokenbridge=false
            shift
            ;;
        --no-run)
            run=false
            shift
            ;;
        --detach)
            detach=true
            shift
            ;;
        --batchposters)
            batchposters=$2
            if ! [[ $batchposters =~ [0-3] ]] ; then
                echo "batchposters must be between 0 and 3 value:$batchposters."
                exit 1
            fi
            shift
            shift
            ;;
        --pos)
            consensusclient=true
            l1chainid=32382
            shift
            ;;
        --l3node)
            l3node=true
            shift
            ;;
        --redundantsequencers)
            redundantsequencers=$2
            if ! [[ $redundantsequencers =~ [0-3] ]] ; then
                echo "redundantsequencers must be between 0 and 3 value:$redundantsequencers."
                exit 1
            fi
            shift
            shift
            ;;
        *)
            echo Usage: $0 \[OPTIONS..]
            echo        $0 script [SCRIPT-ARGS]
            echo
            echo OPTIONS:
            echo --build:           rebuild docker images
            echo --dev:             build nitro and blockscout dockers from source \(otherwise - pull docker\)
            echo --init:            remove all data, rebuild, deploy new rollup
            echo --pos:             l1 is a proof-of-stake chain \(using prysm for consensus\)
            echo --validate:        heavy computation, validating all blocks in WASM
            echo --batchposters:    batch posters [0-3]
            echo --redundantsequencers redundant sequencers [0-3]
            echo --detach:          detach from nodes after running them
            echo --blockscout:      build or launch blockscout
            echo --no-tokenbridge:  don\'t build or launch tokenbridge
            echo --no-run:          does not launch nodes \(usefull with build or init\)
            echo
            echo script runs inside a separate docker. For SCRIPT-ARGS, run $0 script --help
            exit 0
    esac
done

if $force_init; then
  force_build=true
fi

if $dev_build_nitro; then
  if [[ "$(docker images -q nitro-node-dev:latest 2> /dev/null)" == "" ]]; then
    force_build=true
  fi
fi

if $dev_build_blockscout; then
  if [[ "$(docker images -q blockscout:latest 2> /dev/null)" == "" ]]; then
    force_build=true
  fi
fi

NODES="sequencer"
INITIAL_SEQ_NODES="sequencer"

if [ $redundantsequencers -gt 0 ]; then
    NODES="$NODES sequencer_b"
    INITIAL_SEQ_NODES="$INITIAL_SEQ_NODES sequencer_b"
fi
if [ $redundantsequencers -gt 1 ]; then
    NODES="$NODES sequencer_c"
fi
if [ $redundantsequencers -gt 2 ]; then
    NODES="$NODES sequencer_d"
fi

if [ $batchposters -gt 0 ]; then
    NODES="$NODES poster"
fi
if [ $batchposters -gt 1 ]; then
    NODES="$NODES poster_b"
fi
if [ $batchposters -gt 2 ]; then
    NODES="$NODES poster_c"
fi


if $validate; then
    NODES="$NODES validator"
else
    NODES="$NODES staker-unsafe"
fi
if $l3node; then
    NODES="$NODES l3node"
fi
if $blockscout; then
    NODES="$NODES blockscout"
fi
if $force_build; then
  echo == Building..
  if $dev_build_nitro; then
    if ! [ -n "${NITRO_SRC+set}" ]; then
        NITRO_SRC=`dirname $PWD`
    fi
    if ! grep ^FROM "${NITRO_SRC}/Dockerfile" | grep nitro-node 2>&1 > /dev/null; then
        echo nitro source not found in "$NITRO_SRC"
        echo execute from a sub-directory of nitro or use NITRO_SRC environment variable
        exit 1
    fi
    docker build "$NITRO_SRC" -t nitro-node-dev --target nitro-node-dev
  fi
  if $dev_build_blockscout; then
    if $blockscout; then
      docker build blockscout -t blockscout -f blockscout/docker/Dockerfile
    fi
  fi
  LOCAL_BUILD_NODES=scripts
  if $tokenbridge; then
    LOCAL_BUILD_NODES="$LOCAL_BUILD_NODES tokenbridge"
  fi
  docker-compose build --no-rm $LOCAL_BUILD_NODES
fi

if $dev_build_nitro; then
  docker tag nitro-node-dev:latest nitro-node-dev-testnode
else
  docker pull $NITRO_NODE_VERSION
  docker tag $NITRO_NODE_VERSION nitro-node-dev-testnode
fi

if $dev_build_blockscout; then
  if $blockscout; then
    docker tag blockscout:latest blockscout-testnode
  fi
else
  if $blockscout; then
    docker pull $BLOCKSCOUT_VERSION
    docker tag $BLOCKSCOUT_VERSION blockscout-testnode
  fi
fi

if $force_build; then
    docker-compose build --no-rm $NODES scripts
fi

# Helper method that waits for a given URL to be up. Can't use
# cURL's built-in retry logic because connection reset errors
# are ignored unless you're using a very recent version of cURL
function wait_up {
  echo -n "Waiting for $1 to come up..."
  i=0
  until curl -s -f -o /dev/null "$1"
  do
    echo -n .
    sleep 0.25

    ((i=i+1))
    if [ "$i" -eq 600 ]; then
      echo " Timeout!" >&2
      exit 1
    fi
  done
  echo "Done!"
}

if $force_init; then
    echo == Removing old data..
    docker-compose down
    leftoverContainers=`docker container ls -a --filter label=com.docker.compose.project=nitro-testnode -q | xargs echo`
    if [ `echo $leftoverContainers | wc -w` -gt 0 ]; then
        docker rm $leftoverContainers
    fi
    docker volume prune -f --filter label=com.docker.compose.project=nitro-testnode
    leftoverVolumes=`docker volume ls --filter label=com.docker.compose.project=nitro-testnode -q | xargs echo`
    if [ `echo $leftoverVolumes | wc -w` -gt 0 ]; then
        docker volume rm $leftoverVolumes
    fi

    echo == Generating l1 keys
    docker-compose run scripts write-accounts
    docker-compose run --entrypoint sh geth -c "echo passphrase > /datadir/passphrase"
    docker-compose run --entrypoint sh geth -c "chown -R 1000:1000 /keystore"
    docker-compose run --entrypoint sh geth -c "chown -R 1000:1000 /config"

    echo == Bringing up L1
    if $consensusclient; then
      echo == Writing configs
      docker-compose run scripts write-geth-genesis-config

      echo == Writing configs
      docker-compose run scripts write-prysm-config

      echo == Initializing go-ethereum genesis configuration
      docker-compose run geth init --datadir /datadir/ /config/geth_genesis.json

      echo == Starting geth
      docker-compose up -d geth

      echo == Creating prysm genesis
      docker-compose up create_beacon_chain_genesis

      echo == Running prysm
      docker-compose up -d prysm_beacon_chain
      docker-compose up -d prysm_validator
    else
      docker-compose up -d geth
    fi

    echo == Funding validator and sequencer
    docker-compose run scripts send-l1 --ethamount 1000 --to validator --wait
    docker-compose run scripts send-l1 --ethamount 1000 --to sequencer --wait

    echo == Funding Orchestrator, Relayer, and Create2 signer
    docker-compose run scripts send-l1 --ethamount 1000 --to address_0x3fab184622dc19b6109349b94811493bf2a45362 --wait
    curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_sendRawTransaction","params":["0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222"],"id":1}' $L1_RPC
    docker-compose run scripts send-l1 --ethamount 1000 --to address_0x95359c3348e189ef7781546e6E13c80230fC9fB5 --wait
    docker-compose run scripts send-l1 --ethamount 1000 --to address_0x966e6f22781EF6a6A82BBB4DB3df8E225DfD9488 --wait

    echo == create l1 traffic
    docker-compose run scripts send-l1 --ethamount 1000 --to user_l1user --wait
    docker-compose run scripts send-l1 --ethamount 0.0001 --from user_l1user --to user_l1user_b --wait --delay 500 --times 500 > /dev/null &

    echo == Cloning SuccinctX

    # Check if the directory exists
    if [ ! -d "$SUCCINCT_REPO_DIR" ]; then
        echo "Repository directory does not exist. Cloning repository..."
        git clone $SUCCINCT_REPO_URL $SUCCINCT_REPO_DIR
    else
        echo "Repository directory already exists. Skipping clone..."
    fi

    echo == Deploying SuccinctX Contracts

    STARTING_DIR=$(echo "$PWD")

    cd ${SUCCINCT_REPO_DIR}/contracts && forge install && forge build


    WALLET_TYPE=PRIVATE_KEY PRIVATE_KEY=$SUCCINCTX_DEPLOYER GUARDIAN=$GUARDIAN CREATE2_SALT=0x7394a2a9e89e7eb9b501f23fea14f96d29ec5dda681e971ed0f042260e447a37 SUCCINCT_FEE_VAULT_1337=$GUARDIAN SUCCINCT_FEE_VAULT=$GUARDIAN PROVER_1337=$GUARDIAN PROVER=$GUARDIAN RPC_1337=$L1_RPC ETHERSCAN_API_KEY_1337=$ETHERSCAN_API_KEY ./script/deploy.sh "SuccinctGateway" "1337"

    cd $STARTING_DIR

    echo == Setting FunctionVerifier

    cd ./verifiers/next_header/
    forge create src/FunctionVerifier.sol:FunctionVerifier --private-key $SUCCINCTX_DEPLOYER --rpc-url $L1_RPC
    cast send $SUCCINCT_GATEWAY_1337 "registerFunction(address,address,bytes32)" 0x0000000000000000000000000000000000000000 $NEXT_HEADER_VERIFIER 0x4df6a4c89c20a93bf3668adcc38ea661d30aa3eca7dee9c4ee9fe37dd8697a1c --private-key $SUCCINCTX_DEPLOYER --rpc-url $L1_RPC

    cd $STARTING_DIR

    cd ./verifiers/header_range/
    forge create src/FunctionVerifier.sol:FunctionVerifier --private-key $SUCCINCTX_DEPLOYER --rpc-url $L1_RPC
    cast send $SUCCINCT_GATEWAY_1337 "registerFunction(address,address,bytes32)" 0x0000000000000000000000000000000000000000 $HEADER_RANGE_VERIFIER 0xfe3236aade450ae5075091484865c29ccae6d9bce6079e83e83ac980e6a49b04 --private-key $SUCCINCTX_DEPLOYER --rpc-url $L1_RPC

    cd $STARTING_DIR

    echo == Deploying BlobstreamX

    if [ ! -d "$BLOBSTREAMX_REPO_DIR" ]; then
        echo "Repository directory does not exist. Cloning repository..."
        git clone $BLOBSTREAMX_REPO_ULR $BLOBSTREAMX_REPO_DIR
    else
        echo "Repository directory already exists. Skipping clone..."
    fi

    cd ${BLOBSTREAMX_REPO_DIR}/contracts && forge install

    DEPLOY=true PRIVATE_KEY=$SUCCINCTX_DEPLOYER RPC_URL=$L1_RPC CREATE2_SALT=0x7394a2a9e89e7eb9b501f23fea14f96d29ec5dda681e971ed0f042260e447a37 GUARDIAN_ADDRESS=$GUARDIAN GATEWAY_ADDRESS=$SUCCINCT_GATEWAY_1337  GENESIS_HEIGHT=1000 GENESIS_HEADER="93A5FE44AD4EBEEBCDFFD74ECA367E6E858D9836901CE9E4454A9F1E62B739AF" NEXT_HEADER_FUNCTION_ID=$NEXT_HEADER_FUNCTION_ID HEADER_RANGE_FUNCTION_ID=$HEADER_RANGE_FUNCTION_ID  UPDATE_GATEWAY=false UPDATE_GENESIS_STATE=false UPDATE_FUNCTION_IDS=false forge script script/Deploy.s.sol --rpc-url $L1_RPC --private-key $SUCCINCTX_DEPLOYER --broadcast

    cd ..

    PRIVATE_KEY=$SUCCINCTX_DEPLOYER POST_DELAY_MINUTES=$POST_DELAY_MINUTES CHAIN_ID=$CHAIN_ID WRAPPER_BINARY="./artifacts/verifier-build" PROVE_BINARY_0xb48af5deaef6d65e4259089cf49641eb8b95163cee15edfee93e27bf0201aef9=$PROVE_BINARY_0xb48af5deaef6d65e4259089cf49641eb8b95163cee15edfee93e27bf0201aef9 PROVE_BINARY_0x5b9022ceb55eaba374a49d5a2ad47104a5d3fb9d518d03724b750af0c65b27ea=$PROVE_BINARY_0x5b9022ceb55eaba374a49d5a2ad47104a5d3fb9d518d03724b750af0c65b27ea NEXT_HEADER_FUNCTION_ID=$NEXT_HEADER_FUNCTION_ID HEADER_RANGE_FUNCTION_ID=$HEADER_RANGE_FUNCTION_ID LOCAL_PROVE_MODE=true LOCAL_RELAY_MODE=false SUCCINCT_RPC_URL=local SUCCINCT_API_KEY="" RPC_URL=$L1_RPC TENDERMINT_RPC_URL=$TENDERMINT_RPC_URL CONTRACT_ADDRESS=$BLOBSTREAMX_ADDR cargo run --bin blobstreamx --release

    cd $STARTING_DIR

    # Need to add logic to get circuits and what not, document steps, etc.

    # echo == Bringing up Celestia Devnet
    # docker-compose up -d da
    # wait_up http://localhost:26659/header/1
    # export CELESTIA_NODE_AUTH_TOKEN="$(docker exec da-celestia celestia bridge auth admin --node.store  ${NODE_PATH})"


    # echo == Bringing up Celestia Devnet
    # docker-compose up -d da
    # wait_up http://localhost:26659/header/1
    # export CELESTIA_NODE_AUTH_TOKEN="$(docker exec da-celestia celestia bridge auth admin --node.store  ${NODE_PATH})"

    # echo == Bringing up Blobstream Orchestrator
    # docker-compose up -d orchestrator

    # echo "Waiting for Blobstream Contracts"
    # sleep 100
    # echo == Bringing up Blobstream Relayer
    # docker-compose up -d relayer
    # sleep 30

    echo == Writing l2 chain config
    docker-compose run scripts write-l2-chain-config

    # Wait for Relayer to have deployed the contract
    sleep 10
    echo == Deploying L2
    sequenceraddress=`docker-compose run scripts print-address --account sequencer | tail -n 1 | tr -d '\r\n'`
    # export BLOBSTREAM_ADDRESS="$(docker exec relayer cat ${BLOBSTREAM_PATH})"
    # echo == Blobstream Address: ${BLOBSTREAM_ADDRESS}
    docker-compose run --entrypoint /usr/local/bin/deploy poster --l1conn ws://geth:8546 --l1keystore /home/user/l1keystore --sequencerAddress $sequenceraddress --ownerAddress $sequenceraddress --l1DeployAccount $sequenceraddress --l1deployment /config/deployment.json --authorizevalidators 10 --wasmrootpath /home/user/target/machines --l1chainid=$l1chainid --l2chainconfig /config/l2_chain_config.json --l2chainname arb-dev-test --l2chaininfo /config/deployed_chain_info.json --blobstreamAddress $BLOBSTREAM_ADDRESS
    docker-compose run --entrypoint sh poster -c "jq [.[]] /config/deployed_chain_info.json > /config/l2_chain_info.json"
    echo == Writing configs
    echo == Auth Token: ${CELESTIA_NODE_AUTH_TOKEN}
    docker-compose run scripts write-config --authToken $CELESTIA_NODE_AUTH_TOKEN --blobstreamAddress $BLOBSTREAM_ADDRESS

    echo == Initializing redis
    docker-compose run scripts redis-init --redundancy $redundantsequencers

    echo == Funding l2 funnel and dev key
    docker-compose up -d $INITIAL_SEQ_NODES
    docker-compose run scripts bridge-funds --ethamount 100000 --wait
    docker-compose run scripts bridge-funds --ethamount 1000 --wait --from "key_0x$devprivkey"

    if $tokenbridge; then
        echo == Deploying token bridge
        docker-compose run -e ARB_KEY=$devprivkey -e ETH_KEY=$devprivkey tokenbridge gen:network
        docker-compose run --entrypoint sh tokenbridge -c "cat localNetwork.json"
        echo
    fi

    if $l3node; then
        echo == Funding l3 users
        docker-compose run scripts send-l2 --ethamount 1000 --to l3owner --wait
        docker-compose run scripts send-l2 --ethamount 1000 --to l3sequencer --wait


        echo == create l2 traffic
        docker-compose run scripts send-l2 --ethamount 100 --to user_l2user --wait
        docker-compose run scripts send-l2 --ethamount 0.0001 --from user_l2user --to user_l2user_b --wait --delay 500 --times 500 > /dev/null &

        echo == Writing l3 chain config
        docker-compose run scripts write-l3-chain-config

        echo == Deploying L3
        l3owneraddress=`docker-compose run scripts print-address --account l3owner | tail -n 1 | tr -d '\r\n'`

        l3sequenceraddress=`docker-compose run scripts print-address --account l3sequencer | tail -n 1 | tr -d '\r\n'`

        docker-compose run --entrypoint /usr/local/bin/deploy poster --l1conn ws://sequencer:8548 --l1keystore /home/user/l1keystore --sequencerAddress $l3sequenceraddress --ownerAddress $l3owneraddress --l1DeployAccount $l3owneraddress --l1deployment /config/l3deployment.json --authorizevalidators 10 --wasmrootpath /home/user/target/machines --l1chainid=412346 --l2chainconfig /config/l3_chain_config.json --l2chainname orbit-dev-test --l2chaininfo /config/deployed_l3_chain_info.json
        docker-compose run --entrypoint sh poster -c "jq [.[]] /config/deployed_l3_chain_info.json > /config/l3_chain_info.json"

        echo == Funding l3 funnel and dev key
        docker-compose up -d l3node poster
        docker-compose run scripts bridge-to-l3 --ethamount 50000 --wait
        docker-compose run scripts bridge-to-l3 --ethamount 500 --wait --from "key_0x$devprivkey"

    fi
fi

if $run; then
    UP_FLAG=""
    if $detach; then
        UP_FLAG="-d"
    fi

    echo == Launching Sequencer
    echo if things go wrong - use --init to create a new chain
    echo

    docker-compose up $UP_FLAG $NODES
fi
