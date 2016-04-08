## opsworks-cookbooks-wrapper

This will help your run opsworks-cookbooks locally using Chef+Kitchen+Vagrant

### To Test
-------

$ git clone https://github.com/elitechance/opsworks-cookbooks-wrapper.git
$ git clone https://github.com/aws/opsworks-cookbooks.git
$ cd opsworks-cookbooks-wrapper
$ cp .kitchen.sample.yml .kitchen.yml
$ cp Berksfile.sample Berksfile
$ cp metadata.sample.rb metadata.rb

### This will simulate OpsWorks NodeJs Setup Recipes
$ chef exec kitchen setup


### Tested In
Ubuntu 14.04

## KNOWN BUGS
----------
The first time you run _$ chef exec kitchen setup_, you will encounter errors saying:

>Running handlers:
[2016-04-08T17:08:34+00:00] ERROR: Running exception handlers
Running handlers complete
[2016-04-08T17:08:34+00:00] ERROR: Exception handlers complete
Chef Client failed. 43 resources updated in 01 minutes 02 seconds
[2016-04-08T17:08:34+00:00] FATAL: Stacktrace dumped to /tmp/kitchen/cache/chef-stacktrace.out
[2016-04-08T17:08:34+00:00] FATAL: Please provide the contents of the stacktrace.out file if you file a bug report
[2016-04-08T17:08:34+00:00] ERROR: ruby_block[Fallback for remote_file[/tmp/rubygems-2.2.2.tgz]] (opsworks_rubygems::default line 5) had an error: NoMethodError: remote_file[/tmp/rubygems-2.2.2.tgz] (opsworks_rubygems::default line 1) had an error: NoMethodError: undefined method `to_sym' for [:create]:Array
[2016-04-08T17:08:34+00:00] FATAL: Chef::Exceptions::ChildConvergeError: Chef run process exited unsuccessfully (exit code 1)

Just run again:
$ chef exec kitchen setup
