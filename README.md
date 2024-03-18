# Nitro Testnode

Nitro-testnode brings up a full environment for local nitro testing (with or without Stylus support) including a dev-mode geth L1, and multiple instances with different roles.

### Requirements

* bash shell
* docker and docker-compose
* a celestia light node and an address with tokens on Mocha
* a cloud instance with 64CPU and 128GB Ram in order to run the BlobstreamX Prover

All must be installed in PATH.

## Using Celestia's Nitro v2.3.1

Check out this [branch](https://github.com/celestiaorg/nitro/tree/celestia-v2.3.1)

Use the test-node submodule of nitro repository, and make sure you get the `succinctx` and `blobstreamx` submodules.

### Get the v2.3.1 version
```bash
git clone --recurse-submodules https://github.com/celestiaorg/nitro
git checkout celestia-v2.3.1
cd nitro/nitro-testnode
```

## Steps to run e2e testing

1. Make sure you have a celestia light node running against Mocha and have some tokens to post blobs ([docs here](https://docs.celestia.org/nodes/light-node#start-the-light-node))
2. In the [scripts/config.ts](https://github.com/celestiaorg/nitro-testnode/blob/celestia-v2.3.1/scripts/config.ts#L225-L232) file, make sure you put your light node under "rpc" (we use host.docker.internal to connect the docker containers to a light node running on the host, but you can modify this to your liking), then make sure to use a "tendermint-rpc" you have access to. Finally, you can pick a namespace or leave it as is, the "auth-token" you will get from your [light node](https://docs.celestia.org/developers/node-tutorial#auth-token), and leave everything else as is.
3. Go to the succinctx submodule and remove the `verify` flag [here](https://github.com/succinctlabs/succinctx/blob/18611dc4ff59ac53f895cd45588d562f0c088758/contracts/script/deploy.sh#L37C88-L37C152).
4. Finally, `cd blobstreamx` and then run `cargo run --bin genesis -- --block $BLOCK_NUMER` where $BLOCK_NUMBER is the latest Mocha block, then take the height and the hash and use them in the `GENESIS_HEIGHT` and `GENESIS_HEADER` environment variables in the testnode-bash script, or in a .env file inside of BlobstreamX.

Once you have everything setup, you can start testing the e2e setup by running

```bash
./test-node.bash --init --dev
```
To see more options, use `--help`.

And can add `--validate` for validation mode, and thus use the preimage oracle for Celestia
```bash
./test-node.bash --init --dev --validate
```
To see more options, use `--help`.

## Further information

### Working with docker containers

**sequencer** is the main docker to be used to access the nitro testchain. It's http and websocket interfaces are exposed at localhost ports 8547 and 8548 ports, respectively.

Stopping, restarting nodes can be done with docker-compose.

### Helper scripts

Some helper scripts are provided for simple testing of basic actions.

To fund the address 0x1111222233334444555566667777888899990000 on l2, use:

```bash
./test-node.bash script send-l2 --to address_0x1111222233334444555566667777888899990000
```

For help and further scripts, see:

```bash
./test-node.bash script --help
```

## Named accounts

```bash
./test-node.bash script print-address --account sequencer
```
```
sequencer:                  0xe2148eE53c0755215Df69b2616E552154EdC584f
validator:                  0x6A568afe0f82d34759347bb36F14A6bB171d2CBe
l2owner:                    0x5E1497dD1f08C87b2d8FE23e9AAB6c1De833D927
l3owner:                    0x863c904166E801527125D8672442D736194A3362
l3sequencer:                0x3E6134aAD4C4d422FF2A4391Dc315c4DDf98D1a5
user_l1user:                0x058E6C774025ade66153C65672219191c72c7095
user_token_bridge_deployer: 0x3EaCb30f025630857aDffac9B2366F953eFE4F98
user_fee_token_deployer:    0x2AC5278D230f88B481bBE4A94751d7188ef48Ca2
```

While not a named account, 0x3f1eae7d46d88f08fc2f8ed27fcb2ab183eb2d0e is funded on all test chains.
