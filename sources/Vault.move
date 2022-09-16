module VaultTest::Vault {

  use std::signer;
  use std::error;
  use std::bcs;
  use std::vector;
  use aptos_std::type_info;
  use aptos_framework::coin;
  use aptos_framework::account;

  /* Errors. */
  const EAPP_NOT_INITIALIZED: u64 = 0;
  const EVAULT_NOT_EXISTS: u64 = 1;
  const EINVALID_BALANCE: u64 = 2;
  const EINVALID_VALUE: u64 = 3;
  const EINVALID_DEDICATED_INITIALIZER: u64 = 4;
  const EINVALID_ADMIN: u64 = 5;
  const EINVALID_COIN: u64 = 6;
  const EAPP_IS_PAUSED: u64 = 7;

  /* Constants. */
  const APP_INFO_SEED: vector<u8> = b"APP_INFO_SEED";
  const VAULT_SEED: vector<u8> = b"VAULT_SEED";

  /* data structures. */
  struct AppInfo has key, store {
    admin_addr: address,
    is_paused: u8,
  }

  struct VaultInfo has key, store {
    amount: u64,
    deposit_coin_addr: address,
    signer_cap: account::SignerCapability,
  }

  /* entry functions */
  public entry fun initialize_app(initializer: &signer, admin_addr: address) {
    let initializer_addr = signer::address_of(initializer);
    assert!(initializer_addr == @VaultTest, error::permission_denied(EINVALID_DEDICATED_INITIALIZER));
    // pool is derived from contract address
    let (app, _) = account::create_resource_account(initializer, APP_INFO_SEED);
    move_to<AppInfo>(&app, AppInfo {
        admin_addr,
        is_paused: 0,
    });
  }

  public entry fun deposit<CoinType>(account: &signer, amount: u64) acquires VaultInfo, AppInfo {

    let app_addr = account::create_resource_address(&@VaultTest, APP_INFO_SEED);
    // check if app exists
    assert!(exists<AppInfo>(app_addr), error::not_found(EAPP_NOT_INITIALIZED));

    let account_addr = signer::address_of(account);
    let app_info = borrow_global_mut<AppInfo>(app_addr);
    assert!(app_info.is_paused == 0, error::permission_denied(EAPP_IS_PAUSED));

    let coin_addr = coin_address<CoinType>();
  
    let vault_addr = account::create_resource_address(&account_addr, seed_with_address(coin_addr, VAULT_SEED));
    if (!exists<VaultInfo>(vault_addr)) {
      // if it is first deposit, move VaultInfo resource to account
      let (vault, vault_signer_cap) = account::create_resource_account(account, seed_with_address(coin_addr, VAULT_SEED));
      move_to<VaultInfo>(&vault, VaultInfo {
          amount,
          deposit_coin_addr: coin_addr,
          signer_cap: vault_signer_cap
      });
      coin::register<CoinType>(&vault);
    } else {
      // if already deposited, then update vault_info
      let vault_info = borrow_global_mut<VaultInfo>(vault_addr);
      vault_info.amount = vault_info.amount + amount;
        
      check_coin_type<CoinType>(vault_info.deposit_coin_addr);
    };
    
    // deposit coin to vault
    coin::transfer<CoinType>(account, vault_addr, amount);
  }

  public entry fun withdraw<CoinType>(account: &signer, amount: u64) acquires VaultInfo, AppInfo {
    
    let account_addr = signer::address_of(account);
    let app_addr = account::create_resource_address(&@VaultTest, APP_INFO_SEED);
    // check if app exists
    assert!(exists<AppInfo>(app_addr), error::not_found(EAPP_NOT_INITIALIZED));

    let coin_addr = coin_address<CoinType>();
    let vault_addr = account::create_resource_address(&account_addr, seed_with_address(coin_addr, VAULT_SEED));
    assert!(exists<VaultInfo>(vault_addr), error::not_found(EVAULT_NOT_EXISTS));

    // update user's stake amount in stakeInfo
    let vault_info = borrow_global_mut<VaultInfo>(vault_addr);
    assert!(amount <= vault_info.amount, error::invalid_argument(EINVALID_VALUE));
    vault_info.amount = vault_info.amount - amount;
    
    // check if app is paused
    let app_info = borrow_global_mut<AppInfo>(app_addr); 
    assert!(app_info.is_paused == 0, error::permission_denied(EAPP_IS_PAUSED));

    // check coin type
    check_coin_type<CoinType>(vault_info.deposit_coin_addr);

    // transfer to user
    let vault_account_from_cap = account::create_signer_with_capability(&vault_info.signer_cap);
    coin::transfer<CoinType>(&vault_account_from_cap, account_addr, amount);
  }

  public entry fun pause(account: &signer) acquires AppInfo {
    let app_addr = account::create_resource_address(&@VaultTest, APP_INFO_SEED);
    // check if app exists
    assert!(exists<AppInfo>(app_addr), error::not_found(EAPP_NOT_INITIALIZED));

    let app_info = borrow_global_mut<AppInfo>(app_addr);

    // check if account is admin
    let account_addr = signer::address_of(account);
    assert!(app_info.admin_addr == account_addr, error::permission_denied(EINVALID_ADMIN));
    
    // resume the app
    app_info.is_paused = 1;
  }

  public entry fun unpause(account: &signer) acquires AppInfo {
    let app_addr = account::create_resource_address(&@VaultTest, APP_INFO_SEED);
    // check if app exists
    assert!(exists<AppInfo>(app_addr), error::not_found(EAPP_NOT_INITIALIZED));

    let app_info = borrow_global_mut<AppInfo>(app_addr);

    // check if account is admin
    let account_addr = signer::address_of(account);
    assert!(app_info.admin_addr == account_addr, error::permission_denied(EINVALID_ADMIN));
    
    // resume the app
    app_info.is_paused = 0;
  }


  /* private functions*/

  /// function to get mixed seeds (addr + seed)
  fun seed_with_address(addr: address, seed: vector<u8>): vector<u8> {
    let bytes = bcs::to_bytes(&addr);
    vector::append(&mut bytes, seed);
    bytes
  }
  
  /// function to check if coin is stakable coin
  fun check_coin_type<CoinType>(coin_addr: address) {
    assert!(coin_addr == type_info::account_address(&type_info::type_of<CoinType>()), error::invalid_argument(EINVALID_COIN));
  }

  /// A helper function that returns the address of CoinType.
  fun coin_address<CoinType>(): address {
    let type_info = type_info::type_of<CoinType>();
    type_info::account_address(&type_info)
  }

  /* Here are tests. */
  
  #[test_only]
  struct CoinA {}

  #[test_only]
  struct CoinB {}

  #[test_only]
  use aptos_framework::managed_coin;
  
  #[test_only]
  use aptos_framework::aptos_account;

  #[test_only]
  public fun initialize_and_mint<CoinType>(authority: &signer, to: &signer, mint_amount: u64) {

      let to_addr = signer::address_of(to);
      managed_coin::initialize<CoinType>(authority, b"FakeCoinX", b"CoinX", 9, false);
      if (!account::exists_at(to_addr)) {
        aptos_account::create_account(to_addr);
      };
      if (!coin::is_account_registered<CoinType>(to_addr)) {
        coin::register<CoinType>(to);
      };
      managed_coin::mint<CoinType>(authority, to_addr, mint_amount); 
  }

  #[test(fake_admin = @0x1234)]
  #[expected_failure(abort_code = 327684)] // EINVALID_DEDICATED_INITIALIZER
  public fun test_others_can_init(fake_admin: signer)  {
      initialize_app(&fake_admin, signer::address_of(&fake_admin));
  }

  #[test(alice = @0x1234, admin = @0x3333, initializer = @VaultTest)]
  #[expected_failure(abort_code = 327687)] // EAPP_IS_PAUSED
  public fun test_can_deposit_if_paused(alice: signer, admin: signer, initializer: signer) acquires AppInfo, VaultInfo {
      // init and mint coins
      initialize_and_mint<CoinA>(&initializer, &alice, 10000);

      // initialize app
      let admin_addr = signer::address_of(&admin);
      initialize_app(&initializer, admin_addr);

      // pause app
      pause(&admin);
      // try deposit but will be failed
      deposit<CoinA>(&alice, 500);
  }

  #[test(alice = @0x1234, admin = @0x3333, initializer = @VaultTest)]
  #[expected_failure(abort_code = 327687)] // EAPP_IS_PAUSED
  public fun test_can_withdraw_if_paused(alice: signer, admin: signer, initializer: signer) acquires AppInfo, VaultInfo {
      // init and mint coins
      initialize_and_mint<CoinA>(&initializer, &alice, 10000);

      // initialize app
      let admin_addr = signer::address_of(&admin);
      initialize_app(&initializer, admin_addr);

      // deposit 500
      deposit<CoinA>(&alice, 500);
      
      // pause app
      pause(&admin);

      // try withdraw but will be failed
      withdraw<CoinA>(&alice, 500);
  }

  #[test(alice = @0x1234, admin = @0x3333, initializer = @VaultTest)]
  public fun test_can_resume(alice: signer, admin: signer, initializer: signer) acquires AppInfo, VaultInfo {
      // init and mint coins
      initialize_and_mint<CoinA>(&initializer, &alice, 10000);

      // initialize app
      let admin_addr = signer::address_of(&admin);
      initialize_app(&initializer, admin_addr);

      // deposit 500
      deposit<CoinA>(&alice, 500);
      
      // pause app
      pause(&admin);

      // resume app
      unpause(&admin);

      // withdraw 500
      withdraw<CoinA>(&alice, 500);
  }

  #[test(alice = @0x1234, bob = @0x2345, admin = @0x3333, initializer = @VaultTest)]
  public fun e2e_test(alice: signer, bob: signer, admin: signer, initializer: signer) acquires AppInfo, VaultInfo {
      let alice_addr = signer::address_of(&alice);
      let bob_addr = signer::address_of(&bob);

      // init and mint coins
      initialize_and_mint<CoinA>(&initializer, &alice, 10000);
      initialize_and_mint<CoinB>(&initializer, &bob, 10000);
      
      assert!(coin::balance<CoinA>(alice_addr) == 10000, error::invalid_argument(EINVALID_BALANCE));
      assert!(coin::balance<CoinB>(bob_addr) == 10000, error::invalid_argument(EINVALID_BALANCE));

      // initialize app
      let admin_addr = signer::address_of(&admin);
      initialize_app(&initializer, admin_addr);

      // alice deposit 500 CoinA
      deposit<CoinA>(&alice, 500);
      assert!(coin::balance<CoinA>(alice_addr) == 9500, error::invalid_argument(EINVALID_BALANCE));

      let alice_coin_a_vault_addr = account::create_resource_address(&alice_addr, seed_with_address(coin_address<CoinA>(), VAULT_SEED));
      assert!(coin::balance<CoinA>(alice_coin_a_vault_addr) == 500, error::invalid_argument(EINVALID_BALANCE));

      let vault_info = borrow_global<VaultInfo>(alice_coin_a_vault_addr);
      assert!(vault_info.amount == 500, error::invalid_argument(EINVALID_BALANCE));
      
      // alice withdraw 300 coinA
      withdraw<CoinA>(&alice, 300);
      assert!(coin::balance<CoinA>(alice_addr) == 9800, error::invalid_argument(EINVALID_BALANCE));
      assert!(coin::balance<CoinA>(alice_coin_a_vault_addr) == 200, error::invalid_argument(EINVALID_BALANCE));

      let vault_info = borrow_global<VaultInfo>(alice_coin_a_vault_addr);
      assert!(vault_info.amount == 200, error::invalid_argument(EINVALID_BALANCE));

      // bob deposit 500 CoinA
      deposit<CoinB>(&bob, 500);
      assert!(coin::balance<CoinB>(bob_addr) == 9500, error::invalid_argument(EINVALID_BALANCE));

      let bob_coin_b_vault_addr = account::create_resource_address(&bob_addr, seed_with_address(coin_address<CoinB>(), VAULT_SEED));
      assert!(coin::balance<CoinB>(bob_coin_b_vault_addr) == 500, error::invalid_argument(EINVALID_BALANCE));
      
      // bob withdraw 300 coinA
      withdraw<CoinB>(&bob, 300);
      assert!(coin::balance<CoinB>(bob_addr) == 9800, error::invalid_argument(EINVALID_BALANCE));
      assert!(coin::balance<CoinB>(bob_coin_b_vault_addr) == 200, error::invalid_argument(EINVALID_BALANCE));
      
  }
}
