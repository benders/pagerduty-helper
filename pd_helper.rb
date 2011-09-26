#!/usr/bin/env ruby -KU

require 'rubygems'
require 'bundler'
Bundler.setup

require 'date'
require 'time'
require 'json'
require 'sinatra'
require 'erb'
require 'haml'
require 'yaml'

since_date = (Date.today - 14).to_s
until_date = (Date.today + 70).to_s

def time_string(time)
  Time.parse(time).strftime("%Y%m%dT%H%M%SZ")
end

config_file = 'pd_helper.yml'
config = YAML.load(ERB.new(IO.read(config_file)).result)
SUBDOMAIN = config['pagerduty_domain']
AUTH_USER = config['pagerduty_user']
AUTH_PASS = config['pagerduty_pass']
SCHEDULES = config['on_call_schedules']
THIS_SITE = config['this_site']

Event = Struct.new(:summary, :start, :end, :url)

get '/' do
  haml :how_to_use
end

get %r{/users/(P[A-Z0-9]+).ics} do |user_id|
  content_type params[:text] ? :text : 'text/calendar'
  @user_id = user_id
  @events = []

  SCHEDULES.each_pair do |schedule_id,schedule_name|
    api_url = "https://#{SUBDOMAIN}.pagerduty.com/api/v1/schedules/#{schedule_id}/entries"
    api_url += "?since=#{since_date}&until=#{until_date}&user_id=#{user_id}"
    api_url += "&overflow=true"
    api_url += "&fields=start,end"
    command = "curl -s --connect-timeout 5 --max-time 15 --basic --user '#{AUTH_USER}:#{AUTH_PASS}' '#{api_url}'"
    # STDERR.print "RUNNING:\t#{command}"
    # start_time = Time.now
    response_string = `#{command}`
    # STDERR.print "\t(#{'%0.2f' % (Time.now - start_time)}s)\n"
    on_call = JSON.parse(response_string)
    on_call['entries'].each do |entry|
      event = Event.new
      event.summary = schedule_name
      event.start = time_string(entry['start'])
      event.end = time_string(entry['end'])
      event.url = "https://#{SUBDOMAIN}.pagerduty.com/schedule/rotations/#{schedule_id}"
      @events << event
    end
  end
  erb :user_vcalendar
end