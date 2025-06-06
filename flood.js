// network-flood.js
const { ethers } = require('ethers');
const crypto = require('crypto');

const RPC_URL = 'http://localhost:8547'; // Your local network RPC
const PRIVATE_KEY = ''; // Your private key (without 0x prefix)
const TARGET_ADDRESS = ''; // Target address
const PAYLOAD_SIZE_KB = 50; // Size of payload in KB
const TX_DELAY_MS = 1; // Delay between transactions in milliseconds
const GAS_LIMIT = 4000000; // Gas limit for large payload
const GAS_PRICE = 50; // Gas price in gwei

// Convert KB to bytes
const PAYLOAD_SIZE_BYTES = PAYLOAD_SIZE_KB * 1024;

// Setup provider and wallet
const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Generate random data of specified size
function generateRandomData(sizeInBytes) {
    return '0x' + crypto.randomBytes(sizeInBytes).toString('hex');
}

// Send a single transaction
async function sendTransaction() {
    try {
        // Get current nonce
        const nonce = await wallet.getTransactionCount();

        // Generate random data
        console.log(`Generating ${PAYLOAD_SIZE_KB}KB payload...`);
        const data = generateRandomData(PAYLOAD_SIZE_BYTES);

        // Create transaction
        const tx = {
            to: TARGET_ADDRESS,
            value: ethers.utils.parseEther('0.0001'),
            data: data,
            nonce: nonce,
        };

        console.log(`Sending transaction with nonce ${nonce}...`);

        // Send transaction
        const txResponse = await wallet.sendTransaction(tx);
        console.log(`Transaction sent successfully: ${txResponse.hash}`);
        return true;
    } catch (error) {
        console.error(`Failed to send transaction: ${error.message}`);
        return false;
    }
}

// Main function to continuously send transactions
async function main() {
    console.log('Starting continuous network flood...');
    console.log(`Using wallet: ${wallet.address}`);
    console.log('Press Ctrl+C to stop');

    let txCount = 0;

    while (true) {
        const success = await sendTransaction();
        if (success) {
            txCount++;
            console.log(`Total transactions sent: ${txCount}`);
        }

        // Delay before next transaction
        await new Promise(resolve => setTimeout(resolve, TX_DELAY_MS));
    }
}

// Start the flood
main().catch(console.error);