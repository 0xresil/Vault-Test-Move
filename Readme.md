## AppInfo resource
AppInfo resource will be located at app module account.

Here, I save admin info.
```
  struct AppInfo has key {
    admin_addr: address,
    is_paused: u8,
  }
```

- App will be initialized by the contract account. (This structure can be modified)
- App info has two fields - `admin_addr`, `is_paused`
- `admin_addr` stores the address of admin of platform and `is_paused` represents the status of app.

## VaultInfo resource
VaultInfo resource will store the deposited coins.

```
  struct VaultInfo<phantom CoinType> has key {
    coin: Coin<CoinType>,
  }
```
- `coin` represents what user deposited

## Functions
- initialize_app
> Initialize the app only one time by the contract account.
And create AppInfo resource account here/.
- deposit
> Deposit coins to user's VaultInfo resource.
- withdraw
> Withdraw coins from user's VaultInfo resource to User's wallet
- pause
> Admin can pause the site to stop withdraw and deposit.
Here, I admin set `is_paused` variable in `app_info` as 1.
- unpause
> Admin can unpause the site to resume withdraw and deposit.
Here, I admin set `is_paused` variable in `app_info` as 0.