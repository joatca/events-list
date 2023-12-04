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
      if spec.has_key?("css")
        item = item.css(spec["css"])
      end
      if spec.has_key?("attr")
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
    if spec.has_key?("date")
      timetext += extract(from, spec["date"])
      if spec.has_key?("time")
        timetext += " " + extract(from, spec["time"])
      end
    elsif spec.has_key?("datetime")
      timetext += extract(from, spec["datetime"])
    else
      raise "bad date and time spec #{spec.inspect}"
    end
    time = Chronic.parse(timetext)
    raise "Time parse of #{timetext} failed" if time.nil?
    time
  end
end

sources = YAML.load(File.read("event-sources.yaml"))
events = []
sources.each do |source|
  fetcher = EventFetcher.new(source)
  fetcher.each do |event|
    events << event
  end
end

puts events.select { |e| e.time >= Time.now - 86400 }.sort { |a, b| a.time <=> b.time }.join("\n")
