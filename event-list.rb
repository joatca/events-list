#!/usr/bin/env ruby

# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along with this program. If not, see
# <https://www.gnu.org/licenses/>.

require 'optparse'
require 'open-uri'
require 'yaml'
require 'nokogiri'
require 'chronic'

Event = Struct.new('Event', :title, :abbrev, :link, :time, :tags)

class EventFetcher
  def initialize(src, debug = false)
    @src, @debug = src, debug
    @name, @abbrev, @tags, @url = [
      "name", "abbrev", "tags", @debug ? "debug_url" : "url"
    ].map { |k| @src[k] }
    @main, @date_containers, @events, @link, @title = [
      "main", "date_containers", "events", "link", "title"
    ].map { |k| @src["finders"][k] }
    @timespec = [
      "date", "time", "datetime"
    ].map { |k| [k, @src["finders"][k]] }.to_h
  end

  def each
    puts "reading #{@url}" if @debug
    doc = Nokogiri::HTML(URI.open(@url))
    main = extract(doc, @main).first
    if @date_containers
      # each date has a container with multiple timed events
      c = extract(main, @date_containers)
      puts "Found containers #{c.class}" if @debug
      c.each do |container|
        puts "found date container #{container.class}" if @debug
        date = extract(container, @timespec["date"])
        puts "found date #{date} for container" if @debug
        extract(container, @events).each do |event|
          puts "found event #{event.class}" if @debug
          raw_link = extract(event, @link)
          link = @debug ? raw_link : URI::join(@url, raw_link)
          title = extract(event, @title).gsub(/\|/, '\|')
          time = extract_time(event, @timespec, date)
          yield Event.new(title, @abbrev, link, time, @tags)
        end
      end
    else
      extract(main, @events).each do |event|
        puts "found event" if @debug
        raw_link = extract(event, @link)
        link = @debug ? raw_link : URI::join(@url, raw_link)
        title = extract(event, @title).gsub(/\|/, '\|')
        time = extract_time(event, @timespec)
        yield Event.new(title, @abbrev, link, time, @tags)
      end
    end
  end

  def ensure_array(x)
    case x
    when String
      [ x ]
    when Array
      x
    else
      []
    end
  end
  
  # fetch contents of something depending on which attribs are in the spec
  def extract(from, spec)
    puts "extract from #{from.class} spec #{spec}" if @debug
    begin
      item = from
      puts "initial item #{item.class}" if @debug
      if spec["css"]
        item = item.css(spec["css"])
        puts "after css #{item.inspect}" if @debug
      end
      if spec["attr"]
        item = item.attribute(spec["attr"])
        puts "after attr #{item.inspect}" if @debug
      end
      ensure_array(spec["methods"]).each do |method|
        item = item.send(method)
        puts "after method #{method} #{item.inspect}" if @debug
      end
      ensure_array(spec["remove"]).each do |remove|
        item.gsub!(/#{remove}/m, "")
        puts "after remove #{remove.inspect} #{item.inspect}" if @debug
      end
      puts "final item #{item.inspect}" if @debug
      item
    # rescue NoMethodError
    #   "unknown"
    end
  end

  def extract_time(from, spec, date_prefix = nil)
    timetext = ""
    if date_prefix && spec["time"]
      timetext += date_prefix + " " + extract(from, spec["time"])
    elsif spec["date"]
      timetext += extract(from, spec["date"])
      if spec["time"]
        timetext += " " + extract(from, spec["time"])
      end
    elsif spec["datetime"]
      timetext += extract(from, spec["datetime"])
    else
      raise "bad date and time spec #{spec.inspect}"
    end
    time = Chronic.parse(timetext)
    raise "Time parse of #{timetext} failed" if time.nil?
    time
  end
end

options = {}
OptionParser.new do |parser|
  parser.banner = "Usage: #{$0} [options]"

  parser.on("-d", "--[no-]debug", "Show debug messages and read from debug URLs") do |v|
    options[:debug] = v
  end
end.parse!

config = YAML.load(File.read("event-list-config.yaml"))
events = []
config["sources"].each do |source|
  begin
    fetcher = EventFetcher.new(source, options[:debug])
    fetcher.each do |event|
      events << event
    end
  rescue Exception => e
    if options[:debug]
      raise
    else
      STDERR.puts "error loading #{source}: #{e.message}"
    end
  end
end

now = Time.now
earliest = now - 86400 # yesterday
latest = earliest + 86400 * 180 # 6 months
File.open(config["output_file"], "w") do |out|
  out.puts <<HEADER
---
title: "Events"
date: #{ now.iso8601 }
draft: false
---

| When  |  | Event (Venue) |
|------:|-:|:--------------|
HEADER
  cur_date = nil
  events.select { |e| e.time >= earliest && e.time < latest }.sort { |a, b| a.time <=> b.time }.each do |e|
    days_until = e.time.to_date - now.to_date
    date = if days_until < 7
             e.time.strftime("%A")
           elsif e.time.year == now.year
             e.time.strftime("%A %B %d")
           else
             e.time.strftime("%A %B %d %Y")
           end
    if date != cur_date
      cur_date = date
    else
      date = ""
    end
    time = if e.time.hour == 0 && e.time.minute == 0
             ""
           else
             e.time.strftime("%H:%M")
           end
    out.puts "| #{date} | #{time} | [#{e.title}](#{e.link}) ([#{e.abbrev}](/about##{e.abbrev})) |"
  end
  out.puts <<FOOTER

_Last updated #{now}_
FOOTER
end

File.open(config["abbrev_file"], "w") do |out|
  out.puts <<HEADER
---
title: "Abbreviations"
date: #{ now.iso8601 }
draft: false
---

This page currently supports events found on these sites.

|   |       |
|:--------------|:------|
HEADER
  config["sources"].sort { |a, b| a["abbrev"] <=> b["abbrev"] }.each do |s|
    out.puts "| **#{s["abbrev"]}** | [#{s["name"]}](#{s["home"]}) |"
  end
  out.puts <<FOOTER

_Last updated #{now}_
FOOTER
end
