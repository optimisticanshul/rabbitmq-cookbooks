# frozen_string_literal: true
#
# Cookbook Name:: rabbitmq_test
# Recipe:: lwrps
#
# Copyright 2013, Chef Software, Inc. <legal@chef.io>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

chef_gem 'bunny' do
  action :install
end

node.normal['rabbitmq']['clustering']['enable'] = true
node.normal['rabbitmq']['open_file_limit'] = 65000
node.normal['rabbitmq']['clustering']['use_auto_clustering'] = true

include_recipe 'rabbitmq::default'

# force the rabbitmq restart now, then start testing
execute 'sleep 10' do
  notifies :restart, "service[#{node['rabbitmq']['service_name']}]", :immediately
end

include_recipe 'rabbitmq::mgmt_console'

# HACK: Give rabbit time to spin up before the tests, it seems
# to be responding that it has started before it really has
execute 'sleep 10' do
  action :nothing
  subscribes :run, "service[#{node['rabbitmq']['service_name']}]", :delayed
end


include_recipe 'rabbitmq::plugin_management'
include_recipe 'rabbitmq::virtualhost_management'
include_recipe 'rabbitmq::policy_management'
include_recipe 'rabbitmq::user_management'

rabbitmq_user "root" do
  password "RooT@NearBY2016"
  action :add
end

rabbitmq_user "root" do
  vhost ["/"]
  permissions ".* .* .*"
  action :set_permissions
end

rabbitmq_user "root" do
  tag "admin"
  action :set_tags
end

rabbitmq_plugin 'rabbitmq_management' do
  action :enable
  notifies :restart, "service[#{node['rabbitmq']['service_name']}]", :immediately # must restart before we can download
end

remote_file '/usr/local/bin/rabbitmqadmin' do
  source 'http://localhost:15672/cli/rabbitmqadmin'
  mode '0755'
  action :create
end

rabbitmq_policy 'rabbitmq_cluster' do
  pattern 'cluster.*'
  params 'ha-mode' => 'all', 'ha-sync-mode' => 'automatic'
  apply_to 'queues'
  action :set
end

