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
    
    
    groups = node["redborder"]["snort"]["groups"].keys.map{|x| x.to_i}
    used_segments = []
         
    node["redborder"]["snort"]["groups"].each do |id, original_group|
      group = node["redborder"]["snort"]["groups"][id].to_hash.clone
      bindings = group["bindings"].keys.map{|x| x.to_i}.flatten
      name = (group["name"].nil? ? "default" : group["name"].to_s)
      group["name"]     = name 
      group["segments"] = node["redborder"]["segments"].keys  if group["segments"].nil?
      group["cpu_list"] = 0.upto(node["cpu"]["total"]-1).to_a if group["cpu_list"].nil?
      group["cpu_list"] = (group["cpu_list"].map { |x| x.to_i }).sort.uniq
      group["segments"] = group["segments"].sort.uniq
      group["instances_group"] = id.to_i
      group["segments"] = group["segments"].select{ |x| !used_segments.include?(x) }
  
      if group["cpu_list"].size==0 or group["segments"].size==0 or group["bindings"].nil? or group["bindings"].size==0
        groups.delete(id.to_i)
      else
        used_segments = used_segments + group["segments"]
        
        force_span=false
  
        group["segments"].each do |x|
          if node["redborder"]["segments"][x] and node["redborder"]["segments"][x]["interfaces"]
            force_span=true if node["redborder"]["segments"][x]["interfaces"].keys.size<=1
          end
        end
  
        group["mode"] = "IDS_SPAN" if force_span
    
        [ "snortd" ].each do |s|
          [ "reload", "restart", "stop", "start" ].each do |s_action|
            execute "#{s_action}_#{s}_#{group["instances_group"]}_#{name}" do
              command "/bin/env WAIT=1 /etc/init.d/#{s} #{s_action} #{name}" 
              ignore_failure true
              action :nothing
            end
          end
        end
  
        directory "/etc/snort/#{group["instances_group"]}" do 
          owner "root" 
          group "root"
          mode 0755
          recursive true
          action :create
        end
    
        directory "/var/log/snort/#{group["instances_group"]}" do 
          owner "root" 
          group "root"
          mode 0755
          recursive true
          action :create
        end
  
        directory "/etc/snort/#{group["instances_group"]}/geoips" do 
          owner "root" 
          group "root"
          mode 0755
          action :create
        end
  
        directory "/etc/snort/#{group["instances_group"]}/iplists" do 
          owner "root" 
          group "root"
          mode 0755
          action :create
        end
    
        [ "unicode.map", "classification.config", "reference.config", "sid-msg.map" ]. each do |rfile|
          template "/etc/snort/#{group["instances_group"]}/#{rfile}" do 
            source "#{rfile}.erb"
            cookbook "snort"
            owner "root"
            group "root"
            mode 0644
            action :create_if_missing
            retries 2
          end
        end
  
        template "/etc/snort/#{group["instances_group"]}/gen-msg.map" do
          source "gen-msg.map.erb"
          cookbook "snort"
          owner "root"
          group "root"
          mode 0644
          retries 2
          notifies :run, "execute[restart_snortd_#{group["instances_group"]}_#{name}]", :delayed
        end
  
        template "/etc/snort/#{group["instances_group"]}/interfaces" do
          source "variable.erb"
          cookbook "snort"
          owner "root"
          group "root"
          mode 0644
          retries 2
          variables(:variable => group["segments"].join(" ") )
          notifies :run, "execute[stop_snortd_#{group["instances_group"]}_#{name}]"
          notifies :run, "execute[start_snortd_#{group["instances_group"]}_#{name}]", :delayed
        end
    
        template "/etc/snort/#{group["instances_group"]}/mode" do
          source "variable.erb"
          cookbook "snort"
          owner "root"
          group "root"
          mode 0644
          retries 2
          variables(:variable => group["mode"] )
          notifies :run, "execute[stop_snortd_#{group["instances_group"]}_#{name}]"
          notifies :run, "execute[start_snortd_#{group["instances_group"]}_#{name}]", :delayed
        end
    
        template "/etc/snort/#{group["instances_group"]}/cpu_list" do
          source "variable.erb"
          cookbook "snort"
          owner "root"
          group "root"
          mode 0644
          retries 2
          variables(:variable => group["cpu_list"].join(" ") )
          notifies :run, "execute[restart_snortd_#{group["instances_group"]}_#{name}]", :delayed
        end
  
        template "/etc/snort/#{group["instances_group"]}/snort-common.conf" do
          source "snort-common.conf.erb"
          cookbook "snort"
          owner "root"
          group "root"
          mode 0644
          retries 2
          variables(:sensor_id => sensor_id, :name => name, :group => group)
          notifies :run, "execute[reload_snortd_#{group["instances_group"]}_#{name}]", :delayed
        end
        
        template "/etc/snort/#{group["instances_group"]}/snort.conf" do
          source "snort.conf.erb"
          cookbook "snort"
          owner "root"
          group "root"
          mode 0644
          retries 2
          variables(:sensor_id => sensor_id, :name => name, :group => group)
          notifies :run, "execute[reload_snortd_#{group["instances_group"]}_#{name}]", :delayed
        end
       
        template "/etc/sysconfig/snort-#{group["instances_group"]}" do
          source "snort.erb"
          cookbook "snort"
          owner "root"
          group "root"
          mode 0644
          retries 2
          variables(:sensor_id => sensor_id, :name => name, :group => group)
          notifies :run, "execute[restart_snortd_#{group["instances_group"]}_#{name}]", :delayed
        end
          
        template "/etc/snort/#{group["instances_group"]}/snort-preprocessors-default.conf" do
          source "snort-preprocessors-default.conf.erb"
          cookbook "snort"
          owner "root"
          group "root"
          mode 0644
          retries 2
          variables(:sensor_id => sensor_id, :name => name, :group => group)
          notifies :run, "execute[reload_snortd_#{group["instances_group"]}_#{name}]", :delayed
        end
  
        [ "iplists/zone.info", "geoips/geo.info" ].each do |rfile|
          template "/etc/snort/#{group["instances_group"]}/#{rfile}" do 
            source "empty.erb"
            cookbook "snort"
            owner "root"
            group "root"
            mode 0644
            action :create_if_missing
            retries 2
          end
        end
  
        template "/etc/snort/#{group["instances_group"]}/iplists/iplist_script.sh" do
          source "snort_iplist_script.sh.erb"
          cookbook "snort"
          owner "root"
          group "root"
          mode 0644
          action :create_if_missing
          retries 2
        end
  
        template "/etc/snort/#{group["instances_group"]}/geoips/geoip_script.sh" do
          source "snort_geoip_script.sh.erb"
          cookbook "snort"
          owner "root"
          group "root"
          mode 0644
          action :create_if_missing
          retries 2
        end
  
        default_added=false
  
        group["bindings"].keys.map{|x| x.to_i}.sort.map{|x| "#{x}"}.each do |id| 
  
          vgroup         = group["bindings"][id].to_hash.clone
          vgroup_name    = (vgroup["name"].nil? ? "default" : vgroup["name"].to_s)
          vgroup["name"] = vgroup_name 
          vgroup["id"]   = id
  
          if (!(vgroup["vlan_objects"] and vgroup["vlan_objects"].size>0) and !(vgroup["network_objects"] and vgroup["network_objects"].size>0))
            next if default_added
            default_added=true
          end
  
          vgroup["ipvars"]        = node["redborder"]["snort"]["default"]["ipvars"] if vgroup["ipvars"].empty?
          vgroup["portvars"]      = node["redborder"]["snort"]["default"]["portvars"] if vgroup["portvars"].empty?
  
          directory "/etc/snort/#{group["instances_group"]}/snort-binding-#{id}/dynamicrules" do 
            owner "root" 
            group "root"
            mode 0755
            recursive true
            action :create
          end
  
          template "/etc/snort/#{group["instances_group"]}/snort-binding-#{id}/snort-bindings.conf" do
            source "snort-bindings.conf.erb"
            cookbook "snort"
            owner "root"
            group "root"
            mode 0644
            retries 2
            variables(:sensor_id => sensor_id, :name => vgroup_name, :vgroup => vgroup, :group => group)
            notifies :run, "execute[reload_snortd_#{group["instances_group"]}_#{name}]", :delayed
          end
    
          template "/etc/snort/#{group["instances_group"]}/snort-binding-#{id}/snort.conf" do
            source "snort-binding.conf.erb"
            cookbook "snort"
            owner "root"
            group "root"
            mode 0644
            retries 2
            variables(:sensor_id => sensor_id, :name => vgroup_name, :vgroup => vgroup, :group => group)
            notifies :run, "execute[reload_snortd_#{group["instances_group"]}_#{name}]", :delayed
          end
    
          template "/etc/snort/#{group["instances_group"]}/snort-binding-#{id}/snort-variables.conf" do
            source "snort-variables.conf.erb"
            cookbook "snort"
            owner "root"
            group "root"
            mode 0644
            retries 2
            variables(:sensor_id => sensor_id, :name => vgroup_name, :vgroup => vgroup, :group => group)
            notifies :run, "execute[reload_snortd_#{group["instances_group"]}_#{name}]", :delayed
          end
    
          template "/etc/snort/#{group["instances_group"]}/snort-binding-#{id}/snort-preprocessors.conf" do
            source "snort-preprocessors.conf.erb"
            cookbook "snort"
            owner "root"
            group "root"
            mode 0644
            retries 2
            variables(:sensor_id => sensor_id, :name => vgroup_name, :vgroup => vgroup, :group => group)
            notifies :run, "execute[reload_snortd_#{group["instances_group"]}_#{name}]", :delayed
          end
  
          template "/etc/snort/#{group["instances_group"]}/snort-binding-#{id}/threshold.conf" do
            source "threshold.conf.erb"
            cookbook "snort"
            owner "root"
            group "root"
            mode 0644
            action :create_if_missing
            retries 2
            notifies :run, "execute[reload_snortd_#{group["instances_group"]}_#{name}]", :delayed
          end
    
          [ "snort.rules", "preprocessor.rules", "so.rules", "file_capture.rules" ].each do |rfile|
            template "/etc/snort/#{group["instances_group"]}/snort-binding-#{id}/#{rfile}" do 
              source "empty.erb"
              cookbook "snort"
              owner "root"
              group "root"
              mode 0644
              action :create_if_missing
              retries 2
              notifies :run, "execute[reload_snortd_#{group["instances_group"]}_#{name}]", :delayed
            end
          end

          template "/etc/snort/#{group["instances_group"]}/snort-binding-#{id}/reputation.rules" do
            source "reputation.rules.erb"
            cookbook "snort"
            owner "root"
            group "root"
            mode 0644
            action :create_if_missing
            retries 2
          end
        end
  
        # Delete Vlan files not used
        [
          {:files => "/etc/snort/#{group["instances_group"]}/snort-binding-*", :regex => /\/snort-binding-(\d+)$/}
        ].each do |x|
          Dir.glob(x[:files]).each do |f|
            match = f.match(x[:regex])
            if match and !bindings.include?(match[1].to_i)
              if File.directory?(f)
                directory f do 
                  recursive true
                  action :delete
                end
              else
                file f do 
                  action :delete
                end
              end      
            end
          end
        end
  
        # Delete logs if they are too old
        [
          {:files => "/var/log/snort/#{group["instances_group"]}/instance-*", :regex => /\/instance-(\d+)$/}
        ].each do |x|
          Dir.glob(x[:files]).each do |f|
            match = f.match(x[:regex])
            if ( match and match[1].to_i < group["cpu_list"].size and ( (Time.now - File.stat(f).mtime) > 3600 * 24 * 7 ) )
              # This directory can be deleted
              if File.exists?("#{f}/archive")
                if File.directory?("#{f}/archive")
                  directory "#{f}/archive" do 
                    recursive true
                    action :delete
                  end
                else
                  file "#{f}/archive" do 
                    action :delete
                  end
                end      
              end
            end
          end
        end
      end
    end


    template "/etc/cron.daily/snortlog" do
      source "crondaily_snortlog.erb"
      cookbook "snort"
      owner "root"
      group "root"
      mode 0755
      retries 2
    end

    service "snortd" do
      #service_name node[:redBorder][:snort][:service]
      ignore_failure true
      supports :status => true, :reload => true, :restart => true
      action([:start, :enable])
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
