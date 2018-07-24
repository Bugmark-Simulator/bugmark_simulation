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

To be successful, you'll need good skills with the following tools:
- Git
- Linux command line
- Web development
- PostgresQL
- Ruby/Rails
- Vim, Emacs or some command-line editor
- Tmux (nice to have)

#### Host Machine

We assume that you're using Ubuntu 16.04 as your host machine.  If you're Mac
savvy, you'll be able to get things running on a Mac.

Your host machine can exist in a few different forms:
1) a destop Ubuntu system
2) a Virtual Machine running locally (using Vagrant)
3) a Virtual Machine running in the data center

Of the three options, the best and simplest is 3), running in the data center.
We like Linode - you can allocate a cheap node for development that will cost
$5/month.

WARNING: if you choose to install on a local system (option 1), this
configuration process will install many packages and will make changes to your
user configuration, including:
- adding items to your `.bashrc`, modifying your path
- adding your UserID to `sudoers`

In this case, it is ususally best to use a dedicated user-id.

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

1. Clone the tracker
   `mkdir src; cd src; git clone https://github.com/Bugmark-Simulator/exchange.git`

2. CD to the tracker directory `cd exchange`

#### Development Environment Provisioning

On the host machine:

1. Checkout the dev branch `git checkout -b dev origin/dev`

2. Install ansible `script/dev/provision/install_ansible`

3. Install ansible roles `script/dev/provision/install_roles`

4. Provision the dev machine `script/dev/provision/localhost`

5. Check database status: `systemctl status postgresql`

6. Start a new shell: `bash` (required to load your new user configuration)

#### Application Bootstrap

Follow these steps to bootstrap the app in your development environment.

1. Install ruby gems `gem install bundler; bundle install`

2. Install NPM components: `yarn install`

3. Create databases `bundle exec rails db:create`

4. Run migrations `bundle exec rails db:migrate`

5. Start the tmux development session `script/dev/session`

   A cheat-sheet for tmux navigation is in `~/.tmux.conf`.

#### Host Web Access

1. Get the host IP address `ifconfig`  

2. On your local machine, add the VM IP Address to `/etc/hosts`

3. On your local machine, browse to `http://<hostname>:3000`


### 2. Installation of Simulation Platform
This covers the installation of simulation platform to access Bugmark
Exchange and run the simulation on top of Exchange.

1. On the server, go to `src` directory: `cd ~/src`

2. Git clone the Bugmark Simulator: `git clone https://github.com/Bugmark-Simulator/bugmark_simulation.git`

3. Create `.env` setting file `cd bugmark_simulation/exercise/simulation; cp .env-default .env`

4. Check which directory the `.env` links to and change if desired, then create that directory `cd ~; mkdir trial; cd trial; mkdir simulation; cd ~/src`

5. Run script work_queue_table_scr to create work queue table `./bugmark_simulation/exercises/script/work_queue_table_scr`

6. Run script issue_comments to create issue comments table `./bugmark_simulation/exercises/script/issue_comment_table_scr`

7. Go to the simulation application folder `cd bugmark_simulation/exercises/simulation/webapp/`  

8. Start the simulation platform `./run`

9. On your local machine, browse to `http://<hostname>:4567`

Your platform is ready to go.

## Roadmap

The Software is developed in Summer 2018.

  * [Gantt Chart](https://drive.google.com/open?id=1JTQLed788ZDsbExeyMFnR5Xbcf0TYxwBxNb6ToyxRII)

## How to Contribute

### Report an Issue

Please file an issue in the issue tracker.

### Contribute Code

Please fork the repository, commit changes to your fork, and create a pull request. Please describe in the pull request what changes were made and why -- reference all issue that the change is motivated by. Create one pull request for each fixed bug or feature. Use a [Feature Branch Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/feature-branch-workflow).

### How to Become a Repository Maintainer

We do not plan on adding repository maintainers.

## Contributors

* Vindo Ahuja (Repository Maintainer)
* Georg Link (Repository Maintainer)


## License

Mozilla Public License Version 2.0

We chose this license because the Bugmark Exchange uses it.

Please add the license at the top of every source code file, like this: `SPDX-License-Identifier: Apache-2.0`
