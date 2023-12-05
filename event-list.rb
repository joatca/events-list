#!/usr/bin/env ruby

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

cur_date = nil
File.open(config["output_file"], "w") do |out|
  out.puts <<-HEADER
  ---
  title: "Events"
  date: #{ now.iso8601 }
  draft: false
  ---
  _Last updated #{now}_

  | When | Venue | Event |
  |------|-------|-------|
  HEADER
  events.select { |e| e.time >= earliest && e.time < latest }.sort { |a, b| a.time <=> b.time }.each do |e|
    out.puts "| #{ e.time } | #{ e.abbrev } | #{ e.title } |"
  end
end

