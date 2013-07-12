#!/usr/bin/ruby

require "rubygems"; 
require 'trollop'
require "json"; 
require 'term/ansicolor'
include Term::ANSIColor

opts = Trollop::options do

  version "jam 0.1.0 (c) 2013 Alexey Melezhik"
  banner <<-EOS
smart glue between pinto and your scm.

Usage:
       ./jam.rb [options]
where [options] are:
EOS

    opt :p, "path to project", :type => :string
    opt :fast, "run is fast mode, skip some build steps", :default => false
end

project_id = "#{Dir.pwd}/#{opts[:p]}"
local_lib = "#{project_id}/cpanlib"

if (opts[:p].nil? || opts[:p].empty?)
    Trollop::die :p, "must be set"
end


config = JSON.parse(File.read("#{project_id}/jam.json"))

config['sources'].each do |src|


    cmd = "cd #{project_id}/#{src} && rm -rf cpanlib && svn up"
    st = system(cmd) == true or  raise "failed do cmd: #{cmd}" 


    cmd = "eval $(perl -Mlocal::lib=#{local_lib}) &&  cd #{project_id}/#{src} && rm -rf *.gz && rm -rf MANIFEST && perl Build.PL --quiet 1>/dev/null  && ./Build manifest --quiet 2>/dev/null 1>/dev/null  && ./Build dist --quiet 1>/dev/null"
    system(cmd) == true or raise "failed do cmd: #{cmd}"

    cmd ="cd #{project_id}/#{src}/ && pinto list -s #{config['stack']}  -D `ls *.gz` --format %f | grep  `ls *.gz` -q"
    distro_exists = system(cmd)

    if distro_exists == false
	puts dark { blue  { bold {  "add #{src} to pinto for the first time" } } }
        cmd ="cd #{project_id}/#{src} && pinto add -s #{config['stack']} -v `ls *.gz`"
	system(cmd) == true or raise "failed do cmd: #{cmd}"
    elsif distro_exists == true && opts[:fast] == false

	puts dark { magenta  { bold {  "delete #{src} from pinto" } } }
        cmd ="cd #{project_id}/#{src}/ && pinto delete -v PINTO/`ls *.gz`"
	system(cmd) == true or raise "failed do cmd: #{cmd}"

	puts dark { blue  { bold {  "add #{src} to pinto" } } }
        cmd ="cd #{project_id}/#{src} && pinto add -s #{config['stack']} -v `ls *.gz`"
	system(cmd) == true or raise "failed do cmd: #{cmd}"
    end


end


config['sources'].each do |src|
    puts blue { bold { "compile #{src}" } }
    cmd = "cd #{project_id}/#{src} && export PERL5LIB=/usr/local/rle/lib/perl5 && cpanm --mirror file://$PINTO_REPOSITORY_ROOT/stacks/#{config['stack']} --mirror-only -q -L #{local_lib} PINTO/`ls *.gz`"
    system(cmd) == true or raise "failed do cmd: #{cmd}"
end


puts yellow { bold {  "make distributive from #{config['application']}" } }
cmd = "eval $(perl -Mlocal::lib=#{local_lib}) && cd #{project_id}/#{config['application']} && rm -rf cpanlib && mkdir cpanlib/ && cp -r #{local_lib}/* cpanlib/ && rm -rf *.gz && ./Build realclean --quiet 1>/dev/null && perl Build.PL --quiet 1>/dev/null && ./Build manifest --quiet 2>/dev/null 1>/dev/null && ./Build dist --quiet 1>/dev/null"
system(cmd) == true or raise "failed do cmd: #{cmd}"

