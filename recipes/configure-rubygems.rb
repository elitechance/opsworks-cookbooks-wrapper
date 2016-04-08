log "Install rubygems version #{node['opsworks_rubygems']['version']}"

template '/usr/local/bin/setup-rubygems.sh' do
  source 'setup-rubygems.sh.erb'
  mode '0775'
  variables({:version => node['opsworks_rubygems']['version']})
  action :create
end

execute 'configure_rubygems' do
  command "/usr/local/bin/setup-rubygems.sh"
  ignore_failure true
end

