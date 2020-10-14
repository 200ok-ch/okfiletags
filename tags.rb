#!/usr/bin/env ruby
# coding: utf-8

require 'optparse'
require "readline"

def find_tags_for(path)
  tags = []
  Dir.glob(path).each do |file|
    file = File.basename(file, ".*")
    file_tags = file.split('--')[1]&.split(',')&.map(&:strip)
    tags << file_tags if file_tags
  end

  tags = tags.flatten.compact
end

def count_tags(tags)
  tags.inject({}) { |acc, tag|
    acc[tag] = acc[tag].to_i + 1
    acc
  }
end

def list_pretty_tags(path = nil)
  tags = find_tags_for(path || '**/*')
  counts = count_tags(tags)

  pretty_counts = counts.sort_by { |tag, count| count }
    .reverse
    .map do |tag, count|
      "#{tag}(#{count})"
    end

  puts pretty_counts
end

def filename_with_tags(file, tags)
  "#{file.split('--')[0]}--#{tags.join(',')}#{File.extname(file)}"
end

def add_tags_to_file(new_tags, file)
  (puts "Needs a FILE input; i.e. `-a tag filename`"; exit) unless file

  tags = find_tags_for(file)
  tags << new_tags.split(',')&.map(&:strip)
  tags = tags.flatten.uniq.sort

  new_filename = filename_with_tags(file, tags)
  `mv #{file} #{new_filename}`
end

def read_and_add_tags_for(file, tags_path = nil)
  (puts "File '#{file}' does not exist."; exit 1) unless File.exist?(file)

  tags = find_tags_for(tags_path || '**/*')
  Readline.completion_proc = proc do |input|
    tags.select { |tag| tag.start_with?(input) }
  end

  puts "Add new tags:"
  input = Readline.readline("> ", false)
  add_tags_to_file(input, file)
end


OptionParser.new do |opts|
  opts.banner = 'Usage: tags.rb [options]'
  opts.on('-l', "--list [PATH]", 'List file tags (optionally for PATH)') do |path|
    list_pretty_tags(path)
    exit
  end
  opts.on('-a', '--add-tags TAGS FILE', 'Add comma-separated TAGS to FILE') do |tags|
    add_tags_to_file(tags, ARGV[0])
    exit
  end
  opts.on('-i', '--add-tags-interactively FILE', 'Auto-complete tags and add them to FILE') do |file|
    read_and_add_tags_for(file)
    exit
  end
end.parse!
