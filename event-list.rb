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
require 'json'
require 'yaml'
require 'nokogiri'
require 'chronic'

class Config
  def initialize
    @options = {
      "debug" => false,
      "config_file" => "event-list-config.yaml",
      "output_file" => "_index.md",
      "abbrev_file" => "abbrev.md",
      "json_file" => "data.json",
    }
    OptionParser.new do |parser|
      parser.banner = "Usage: #{$0} [options]"
      
      parser.on("-d", "--[no-]debug", "Show debug messages and read from debug URLs") do |v|
        @options["debug"] = v
      end
      parser.on("-c", "--config-file=FILE", "configuration/sources file") do |f|
        @options["config_file"] = f
      end
      parser.on("-o", "--output-file=FILE", "main output file") do |f|
        @options["output_file"] = f
      end
      parser.on("-a", "--abbrev-file=FILE", "abbreviation output file") do |f|
        @options["abbrev_file"] = f
      end
      parser.on("-j", "--json-file=FILE", "JSON data dump") do |f|
        @options["json_file"] = f
      end
    end.parse!
    cfdata = YAML.load(File.read(@options["config_file"]))
    @options.merge!(cfdata)
  end

  def method_missing(name)
    o = name.to_s
    raise "unknown option #{name}" unless @options.has_key?(o)
    @options[o]
  end
end

Event = Struct.new('Event', :title, :abbrev, :link, :time_from, :time_to, :tags)

class EventFetcher
  def initialize(src, today, debug = false)
    @src, @today, @debug = src, today, debug
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
          puts "event_fetcher each: time is #{time.inspect}" if @debug
          if time.length == 1
            puts "event_fetcher container each single: time was #{time.inspect}" if @debug
            yield Event.new(title, @abbrev, link, time.first, time.first, @tags)
          else
            first, last = time[0], time[1]
            first = today.to_time if first.to_date < @today
            puts "event_fetcher container each multiple: time was #{time.inspect} first #{first.inspect} last #{last.inspect}" if @debug
            yield Event.new(title, @abbrev, link, first, last, @tags)
          end
        end
      end
    else
      extract(main, @events).each do |event|
        puts "found event" if @debug
        raw_link = extract(event, @link)
        link = @debug ? raw_link : URI::join(@url, raw_link)
        title = extract(event, @title).gsub(/\|/, '\|')
        time = extract_time(event, @timespec)
        if time.length == 1
          puts "event_fetcher normal each single: time was #{time.inspect}" if @debug
          yield Event.new(title, @abbrev, link, time.first, time.first, @tags)
        else
          first, last = time[0], time[1]
          first = @today.to_time if first.to_date < @today
          puts "event_fetcher normal each multiple: time was #{time.inspect} first #{first.inspect} last #{last.inspect}" if @debug
          yield Event.new(title, @abbrev, link, first, last, @tags)
        end
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
    timetext.gsub!(/\s{2,}/m, ' ')
    puts "extract_time: found timetext #{timetext}" if @debug
    time = timetext.split(/\s*-\s*/m)
    puts "extract_time: text time after split #{time.inspect}" if @debug
    time.map! { |t| spec["time"] || spec["datetime"] ? t : t + " 00:00:00" }.map! { |t| Chronic.parse(t) }
    puts "extract_time: time after split #{time.inspect} length #{time.length}" if @debug
    raise "time parse of #{timetext} failed" if time.length == 0
    time
  end
end

config = Config.new
events = []
now = Time.now
today = now.to_date
json_dump = { "sources" => {} }

config.sources.each do |source|
  next unless source["url"]
  json_dump["sources"][source["abbrev"]] = {
    "abbreviation" => source["abbrev"],
    "name" => source["name"],
    "home" => source["home"],
    "events" => [],
  }
  begin
    fetcher = EventFetcher.new(source, today, config.debug)
    fetcher.each do |event|
      events << event
    end
  rescue Exception => e
    if config.debug
      raise
    else
      STDERR.puts "error loading #{source}: #{e.message}"
    end
  end
end

earliest = now - 86400 # yesterday
latest = earliest + 86400 * 180 # 6 months
File.open(config.output_file, "w") do |out|
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
  events.select { |e| e.time_from >= earliest && e.time_from < latest }.sort { |a, b| a.time_from <=> b.time_from }.each do |e|
    days_until = e.time_from.to_date - today
    date = if days_until < 7
             e.time_from.strftime("%A")
           elsif e.time_from.year == now.year
             e.time_from.strftime("%A %B %d")
           else
             e.time_from.strftime("%A %B %d %Y")
           end
    if date != cur_date
      cur_date = date
    else
      date = ""
    end
    time = if e.time_from.hour == 0 && e.time_from.min == 0
             ""
           else
             e.time_from.strftime("%H:%M")
           end
    out.puts "| #{date} | #{time} | [#{e.title}](#{e.link}) ([#{e.abbrev}](/about##{e.abbrev})) |"
    json_dump["sources"][e.abbrev]["events"] << {
      "title" => e.title,
      "link" => e.link,
      "source" => e.abbrev,
      "time" => e.time_from.iso8601,
    }
  end
end

File.open(config.abbrev_file, "w") do |out|
  out.puts <<HEADER
---
title: "Abbreviations"
date: #{ now.iso8601 }
draft: false
---

This page currently supports events found on these sites.

|   |       | |
|:--------------|:------|:--|
HEADER
  config.sources.sort { |a, b| a["abbrev"] <=> b["abbrev"] }.each do |s|
    out.puts "| **#{s["abbrev"]}** | [#{s["name"]}](#{s["home"]}) | #{s["note"] ? "*"+s["note"]+"*" : ""}"
  end
  out.puts <<FOOTER

_Last updated #{now}_
FOOTER
end

File.open(config.json_file, "w") do |json|
  json.puts json_dump.to_json
end
