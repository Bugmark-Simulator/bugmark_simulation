# Bugmark Simulation Platform

## Description

The Bugmark Simulation Platform is a system for research purposes. The system builds on the [Bugmark Exchange](https://github.com/bugmark/exchange) and adapts [Test_Bench](https://github.com/bugmark/test_bench/). The system architecture consists of the Bugmark Exchange, an Issue Tracker, several Scripts for automated behavior, and the User Interface.

## Goal

The Bugmark Simulation Platform is developed for research experiments. The objective of the research is to investigate how developers conceptualize the use of Bugmark market mechanisms. Specifically, we are interested in how signals about the Market and Open Source Project Health are related and compete. For more information on the setup, please read the documentation on how to run an experiment.

## Documentation

_TODO:_ write the doc

  * How to Configure
  * How to Run an Experiment
  * Where to Find Everything: Software Design
    * Structure of Repository
    * Use Case Diagram
    * Activity Diagrams

## How to Install
### 1. Installation of Bugmark Exchange
This covers the config and install of software components for Bugmark
Exchange.

#### Required Skills

To be successful, we recommend good skills with the following:
- Git
- Linux command line
- Web development
- PostgreSQL
- Ruby on Rails
- Slim template engine
- Tmux (nice to have)
- InfluxDB
- Grafana

#### Host Machine

We assume that you're using Ubuntu 16.04 as your host machine.

Your host machine can exist in a few different forms:
1) a desktop Ubuntu system
2) a Virtual Machine running locally (using Vagrant)
3) a Virtual Machine running in the data center

Of the three options, the best and simplest is 3), running in the data center.
We like Linode - you can allocate a cheap node for development that will cost
$20/month.

WARNING: if you choose to install on a local system (option 1), this
configuration process will install many packages and will make changes to your
user configuration, including:
- adding items to your `.bashrc`, modifying your path
- adding your UserID to `sudoers`

In this case, it is usually best to use a dedicated user-id.

#### Development VM Configuration

Follow these steps to set up a working development environment running on an
Ubuntu Virtual machine.

Let's get started:

1. Install VirtualBox and Vagrant on your host machine (Linux, Win, Mac OK)

2. Download the dev-machine Vagrantfile
   `wget raw.githubusercontent.com/Bugmark-Simulator/exchange/master/Vagrantfile`

3. Run `vagrant up` to create a virtual machine.

4. Login to your virtual machine using `vagrant ssh`

#### Cloning the Bugmark Exchange

**NOTE:** Make sure you are not working as root user. If necessary, create a new user on Ubuntu. E.g. `adduser bugmarkstudy; adduser bugmarkstudy sudo`

1. Clone the tracker
   `mkdir src; cd src; git clone https://github.com/Bugmark-Simulator/exchange.git`

2. CD to the tracker directory `cd exchange`

#### Development Environment Provisioning

On the host machine:

1. Checkout the dev branch `git checkout -b dev origin/dev` (TODO: TEST whether it works when in master -- all of our changes are in master)

2. Install ansible `script/dev/provision/install_ansible`

3. Install ansible roles `script/dev/provision/install_roles`

4. Provision the dev machine `script/dev/provision/localhost`
  - If Node.js or NPM fail, make sure they are installed `npm -v`
    - If not, add the NodeSource APT repository `curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -`
    - Then install Node.js `sudo apt-get install -y nodejs`
  - If tasks 'influxdb : setup admin user' and 'influxdb : create database' fail, then
    - Check that influxdb is installed and running `systemctl status influxdb`
    - If it is not running, start it `sudo systemctl start influxdb`
    - Re-run the provision script in step 4
  - If any other task fails, try re-running the script, sometimes that help
  - If an error comes up about sudo requiring a password, run `sudo ls` before retrying

5. Check database status: `systemctl status postgresql`

6. Start a new shell: `bash` (required to load your new user configuration)

7.  Checkout the master branch `git checkout master`

#### Application Bootstrap

Follow these steps to bootstrap the app in your development environment.

1. Install ruby gems `gem install bundler; bundle install`

2. Install NPM components: `yarn install`

3. Create databases `bundle exec rails db:create`

4. Run migrations `bundle exec rails db:migrate`

5. Start the tmux session `tmux`

   A cheat-sheet for tmux navigation is in `~/.tmux.conf`.

#### Host Web Access

1. Get the host IP address `ifconfig`  

2. On your local machine, add the VM IP Address to `/etc/hosts`

3. On your local machine, browse to `http://<hostname>:3000` (TODO: what ever service this is, we need to start it first)


### 2. Installation of Simulation Platform
This covers the installation of simulation platform to access Bugmark
Exchange and run the simulation on top of Exchange.

1. On the server, go to *src* directory: `cd ~/src`

2. Git clone the Bugmark Simulator: `git clone https://github.com/Bugmark-Simulator/bugmark_simulation.git`

3. Create *.env* setting file `cd bugmark_simulation/exercise/simulation; cp .env-default .env`

4. Check which directory the *.env* links to `less .env` and change if desired `vim .env`, then create that directory `cd ~; mkdir trial; cd trial; mkdir simulation; mkdir .trial_data; cd ~/src`

5. Go to the simulation application folder `cd bugmark_simulation/exercise/simulation/webapp/`  

6. Start the simulation platform `./run`

7. On your local machine, browse to `http://<hostname>:4567`

Your platform is ready to go.

## Reseting Bugmark Exchange and all the database

Run script reset_scr to reset exchange and all database `~/src/bugmark_simulation/exercise/simulation/script/reset_scr`

To destroy the database and setup again:

1. Go to the exchange `cd ~\src\exchange`
2. Destroy Database and reconstruct it `bundle exec rails db:drop db:create db:migrate`

## Running the experiment
If InfluxDB or Grafana are not running:
- `sudo systemctl start influxdb`
- `sudo systemctl start grafana-server`

Following are the steps to setup the experiment
1. Run the script to clean the bugmark excange `~/src/bugmark_simulation/exercise/simulation/script/reset_scr`
  (Note: This step is not needed if you have setup a clean environment for the first time)
2. Run the script to set the BugmTime (TODO: specify script)
3. Run the script to create users  `./bugmark_simulation/exercise/simulation/script/user_gen_scr`

When you run the experiment, you need to make sure the 'background services' are running:
1. Run the script nightly (TODO: specify script)


## Simulate user behavior

To test the visualizations, data analysis, or simply see how the system behaves with many users,
run a simulation script that executes simple user actions with some randomization.

1. Setup Experiment
2. Start nightly script to make sure the system is in simulation mode `(?)`
3. Start the user behavior simulation script `~/src/bugmark_simulation/exercise/simulation/script/simulate_worker_funder.rb`

## Roadmap

- Software is developed in Summer 2018.
- Pilot studies are run in September 2018.
- Experiment is executed in November 2018.
- Data analysis is planned for Spring of 2018.

## How to Contribute

### Report an Issue

Please file an issue in the issue tracker.

### Contribute Code

Please fork the repository, commit changes to your fork, and create a pull request.
Please describe in the pull request what changes were made and why -- reference all issue that the change is motivated by.
Create one pull request for each fixed bug or feature.
Use a [Feature Branch Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/feature-branch-workflow).

### How to Become a Repository Maintainer

We do not plan on adding repository maintainers.

## Contributors

* Vinod Ahuja (Repository Maintainer)
* Georg Link (Repository Maintainer)


## License

Mozilla Public License Version 2.0

We chose this license because the Bugmark Exchange uses it.

Please add the license at the top of every source code file, like this: `SPDX-License-Identifier: MPL-2.0`
