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

require 'open-uri'
require 'yaml'
require 'nokogiri'
require 'chronic'

Event = Struct.new('Event', :title, :abbrev, :link, :time, :tags)

class EventFetcher
  def initialize(src)
    @src = src
    @name, @abbrev, @tags, @url = [
      "name", "abbrev", "tags", "url"
    ].map { |k| @src[k] }
    @main, @event, @link, @title = [
      "main", "event", "link", "title"
    ].map { |k| @src["finders"][k] }
    @timespec = [
      "date", "time", "datetime"
    ].map { |k| [k, @src["finders"][k]] }.to_h
  end

  def each
    doc = Nokogiri::HTML(URI.open(@src["url"]))
    main = extract(doc, @main).first
    extract(main, @event).each do |event|
      link = extract(event, @link)
      title = extract(event, @title)
      time = extract_time(event, @timespec)
      yield Event.new(title, @abbrev, link, time, @tags)
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
    begin
      item = from
      if spec["css"]
        item = item.css(spec["css"])
      end
      if spec["attr"]
        item = item.attribute(spec["attr"])
      end
      ensure_array(spec["methods"]).each do |method|
        item = item.send(method)
      end
      ensure_array(spec["remove"]).each do |remove|
        item.gsub!(/#{remove}/m, "")
      end
      item
    rescue NoMethodError
      "unknown"
    end
  end

  def extract_time(from, spec)
    timetext = ""
    if spec["date"]
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

config = YAML.load(File.read("event-list-config.yaml"))
events = []
config["sources"].each do |source|
  fetcher = EventFetcher.new(source)
  fetcher.each do |event|
    events << event
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

| Abbreviation | Name |
|--------------|------|
HEADER
  config["sources"].sort { |a, b| a["abbrev"] <=> b["abbrev"] }.each do |s|
    out.puts "| #{s["abbrev"]} | [#{s["name"]}](#{s["home"]}) |"
  end
  out.puts <<FOOTER
_Last updated #{now}_
FOOTER
end
