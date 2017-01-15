#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'digest/md5'
require 'time'
require 'date'
require 'yaml'
require 'fileutils'
require 'uri'

config = YAML.load_file("_data/crawler.yml")

def make_absolute( href, root )
  URI.parse(root).merge(URI.parse(href)).to_s
end

config.shuffle.each do |site|
  site_name = site['name']
  puts "===== #{site_name}"

  base_url = site['base_url']
  list_url = site['list_url']

  data_dir = site['data_dir']
  FileUtils.mkdir_p(data_dir) unless File.exists?(data_dir)
  meta_dir = site['meta_dir']
  FileUtils.mkdir_p(meta_dir) unless File.exists?(meta_dir)

  FileUtils.mkdir_p("./images/#{site_name}/") unless File.exists?("./images/#{site_name}/")

  begin
    page = Nokogiri::HTML(open(list_url, :open_timeout => 15, :read_timeout => 60))
  rescue Errno::ETIMEDOUT => e
    p e
    next
  rescue OpenURI::HTTPError => e
    p e
    next
  end
  rows = page.css(site['list_rows_sel'])

  hrefs = rows[0..25].map { |a|
    a['href'] if a['href'] =~ /^\// or a['href'].start_with?(base_url)
  }.compact.uniq

  hrefs.each do |href|
    remote_url = href.start_with?(base_url) ? href : base_url + href
    puts remote_url
    local_fname = "#{data_dir}/#{File.basename(href).gsub('?', '__')}-#{Digest::MD5.hexdigest(href)[0..8]}.html"

    unless File.exists?(local_fname)
      puts "Fetching #{remote_url}..."
      begin
        page_content = open(remote_url, {:open_timeout => 15, :read_timeout => 60}.merge(site['headers_hash'])).read
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
        post_images = {}
        post_content.css('img').each do |img|
          src = img['src']
          next if src =~ /^data:/
          src_digest = Digest::MD5.hexdigest(src)
          post_images[src_digest] = src
          img['src'] = "/images/#{site_name}/#{src_digest}.jpg"
          uri = make_absolute(src, remote_url)
          p uri
          begin
            File.open("./images/#{site_name}/#{src_digest}.jpg", 'wb') { |f| f.write(open(URI.encode(uri), :open_timeout => 15, :read_timeout => 60).read) }
          rescue => e
            puts "#  ---   ./images/#{site_name}/#{src_digest}.jpg"
            p e
          end
        end
	post_content.css('object').each do |object|
          data = object['data']
          next if data =~ /^data:/
          data_digest = Digest::MD5.hexdigest(data)
          ext = data.split('.')[-1]
          post_images[data_digest] = data
          object['data'] = "/images/#{site_name}/#{data_digest}.#{ext}"
          uri = make_absolute(data, remote_url)
          p uri
          begin
            File.open("./images/#{site_name}/#{data_digest}.#{ext}", 'wb') { |f| f.write(open(uri, :open_timeout => 15, :read_timeout => 60).read) }
          rescue => e
            puts "#  ---   ./images/#{site_name}/#{data_digest}.#{ext}"
            p e
          end
        end

        puts post_href
        puts post_title.text
        puts post_time.text
        p post_images

        if site['post_time_p']
          puts post_time.text.strip
          post_time = Date.strptime(post_time.text.strip.gsub(/st|nd|rd|th/, ''), site['post_time_p'])
        else
          post_time = Time.parse(post_time.text)
        end
        meta_fname = "#{meta_dir}/#{post_time.strftime('%F')}-#{File.basename(href).gsub('?', '-')}-#{Digest::MD5.hexdigest(href)[0..8]}.html"
        puts "\t...Success, saved to #{meta_fname}"
        File.open(meta_fname, 'w') {|file|
          file.puts("---")
          file.puts("layout: post")
          file.puts("title: '#{post_title.text.strip}'")
          file.puts("time: #{post_time}")
          file.puts("site_name: #{site_name}")
          file.puts("source_url: #{post_href}")
          if post_images.size > 0
            file.puts("images:")
            post_images.each do |k, v|
              file.puts("  #{k}: #{v}")
            end
          end
          file.puts("---")
          file.puts("{% raw %}")
          file.puts(post_content.inner_html)
          file.puts("{% endraw %}")
        }
      ensure
        sleep 1.0 + rand
      end  # done: begin/rescue
    end # done: unless File.exists?
  end
end
