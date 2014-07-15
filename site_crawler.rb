#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'digest/md5'
require 'time'
require 'yaml'
require 'fileutils'

config = YAML.load_file("_data/crawler.yml")

config.each do |site|
  site_name = site['name']
  puts "===== #{site_name}"

  base_url = site['base_url']
  list_url = site['list_url']

  data_dir = site['data_dir']
  FileUtils.mkdir_p(data_dir) unless File.exists?(data_dir)
  meta_dir = site['meta_dir']
  FileUtils.mkdir_p(meta_dir) unless File.exists?(meta_dir)

  page = Nokogiri::HTML(open(list_url))
  rows = page.css(site['list_rows_sel'])

  rows[1..-2].each do |row|
    hrefs = row.css("a").map{ |a| 
      a['href'] if a['href'] =~ /^\// or a['href'].start_with?(base_url)
    }.compact.uniq

    hrefs.each do |href|
      remote_url = href.start_with?(base_url) ? href : base_url + href
      puts remote_url
      local_fname = "#{data_dir}/#{File.basename(href)}-#{Digest::MD5.hexdigest(href)[0..8]}.html"

      unless File.exists?(local_fname)
        puts "Fetching #{remote_url}..."
        begin
          page_content = open(remote_url, site['headers_hash']).read
        rescue Exception=>e
          puts "Error: #{e}"
          sleep 5
        else
          File.open(local_fname, 'w'){|file| file.write(page_content)}
          puts "\t...Success, saved to #{local_fname}"

          post = Nokogiri::HTML(page_content)
          post_href = remote_url
          post_title = post.css(site['post_title_sel']).first
          post_time = post.css(site['post_time_sel']).first
          post_content = post.css(site['post_content_sel']).first
          site['post_content_excludes'].each do |exclude_node|
            post_content.search(exclude_node).remove
          end

          puts post_href
          puts post_title.text
          puts post_time.text

          post_time = Time.parse(post_time.text)
          meta_fname = "#{meta_dir}/#{post_time.strftime('%F')}-#{File.basename(href)}-#{Digest::MD5.hexdigest(href)[0..8]}.html"
          File.open(meta_fname, 'w') {|file|
            file.puts("---")
            file.puts("layout: post")
            file.puts("title: #{post_title.text}")
            file.puts("time: #{post_time}")
            file.puts("site_name: #{site_name}")
            file.puts("source_url: #{post_href}")
            file.puts("---")
            file.puts(post_content.inner_html)
          }
        ensure
          sleep 1.0 + rand
        end  # done: begin/rescue
      end # done: unless File.exists?
    end
  end
end
