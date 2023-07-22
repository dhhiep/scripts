#!/usr/bin/env ruby

# frozen_string_literal: true

require 'builder'

EXT_LIST = %w[mp4 mkv avi flv mov wmv vob mpg 3gp m4v].freeze
ROOT_PATH = ARGV[0]

def scan_files # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  index = 0
  directories = Dir["#{Regexp.escape(ROOT_PATH)}/*"].select { |path| File.directory?(path) }
  directories.sort.each_with_object({}) do |sub_directory, accumulator|
    sub_directory_key = sub_directory.split('/').last
    next accumulator unless sub_directory_key

    accumulator[sub_directory_key] ||= []
    files = Dir["#{Regexp.escape(sub_directory)}/*.{#{EXT_LIST.join(',')}}"]
    files.sort.each do |file|
      index += 1
      accumulator[sub_directory_key] << {
        id: index,
        title: File.basename(file, '.*'),
        location: file.gsub(ROOT_PATH, '.')
      }
    end

    accumulator
  end
end

def build_track_list(xml, data) # rubocop:disable Metrics/MethodLength
  xml.trackList do |track_list|
    data.each do |_playlist_title, playlist_items|
      playlist_items.each do |playlist_item|
        track_list.track do |track|
          track.title playlist_item[:title]
          track.location playlist_item[:location]
          track.extension(application: 'http://www.videolan.org/vlc/playlist/0') do |extension|
            extension.vlc___id playlist_item[:id]
          end
        end
      end
    end
  end
end

def build_extension(xml, data)
  xml.extension(application: 'http://www.videolan.org/vlc/playlist/0') do |extension|
    data.each do |playlist_title, playlist_items|
      extension.vlc___node(title: playlist_title) do |vlc_node|
        playlist_items.each do |playlist_item|
          vlc_node.vlc___item(tid: playlist_item[:id])
        end
      end
    end
  end
end

def build_xml(data) # rubocop:disable Metrics/MethodLength
  xml = Builder::XmlMarkup.new(indent: 2)
  xml.instruct! :xml, encoding: 'UTF-8'
  xml.playlist(
    version: '1',
    xmlns: 'http://xspf.org/ns/0/',
    'xmlns:vlc' => 'http://www.videolan.org/vlc/playlist/ns/0/'
  ) do |playlist|
    playlist.title ROOT_PATH.split('/').last
    build_track_list(xml, data)
    build_extension(xml, data)
  end
end

File.open("#{ROOT_PATH}/playlist.xspf", 'w') do |file|
  xml = build_xml(scan_files)
  xml.gsub!('___', ':')
  file.write(xml)
end

system("cd #{Regexp.escape(ROOT_PATH)} && cat playlist.xspf")
