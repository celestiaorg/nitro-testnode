FROM node:18-bullseye-slim
ARG NITRO_CONTRACTS_BRANCH=celestia-v3.1.0-test
RUN apt-get update && \
    apt-get install -y git docker.io python3 build-essential curl jq
WORKDIR /workspace
RUN git clone --recurse-submodules --no-checkout https://github.com/celestiaorg/nitro-contracts.git ./
RUN git checkout ${NITRO_CONTRACTS_BRANCH}
RUN curl -L https://foundry.paradigm.xyz | bash
ENV PATH="${PATH}:/root/.foundry/bin"
RUN foundryup
RUN forge update lib/forge-std
RUN touch scripts/config.ts
RUN yarn install
RUN yarn build:all
ENTRYPOINT ["yarn"]
