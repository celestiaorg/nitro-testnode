FROM node:18-bookworm-slim
ARG NITRO_CONTRACTS_BRANCH=v2.1.0
RUN apt-get update && \
    apt-get install -y git docker.io python3 make gcc g++ curl jq
WORKDIR /workspace
RUN git clone --recurse-submodules --no-checkout https://github.com/celestiaorg/nitro-contracts.git ./
RUN git checkout ${NITRO_CONTRACTS_BRANCH}
RUN yarn install && yarn cache clean
RUN curl -L https://foundry.paradigm.xyz | bash
ENV PATH="${PATH}:/root/.foundry/bin"
RUN foundryup
RUN touch scripts/config.ts
RUN yarn build:all
ENTRYPOINT ["yarn"]
