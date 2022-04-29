# Cookbook Name:: snort
#
# Resource:: config
#

actions :add, :remove
default_action :add

attribute :sensor_id, :kind_of => Integer, :default => 0
attribute :groups, :kind_of => Array, :default => []