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

require 'set'
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
      "only" => nil,
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
      parser.on("--only=ABBREV", "only process this source") do |o|
        @options["only"] = o.downcase
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

class Filter
  attr_reader :matcher
  
  def initialize(h)
    raise "need matcher" unless h.has_key?("match")
    @matcher = h["match"]
    raise "need rules" unless h["rules"].is_a?(Array)
    @rules = h["rules"]
  end

  # return true if we should filter out this event
  def filtered(data)
    @rules.each do |rule|
      if rule.has_key?("exclude")
        return true if data =~ /#{rule["exclude"]}/
      elsif rule.has_key?("include")
        return true unless data =~ /#{rule["include"]}/
      else
        raise "bad rule set #{@rules.inspect}"
      end
    end
    return false
  end
end

class EventFetcher
  def initialize(src, today, debug = false)
    @src, @today, @debug = src, today, debug
    @name, @abbrev, @tags, @url, @page_suffix = [
      "name", "abbrev", "tags", @debug ? "debug_url" : "url",
      @debug ? "debug_page_suffix" : "page_suffix"
    ].map { |k| @src[k] }
    @first_page = @src.has_key?("first_page") ? @src["first_page"].to_i : 1
    @max_page = @src.has_key?("max_page") ? @src["max_page"].to_i : 10
    @main, @date_containers, @events, @link, @title = [
      "main", "date_containers", "events", "link", "title"
    ].map { |k| @src["finders"][k] }
    @filters = (@src["finders"]["filters"] || []).map { |h| Filter.new(h) }
    @timespec = [
      "date", "time", "datetime", "range-sep"
    ].map { |k| [k, @src["finders"][k]] }.to_h
  end

  def page_url(page)
    raise "bad page number" if !page.is_a?(Integer) || page < @first_page
    return @url if page == @first_page
    raise "no pages" if @page_suffix.nil?
    "#{@url}#{@page_suffix}#{page}"
  end

  def single_page
    @page_suffix.nil?
  end

  def yield_event(latest_time, url, event_doc, time, seen, &block)
    throw :done if time.first > latest_time
    return if @filters.any? { |filter|
      filter.filtered(extract(event_doc, filter.matcher))
    }
    puts "yield_event: finding link" if @debug
    raw_link = extract(event_doc, @link)
    link = begin
             @debug ? raw_link : URI::join(@url, raw_link)
           rescue URI::InvalidURIError
             url # replace bad URLs with current events page
           end
    puts "yield_event: found link #{link.inspect}" if @debug
    puts "yield_event: finding title" if @debug
    title = extract(event_doc, @title).gsub(/\|/, '\|')
    puts "yield_event: found title #{title.inspect}" if @debug
    hashcode = title.hash ^ time.hash
    if seen.include?(hashcode)
      puts "yield_event: hashcode #{hashcode} already found" if @debug
      throw :done
    else
      puts "yield_event: added new hashcode #{hashcode}" if @debug
      seen << hashcode
    end
    if time.length == 1
      puts "yield_event single: time was #{time.inspect}" if @debug
      yield Event.new(title, @abbrev, link, time.first, time.first, @tags)
    else
      first, last = time[0], time[1]
      puts "yield_event multiple: time was #{time.inspect} first #{first.inspect} last #{last.inspect}" if @debug
      first = @today.to_time if first.to_date < @today && last.to_date >= @today
      puts "yield_event multiple: time was #{time.inspect} corrected first #{first.inspect} last #{last.inspect}" if @debug
      yield Event.new(title, @abbrev, link, first, last, @tags)
    end
  end
  
  def each(latest_time, &block)
    page = @first_page
    seen = Set.new
    catch (:done) do
      loop do
        url = page_url(page)
        puts "reading #{url}"
        doc = begin
                Nokogiri::HTML(URI.open(url))
              rescue Errno::ENOENT
                puts "#{url} not found, stopping" if @debug
                throw :done
              end
        page_event_count = 0
        main = extract(doc, @main).first
        if @date_containers
          # each date has a container with multiple timed events
          c = begin
                extract(main, @date_containers)
              rescue NoMethodError
                puts "date containers not found, give up" if @debug
                throw :done
              end
          puts "Found containers #{c.class}" if @debug
          c.each do |container|
            puts "found date container #{container.class}" if @debug
            date = extract(container, @timespec["date"])
            puts "found date #{date} for container" if @debug
            extract(container, @events).each do |event_doc|
              puts "found event #{event_doc.class}" if @debug
              time = extract_time(event_doc, @timespec, date)
              puts "yield_event: time is #{time.inspect}" if @debug
              page_event_count += 1
              yield_event(latest_time, url, event_doc, time, seen, &block)
            end
          end
        else
          i = 0
          e = begin
                extract(main, @events)
              rescue NoMethodError
                puts "events not found, give up" if @debug
                throw :done
              end
          e.each do |event_doc|
            i += 1
            puts "found event" if @debug
            time = extract_time(event_doc, @timespec)
            page_event_count += 1
            yield_event(latest_time, url, event_doc, time, seen, &block)
          end
        end
        throw :done if single_page # give up now unless we are multi-page
        throw :done if page_event_count == 0 # give up if we found nothing in the last page
        page += 1
        throw :done if page > @max_page
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
      ensure_array(spec["replace"]).each do |replace|
        rep = replace.is_a?(Array) ? replace : [ replace,  ""]
        puts "replace #{replace.inspect} becomes #{rep.inspect}" if @debug
        item.gsub!(/#{rep.first}/m, rep.last)
        puts "after replace #{replace.inspect} #{item.inspect}" if @debug
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
    puts "extract_time: spec is #{spec.inspect}" if @debug
    range_sep = spec["range-sep"] || "-"
    timetext.gsub!(/\s{2,}/m, ' ')
    puts "extract_time: found timetext #{timetext}" if @debug
    split = /\s*#{range_sep}\s*/m
    puts "extract_time: about to split timetext with #{split.inspect}" if @debug
    timetextary = timetext.split(split)
    raise "too many time components #{timetextary.inspect}" unless timetextary.length <= 2
    puts "extract_time: text time after split #{timetextary.inspect}" if @debug
    time = [ Chronic.parse(spec["time"] || spec["datetime"] ? timetextary[0] : timetextary[0] + " 00:00:00") ]
    if timetextary.length > 1
      time.push(Chronic.parse(
                  if spec["time"] || spec["datetime"]
                    if timetextary[1] =~ /^\d{1,2}:/ # assume it's a time only
                      time[0].to_date.to_s + " " + timetextary[1]
                    else
                      timetextary[1]
                    end
                  else # just date
                    timetextary[1] + " 00:00:00"
                  end
                )
               )
    end
    timetextary.map! { |t| spec["time"] || spec["datetime"] ? t : t + " 00:00:00" }.map! { |t| Chronic.parse(t) }
    puts "extract_time: time after split #{timetextary.inspect} length #{timetextary.length}" if @debug
    raise "time parse of #{timetext} failed" if timetextary.length == 0
    timetextary
  end
end

config = Config.new
events = []
now = Time.now
today = now.to_date
json_dump = {
  "last_updated" => now.iso8601,
  "sources" => [],
}

earliest = today.to_time # midnight this morning
latest = earliest + 86400 * 180 # 6 months

config.sources.each do |source|
  next unless source["url"]
  next unless config.only.nil? || (config.only == source["abbrev"].downcase)
  json_dump["sources"] << {
    "abbreviation" => source["abbrev"],
    "name" => source["name"],
    "home" => source["home"],
    "events" => [],
  }
  fetch_count = 0
  begin
    fetcher = EventFetcher.new(source, today, config.debug)
    fetcher.each(latest) do |event|
      fetch_count += 1
      events << event
      json_dump["sources"].last["events"] << {
      "title" => event.title,
      "link" => event.link,
      "source" => event.abbrev,
      "time" => event.time_from.iso8601,
    }
    end
  rescue Exception => e
    raise
    if config.debug
      raise
    else
      STDERR.puts "error loading #{source}: #{e.class} #{e.message}"
    end
  end
  source["note"] = fetch_count == 0 ? "Error: unable to fetch any events" : "#{fetch_count} events found"
end

File.open(config.output_file, "w") do |out|
  out.puts <<HEADER
---
title: "Events"
date: #{ now.iso8601 }
draft: false
---

| When  |  | Source | Event |
|------:|-:|:-------|:------|
HEADER
  cur_date = nil
  events.select { |e| e.time_from >= earliest && e.time_from < latest }.sort { |a, b| a.time_from <=> b.time_from }.each do |e|
    days_until = e.time_from.to_date - today
    date = if days_until == 0
             "Today (#{e.time_from.strftime("%a")})"
           elsif days_until == 1
             "Tomorrow (#{e.time_from.strftime("%a")})"
           elsif days_until < 7
             e.time_from.strftime("%A")
           elsif e.time_from.year == now.year
             e.time_from.strftime("%a %b %d")
           else
             e.time_from.strftime("%a %b %d %Y")
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
    out.puts "| #{date} | #{time} | [#{e.abbrev}](/about##{e.abbrev}) | [#{e.title}](#{e.link}) |"
  end
  out.puts "\nA machine-readable version of this page is available [here](/data.json)"
end

File.open(config.abbrev_file, "w") do |out|
  out.puts <<HEADER
---
title: "Abbreviations"
date: #{ now.iso8601 }
draft: false
---

This page knows about events on these sites.

|   |       | |
|:--------------|:------|:--|
HEADER
  config.sources.sort { |a, b| a["abbrev"] <=> b["abbrev"] }.each do |s|
    out.puts "| **#{s["abbrev"]}** | [#{s["name"]}](#{s.has_key?("home") ? s["home"] : s["url"]}) | #{s["note"] ? "*"+s["note"]+"*" : ""}"
  end
  out.puts <<FOOTER

_Last updated #{now}_
FOOTER
end

File.open(config.json_file, "w") do |json|
  json.puts json_dump.to_json
end
