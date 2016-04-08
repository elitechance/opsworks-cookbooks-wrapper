#
# Cookbook Name:: opsworks-cookbooks-wrapper
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

include_recipe 'apt'

package 'curl' do
  action:install
end

package 'monit' do
  action:install
end

package 'g++' do
  action:install
end

user 'aws' do
  home '/home/aws'
  shell '/bin/bash'
  password '$asdfasdfsadfasdfsadfasdfsadfasdfasdfASDFASDF'
end

group 'aws' do
  action :modify
  append true
end

user 'deploy' do
  home '/home/deploy'
  shell '/bin/bash'
  password '$asdfasdfsadfasdfsadfasdfsadfasdfasdfASDFASDF'
end

group 'deploy' do
  action :modify
  append true
end

cookbook_file '/usr/local/bin/create-directories.sh' do
  source 'create-directories.sh'
  mode '0775'
  action:create
end

execute 'configure_directories' do
  command "/usr/local/bin/create-directories.sh"
  ignore_failure true
end

cookbook_file '/var/lib/aws/opsworks/client.yml' do
  source 'client.yml'
  mode '0664'
  action:create
end

cookbook_file '/opt/aws/opsworks/current/bin/downloader.sh' do
  source 'downloader.sh'
  mode '0775'
  action:create
end

