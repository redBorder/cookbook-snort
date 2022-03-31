# Cookbook Name:: snort
#
# Resource:: config
#

actions :add, :remove
default_action :add

attribute :cores, :kind_of => Integer, :default => 1
attribute :memory_kb, :kind_of => Integer, :default => 102400
attribute :enrichment_enabled, :kind_of => [TrueClass, FalseClass], :default => true
attribute :cache_dir, :kind_of => String, :default => "/var/cache/snort"
attribute :templates_dir, :kind_of => String, :default => "/var/cache/snort/templates"
attribute :config_dir, :kind_of => String, :default => "/etc/snort"
attribute :user, :kind_of => String, :default => "snort"
attribute :sensors, :kind_of => Hash, :default => []


attribute :sensor_id, :kind_of => Integer, :default => 0