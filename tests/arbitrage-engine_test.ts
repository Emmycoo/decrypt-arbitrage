import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "Verify trade creation functionality",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall('arbitrage-engine', 'create-trade', [
        types.ascii('Binance'),
        types.ascii('Kraken'),
        types.ascii('STX-USDT'),
        types.uint(100),
        types.uint(105),
        types.uint(1000)
      ], deployer.address)
    ]);

    assertEquals(block.receipts.length, 1);
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk().expectUint(1);
  }
});

Clarinet.test({
  name: "Validate trade status update",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall('arbitrage-engine', 'create-trade', [
        types.ascii('Binance'),
        types.ascii('Kraken'),
        types.ascii('STX-USDT'),
        types.uint(100),
        types.uint(105),
        types.uint(1000)
      ], deployer.address),
      Tx.contractCall('arbitrage-engine', 'update-trade-status', [
        types.uint(1),
        types.uint(2)
      ], deployer.address)
    ]);

    assertEquals(block.receipts.length, 2);
    block.receipts[1].result.expectOk().expectBool(true);
  }
});