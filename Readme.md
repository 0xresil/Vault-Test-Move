## AppInfo resource
AppInfo resource will be located at resource account which address is derived from contract address with 'APP_SEED' as a seed string.

Here, I save admin info.
```
  struct AppInfo has key, store {
    admin_addr: address,
    is_paused: u8,
  }
```

- App will be initialized by the contract account. (This structure can be modified)
- App info has two fields - `admin_addr`, `is_paused`
- `admin_addr` stores the address of admin of platform and `is_paused` represents the status of app.

## VaultInfo resource
VaultInfo resource will store the deposited coins and also will have deposited coin type and amount.

```
  struct VaultInfo<phantom CoinType> has key {
    user_addr: address,
    coin: Coin<CoinType>,
  }
```
- `user_addr` is the address of the user who deposited to this vault
- `coin` represents what user deposited

## Functions
- initialize_app
> Initialize the app only one time by the contract account.
And create AppInfo resource account here/.
- deposit
> Deposit coins to user's VaultInfo resource account.
`VaultInfo` resource account varies per users and deposit coin types.
- withdraw
> Withdraw coins from user's VaultInfo resource account to User's wallet
- pause
> Admin can pause the site to stop withdraw and deposit.
Here, I admin set `is_paused` variable in `app_info` as 1.
- unpause
> Admin can unpause the site to resume withdraw and deposit.
Here, I admin set `is_paused` variable in `app_info` as 0.