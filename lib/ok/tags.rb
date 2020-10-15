#!/usr/bin/env ruby
# coding: utf-8

require 'optparse'
require 'readline'
require 'fileutils'

module OK
  module Tags
    class Error < StandardError; end
    extend self

    # oktags uses --[] as the place to save tags. [] does have special
    # meaning for Ruby Dir.glob, though. Hence, it's escaped.
    def escape_glob(s)
      s&.gsub(/[\[\]]/) { |x| "\\" + x }
    end

    def find_tags_for(path = '**/*')
      tags = []
      Dir.glob(escape_glob(path)).each do |file|
        file = File.basename(file, '.*')
        file_tags =
          file.match(/--\[(.*)\]/)&.to_a&.at(1)&.split(',')&.map(&:strip)&.map(
            &:downcase
          )
        tags << file_tags if file_tags
      end

      tags.flatten.compact.sort
    end

    def count_tags(tags)
      tags.inject({}) do |acc, tag|
        acc[tag] = acc[tag].to_i + 1
        acc
      end
    end

    def list_pretty_tags(path = '**/*')
      tags = find_tags_for(path)
      counts = count_tags(tags)

      pretty_counts =
        counts.sort_by { |tag, count| count }.reverse.map do |tag, count|
          "#{tag}(#{count})"
        end

      puts pretty_counts
    end

    def filename_with_tags(file, tags)
      dirname = File.dirname(file)
      ext = File.extname(file)
      basename = File.basename(file, '.*')
      tag_part = basename.match(/--\[(.*)\]/)&.to_a&.at(0)
      basename = basename.gsub(tag_part, '') if tag_part
      File.join(dirname, "#{basename}--[#{tags.join(',')}]#{ext}")
    end

    def add_tags_to_file(new_tags, file)
      unless file
        (
          puts 'Needs a FILE input; i.e. `-a tag filename`'
          exit
        )
      end

      tags = find_tags_for(file)
      tags <<
        new_tags.split(',')&.map(&:strip)&.map(&:downcase)&.map do |t|
          # Replace spaces in tags with underscores, because spaces in
          # filenames can cause all kinds of issues depending on what
          # tools are used on the filenames. The less requirements for
          # escaping filenames, the better.
          t.gsub(' ', '_')
        end

      tags = tags.flatten.uniq.sort

      new_filename = filename_with_tags(file, tags)
      FileUtils.mv(file, new_filename) if file != new_filename

      new_filename
    end

    def read_and_add_tags_for(file, tags_path = '**/*')
      unless File.exist?(file)
        (
          puts "File '#{file}' does not exist."
          exit 1
        )
      end

      tags = find_tags_for(tags_path)
      Readline.completion_proc =
        proc { |input| tags.select { |tag| tag.start_with?(input) } }

      puts 'Add new tags:'
      new_tags = Readline.readline('> ', false)
      new_filename = add_tags_to_file(new_tags, file)
      [new_tags, new_filename]
    end

    def delete_tag_from_file(tag, file)
      unless file
        (
          puts 'Needs a FILE input; i.e. `-d tag1 filename`'
          exit
        )
      end

      tags = find_tags_for(file)
      tags = tags.reject { |t| t == tag }

      new_filename = filename_with_tags(file, tags)
      FileUtils.mv(file, new_filename) if file != new_filename

      new_filename
    end

    def rename_tag(path, old_tag, new_tag)
      unless new_tag
        (
          puts 'Needs a NEW_TAG input; i.e. `-r old_tag new_tag`'
          exit
        )
      end

      Dir.glob("#{path}/**/*--\\[*#{old_tag}*\\]*").each do |file|
        file = add_tags_to_file(new_tag, file)
        delete_tag_from_file(old_tag, file)
      end
    end

    def main
      OptionParser.new do |opts|
        opts.banner = 'Usage: oktags [options]'
        opts.on(
          '-l',
          '--list [PATH]',
          'List file tags (optionally for PATH)'
        ) do |path|
          path ? list_pretty_tags(path) : list_pretty_tags
          exit
        end
        opts.on(
          '-a',
          '--add-tags TAGS FILE',
          'Add comma-separated TAGS to FILE'
        ) do |tags|
          add_tags_to_file(tags, ARGV[0])
          exit
        end
        opts.on(
          '-i',
          '--add-tags-interactively FILE',
          'Auto-complete tags and add them to FILE'
        ) do |file|
          read_and_add_tags_for(file)
          exit
        end
        opts.on(
          '-r',
          '--rename-tag OLD_TAG NEW_TAG',
          'Rename OLD_TAG to NEW_TAG(S) recursively for all files'
        ) do |old_tag|
          rename_tag('.', old_tag, ARGV[0])
          exit
        end
        opts.on(
          '-d',
          '--delete-tag-from-file TAG FILE',
          'Delete TAG from FILE'
        ) do |tag|
          delete_tag_from_file(tag, ARGV[0])
          exit
        end
      end.parse!
    end
  end
end
