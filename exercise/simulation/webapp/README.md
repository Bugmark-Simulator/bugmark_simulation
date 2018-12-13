# Bugmark Exercise: Webapp1

A Bugmark Research Application

## Goals 

- Generate live trading data ASAP with a simple trading app
- Minimum UI, Limited features, limited functions
- Simple / Hackable / Extensible

## Hard Coded Trackers

- bugmark/exchange
- bugmark/bmx_cl_ruby
- bugmark/test_bench
- bugmark/website
- bugmark/documentation

## Scenario

- We post a simple webapp for internal use by the Bugmark team
- App runs a friendly competition to see who gets high score
- Trading tokens not real currency
- Every week, traders are topped up to a minimum of 1000 tokens
- Users self-register with email and pwd (anyone can register)
- We post prices, top issues, etc. 

## Tooling

- `bmx_cli_ruby` - our ruby cli
- Sinatra - simplistic web-app builder
- Bootstrap4 / FontAwesome / Datatables - loaded via CDN in page layout
- Application data stored in JSON files - no database
- Tested to run on an Ubuntu host
- Tracker list hard-coded in a server-side JSON file

## Cron 

- [Weekly] top off user balances
- [Hourly] sync bugs
- [Hourly] cross open offers
