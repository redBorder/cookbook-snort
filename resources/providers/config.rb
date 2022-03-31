# Cookbook Name:: snort
#
# Provider:: config
#

action :add do #Usually used to install and configure something
  begin
    cores = new_resource.cores
    memory_kb = new_resource.memory_kb
    enrichment_enabled = new_resource.enrichment_enabled
    cache_dir = new_resource.cache_dir
    config_dir = new_resource.config_dir
    templates_dir = new_resource.templates_dir
    user = new_resource.user
    sensors = new_resource.sensors

    chef_gem 'ruby_dig' do
      action :nothing
    end.run_action(:install)

    #User creation
    user user do
      action :create
    end

    # Directory creation
    directory config_dir do
      owner "root"
      group "root"
      mode 0755
    end

    directory cache_dir do
      owner user
      group user
      mode 0755
    end

    directory templates_dir do
      owner user
      group user
      mode 0755
    end


    # RPM Installation
    yum_package "snort" do
      action :upgrade
    end

    # Memory calculation
    dns_cache_size_mb = [ memory_kb/(4*1024), 10 ].max.to_i
    buffering_max_messages = [ memory_kb/4, 1000 ].max.to_i

    # Templates
    template "/etc/sysconfig/snort" do
      source "snort_sysconfig.erb"
      cookbook "snort"
      owner "root"
      group "root"
      mode 0644
      retries 2
      variables(  :cores => cores,
                  :enrichment_enabled => enrichment_enabled,
                  :cache_dir => cache_dir,
                  :config_file => "#{config_dir}/config.json",
                  :dns_cache_size_mb => dns_cache_size_mb,
                  :user => user,
                  :buffering_max_messages => buffering_max_messages
      )
      notifies :reload, 'service[snort]', :delayed
    end

    template "#{config_dir}/config.json" do
      source "snort_config.erb"
      cookbook "snort"
      owner "root"
      group "root"
      mode 0644
      retries 2
      variables(:sensors => sensors)
      helpers Snort::Renderer
      notifies :reload, 'service[snort]', :delayed
    end

    service "snort" do
      supports :status => true, :start => true, :restart => true, :reload => true, :stop => true
      action [:enable, :start]
    end

    Chef::Log.info("snort cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :remove do #Usually used to uninstall something
  begin
    service "snort" do
      supports :stop => true, :disable => true
      action [:stop, :disable]
    end

    Chef::Log.info("snort cookbook has been processed")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :register do #Usually used to register in consul
  begin
    if !node["snort"]["registered"]
      query = {}
      query["ID"] = "snort-#{node["hostname"]}"
      query["Name"] = "snort"
      query["Address"] = "#{node["ipaddress"]}"
      query["Port"] = 2055
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.set["snort"]["registered"] = true
    end
    Chef::Log.info("snort service has been registered in consul")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do #Usually used to deregister from consul
  begin
    if node["snort"]["registered"]
      execute 'Deregister service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/deregister/snort-#{node["hostname"]} &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.set["snort"]["registered"] = false
    end
    Chef::Log.info("snort service has been deregistered from consul")
  rescue => e
    Chef::Log.error(e.message)
  end
end