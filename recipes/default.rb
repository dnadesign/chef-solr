#
# Cookbook Name:: solr
# Recipe:: default
#
# Copyright 2013, David Radcliffe
#

include_recipe 'java'

src_filename = ::File.basename(node['solr']['url'])
src_filepath = "#{Chef::Config['file_cache_path']}/#{src_filename}"
extract_path = "/opt/solr"
solr_path    = "#{extract_path}/solr-#{node['solr']['version']}"

remote_file src_filepath do
  source node['solr']['url']
  action :create_if_missing
end

bash 'unpack_solr' do
  cwd ::File.dirname(src_filepath)
  code <<-EOH
    mkdir -p #{extract_path}
    tar xzf #{src_filename} -C #{extract_path}
  EOH
  not_if { ::File.exists?(extract_path) }
end

directory node['solr']['data_dir'] do
  owner 'root'
  group 'root'
  action :create
end

case node['platform']
when 'debian', 'ubuntu'
  service 'solr' do
    provider Chef::Provider::Service::Upstart
    supports :start => true, :restart => true, :stop => true
  end

  template '/etc/init/solr.conf' do
    source 'solr.conf.erb'
    mode 0664
    owner 'root'
    group 'root'
    variables(
      :solr_dir => solr_path,
      :solr_home => node['solr']['data_dir'],
      :pid_file => '/var/run/solr.pid',
      :log_file => '/var/log/solr.log'
    )
    notifies :restart, resources(:service => 'solr')
  end
when 'redhat', 'centos', 'fedora'
  template '/var/lib/solr.start' do
    source 'solr.start.erb'
    owner 'root'
    group 'root'
    mode '0755'
    variables(
      :solr_dir => extract_path,
      :solr_home => node['solr']['data_dir'],
      :pid_file => '/var/run/solr.pid',
      :log_file => '/var/log/solr.log'
    )
  end

  template '/etc/init.d/solr' do
    source 'initd.erb'
    owner 'root'
    group 'root'
    mode '0755'
  end

  service 'solr' do
    supports :restart => true, :status => true
    action [:enable, :start]
  end
end

template "solr.xml" do
  path "#{node['solr']['data_dir']}/solr.xml"
  owner 'root'
  group 'root'
  source 'solr.xml.erb'
  cookbook 'solr'
  variables(
    :collections => Array(node['solr']['collections'])
  )
  action :create_if_missing
  notifies :restart, resources(:service => 'solr')
end
