log 'Configure Applications Config Directory'

node[:deploy].each do |application, deploy|
  log "Create shared/config directory for for #{deploy[:deploy_to]}"
  directory "#{deploy[:deploy_to]}/shared/config" do
    mode '755'
    action :create
    recursive true
  end
end

