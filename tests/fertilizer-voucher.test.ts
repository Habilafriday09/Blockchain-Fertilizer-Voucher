import { Cl, getAddressFromPrivateKey, makeRandomPrivKey, privateKeyToString, TransactionVersion } from '@stacks/transactions';
import { describe, expect, it, beforeEach } from 'vitest';

const accounts = simnet.getAccounts();
const deployer = accounts.get('deployer')!;

const makeAddress = () => {
  const privKey = makeRandomPrivKey();
  const privKeyStr = privateKeyToString(privKey);
  return getAddressFromPrivateKey(privKeyStr, TransactionVersion.Testnet);
};

const farmer1 = makeAddress();
const farmer2 = makeAddress();
const unauthorized = makeAddress();

const asPrincipal = (account: string) => Cl.principal(account);

const registerFarmer = (farmer = farmer1, sender = deployer) =>
  simnet.callPublicFn('fertilizer-voucher', 'register-farmer', [asPrincipal(farmer)], sender);

const verifyFarmer = (farmer = farmer1, sender = deployer) =>
  simnet.callPublicFn('fertilizer-voucher', 'verify-farmer', [asPrincipal(farmer)], sender);

const issueVouchers = (farmer = farmer1, amount = 100n, sender = deployer) =>
  simnet.callPublicFn(
    'fertilizer-voucher',
    'issue-vouchers',
    [asPrincipal(farmer), Cl.uint(amount)],
    sender,
  );

describe('Fertilizer Voucher Management System', () => {

  describe('Farmer Registration', () => {
    it('should allow contract owner to register farmers', () => {
      const { result } = registerFarmer();

      expect(result).toBeOk(Cl.bool(true));
    });

    it('should prevent duplicate farmer registration', () => {
      // Register farmer1 first
      registerFarmer();

      // Try to register the same farmer again
      const { result } = registerFarmer();

      expect(result).toBeErr(Cl.uint(101)); // ERR-FARMER-EXISTS
    });

    it('should prevent unauthorized users from registering farmers', () => {
      const { result } = registerFarmer(farmer1, unauthorized);

      expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });
  });

  describe('Farmer Verification', () => {
    beforeEach(() => {
      registerFarmer();
    });

    it('should allow contract owner to verify farmers', () => {
      const { result } = verifyFarmer();

      expect(result).toBeOk(Cl.bool(true));

      // Check verification status
      const verification = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'is-farmer-verified',
        [asPrincipal(farmer1)],
        deployer
      );

      expect(verification.result).toBeOk(Cl.bool(true));
    });

    it('should prevent duplicate verification', () => {
      // Verify farmer1 first
      verifyFarmer();

      // Try to verify the same farmer again
      const { result } = verifyFarmer();

      expect(result).toBeErr(Cl.uint(106)); // ERR-ALREADY-VERIFIED
    });
  });

  describe('Voucher Issuance', () => {
    beforeEach(() => {
      // Register and verify farmer1
      registerFarmer();
      verifyFarmer();
    });

    it('should allow voucher issuance to verified farmers', () => {
      const { result } = issueVouchers();

      expect(result).toBeOk(Cl.uint(100));

      // Check balance
      const balance = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'get-voucher-balance',
        [asPrincipal(farmer1)],
        deployer
      );

      expect(balance.result).toBeOk(Cl.uint(100));
    });

    it('should prevent voucher issuance to unverified farmers', () => {
      // Register but don't verify farmer2
      registerFarmer(farmer2);

      const { result } = issueVouchers(farmer2);

      expect(result).toBeErr(Cl.uint(107)); // ERR-NOT-VERIFIED
    });

    it('should prevent unauthorized voucher issuance', () => {
      const { result } = issueVouchers(farmer1, 100n, unauthorized);

      expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });
  });

  describe('Voucher Redemption', () => {
    beforeEach(() => {
      // Register, verify, and issue vouchers to farmer1
      registerFarmer();
      verifyFarmer();
      issueVouchers();
    });

    it('should allow farmers to redeem vouchers', () => {
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'redeem-vouchers',
        [Cl.uint(50)],
        farmer1,
      );

      expect(result).toBeOk(Cl.uint(50));

      // Check remaining balance
      const balance = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'get-voucher-balance',
        [asPrincipal(farmer1)],
        deployer,
      );

      expect(balance.result).toBeOk(Cl.uint(50));
    });

    it('should prevent over-redemption', () => {
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'redeem-vouchers',
        [Cl.uint(150)],
        farmer1,
      );

      expect(result).toBeErr(Cl.uint(103)); // ERR-INSUFFICIENT-VOUCHERS
    });

    it('should prevent zero amount redemption', () => {
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'redeem-vouchers',
        [Cl.uint(0)],
        farmer1,
      );

      expect(result).toBeErr(Cl.uint(105)); // ERR-INVALID-AMOUNT
    });
  });

  describe('Read-Only Functions', () => {
    beforeEach(() => {
      // Set up test data
      registerFarmer();
      verifyFarmer();
      issueVouchers();
    });

    it('should return farmer information', () => {
      const result = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'get-farmer-info',
        [asPrincipal(farmer1)],
        deployer,
      );
      
      expect(result.result).toBeDefined();
    });

    it('should return total vouchers issued', () => {
      const result = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'get-total-vouchers-issued',
        [],
        deployer,
      );

      expect(result.result).toBeOk(Cl.uint(1));
    });

    it('should return total vouchers redeemed', () => {
      // Redeem some vouchers first
      simnet.callPublicFn(
        'fertilizer-voucher',
        'redeem-vouchers',
        [Cl.uint(25)],
        farmer1,
      );

      const result = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'get-total-vouchers-redeemed',
        [],
        deployer,
      );

      expect(result.result).toBeOk(Cl.uint(1));
    });
  });
});
