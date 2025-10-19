import { Cl } from '@stacks/transactions';
import { describe, expect, it, beforeEach } from 'vitest';

const accounts = simnet.getAccounts();
const deployer = accounts.get('deployer')!;
const farmer1 = accounts.get('wallet_1')!;
const farmer2 = accounts.get('wallet_2')!;
const unauthorized = accounts.get('wallet_3')!;

describe('Fertilizer Voucher Management System', () => {
  beforeEach(() => {
    simnet.deployContract(
      'fertilizer-voucher',
      'contracts/fertilizer-voucher.clar',
      null,
      deployer
    );
  });

  describe('Farmer Registration', () => {
    it('should allow contract owner to register farmers', () => {
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'register-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
      
      expect(result).toBeOk(Cl.bool(true));
    });

    it('should prevent duplicate farmer registration', () => {
      // Register farmer1 first
      simnet.callPublicFn(
        'fertilizer-voucher',
        'register-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
      
      // Try to register the same farmer again
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'register-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
      
      expect(result).toBeErr(Cl.uint(101)); // ERR-FARMER-EXISTS
    });

    it('should prevent unauthorized users from registering farmers', () => {
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'register-farmer',
        [Cl.principal(farmer1)],
        unauthorized
      );
      
      expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });
  });

  describe('Farmer Verification', () => {
    beforeEach(() => {
      simnet.callPublicFn(
        'fertilizer-voucher',
        'register-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
    });

    it('should allow contract owner to verify farmers', () => {
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'verify-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
      
      expect(result).toBeOk(Cl.bool(true));
      
      // Check verification status
      const verification = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'is-farmer-verified',
        [Cl.principal(farmer1)],
        deployer
      );
      
      expect(verification.result).toBeOk(Cl.bool(true));
    });

    it('should prevent duplicate verification', () => {
      // Verify farmer1 first
      simnet.callPublicFn(
        'fertilizer-voucher',
        'verify-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
      
      // Try to verify the same farmer again
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'verify-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
      
      expect(result).toBeErr(Cl.uint(106)); // ERR-ALREADY-VERIFIED
    });
  });

  describe('Voucher Issuance', () => {
    beforeEach(() => {
      // Register and verify farmer1
      simnet.callPublicFn(
        'fertilizer-voucher',
        'register-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
      simnet.callPublicFn(
        'fertilizer-voucher',
        'verify-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
    });

    it('should allow voucher issuance to verified farmers', () => {
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'issue-vouchers',
        [Cl.principal(farmer1), Cl.uint(100)],
        deployer
      );
      
      expect(result).toBeOk(Cl.uint(100));
      
      // Check balance
      const balance = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'get-voucher-balance',
        [Cl.principal(farmer1)],
        deployer
      );
      
      expect(balance.result).toBeOk(Cl.uint(100));
    });

    it('should prevent voucher issuance to unverified farmers', () => {
      // Register but don't verify farmer2
      simnet.callPublicFn(
        'fertilizer-voucher',
        'register-farmer',
        [Cl.principal(farmer2)],
        deployer
      );
      
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'issue-vouchers',
        [Cl.principal(farmer2), Cl.uint(100)],
        deployer
      );
      
      expect(result).toBeErr(Cl.uint(107)); // ERR-NOT-VERIFIED
    });

    it('should prevent unauthorized voucher issuance', () => {
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'issue-vouchers',
        [Cl.principal(farmer1), Cl.uint(100)],
        unauthorized
      );
      
      expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });
  });

  describe('Voucher Redemption', () => {
    beforeEach(() => {
      // Register, verify, and issue vouchers to farmer1
      simnet.callPublicFn(
        'fertilizer-voucher',
        'register-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
      simnet.callPublicFn(
        'fertilizer-voucher',
        'verify-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
      simnet.callPublicFn(
        'fertilizer-voucher',
        'issue-vouchers',
        [Cl.principal(farmer1), Cl.uint(100)],
        deployer
      );
    });

    it('should allow farmers to redeem vouchers', () => {
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'redeem-vouchers',
        [Cl.uint(50)],
        farmer1
      );
      
      expect(result).toBeOk(Cl.uint(50));
      
      // Check remaining balance
      const balance = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'get-voucher-balance',
        [Cl.principal(farmer1)],
        deployer
      );
      
      expect(balance.result).toBeOk(Cl.uint(50));
    });

    it('should prevent over-redemption', () => {
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'redeem-vouchers',
        [Cl.uint(150)],
        farmer1
      );
      
      expect(result).toBeErr(Cl.uint(103)); // ERR-INSUFFICIENT-VOUCHERS
    });

    it('should prevent zero amount redemption', () => {
      const { result } = simnet.callPublicFn(
        'fertilizer-voucher',
        'redeem-vouchers',
        [Cl.uint(0)],
        farmer1
      );
      
      expect(result).toBeErr(Cl.uint(105)); // ERR-INVALID-AMOUNT
    });
  });

  describe('Read-Only Functions', () => {
    beforeEach(() => {
      // Set up test data
      simnet.callPublicFn(
        'fertilizer-voucher',
        'register-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
      simnet.callPublicFn(
        'fertilizer-voucher',
        'verify-farmer',
        [Cl.principal(farmer1)],
        deployer
      );
      simnet.callPublicFn(
        'fertilizer-voucher',
        'issue-vouchers',
        [Cl.principal(farmer1), Cl.uint(100)],
        deployer
      );
    });

    it('should return farmer information', () => {
      const result = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'get-farmer-info',
        [Cl.principal(farmer1)],
        deployer
      );
      
      expect(result.result).toBeSome();
    });

    it('should return total vouchers issued', () => {
      const result = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'get-total-vouchers-issued',
        [],
        deployer
      );
      
      expect(result.result).toBeOk(Cl.uint(1));
    });

    it('should return total vouchers redeemed', () => {
      // Redeem some vouchers first
      simnet.callPublicFn(
        'fertilizer-voucher',
        'redeem-vouchers',
        [Cl.uint(25)],
        farmer1
      );
      
      const result = simnet.callReadOnlyFn(
        'fertilizer-voucher',
        'get-total-vouchers-redeemed',
        [],
        deployer
      );
      
      expect(result.result).toBeOk(Cl.uint(1));
    });
  });
});
