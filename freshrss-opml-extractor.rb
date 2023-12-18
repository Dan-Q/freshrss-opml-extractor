#!/bin/env ruby
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'mysql2'
  gem 'dotenv'
  gem 'nokogiri'
end
require 'dotenv/load'

# Connect to FreshRSS DB
puts "Connecting to FreshRSS..."
Dotenv.require_keys('FRESHRSS_HOST', 'FRESHRSS_DB', 'FRESHRSS_USER', 'FRESHRSS_PASSWORD', 'DANQ_SSH_PORT', 'DANQ_HOST', 'DANQ_PATH')
db = Mysql2::Client.new({host: ENV['FRESHRSS_HOST'], username: ENV['FRESHRSS_USER'], password: ENV['FRESHRSS_PASSWORD'], database: ENV['FRESHRSS_DB']})

# Get all feeds
puts "Getting feeds..."
feeds = db.query("
  SELECT
    danq_category_export_mappings.out `cat_name`,
    danq_category_export_mappings.description `cat_desc`,
    feed.name `name`,
    feed.website url,
    IF(
      (
        (feed.attributes LIKE '%\"xpath\"%') OR
        (feed.url LIKE '%danq-lj-proxy%' OR feed.url LIKE '%danq-dw-proxy%') OR
        (feed.url LIKE '%wltoken=%')
      ), NULL, feed.url) feed_url

  FROM freshrss_admin_feed feed
  LEFT JOIN freshrss_admin_category ON feed.category=freshrss_admin_category.id
  INNER JOIN danq_category_export_mappings ON freshrss_admin_category.name=danq_category_export_mappings.in

  AND feed.id IN (
    SELECT DISTINCT id_feed FROM freshrss_admin_entry
    WHERE `date` > UNIX_TIMESTAMP(SUBDATE(NOW(), INTERVAL 1 YEAR))
    AND ttl >= 0
  )

  ORDER BY
    IF(danq_category_export_mappings.order IS NULL, 1, 0),
    danq_category_export_mappings.order,
    danq_category_export_mappings.out,
    feed.name
").to_a
categories = feeds.map{|feed|feed.filter{|feed|%w{cat_name cat_desc}.include?(feed)}}.uniq

puts "Generating OPML/HTML..."
# Write OPML & HTML
opml = Nokogiri::XML <<~XML
  <opml version="1.0">
    <head>
      <title>Dan Q's Blogroll</title>
      <ownerName>Dan Q</ownerName>
      <ownerEmail>blogroll@danq.me</ownerEmail>
      <ownerId>https://danq.me/</ownerId>
      <docs>https://danq.me/blogroll</docs>
      <dateModified>#{DateTime.now.rfc822}</dateModified>
    </head>
    <body />
  </opml>
XML
html = Nokogiri::HTML.fragment("<p>Last updated: #{Time.now.strftime('%e %B %Y')}</p>")
opml_body = opml.at_css('body')
categories.each do |category|
  category_outline = Nokogiri::XML::Node.new('outline', opml)
  category_outline['text'] = category['cat_name']
  html_section = Nokogiri::XML::Node.new('section', html)
  html_section['class'] = "blogroll blogroll-#{category['cat_name'].downcase.gsub(/[^a-z0-9]/, '')}"
  html_section.add_child "<h2>#{category['cat_name']}</h2>"
  html_section.add_child("<p>#{category['cat_desc']}</p>") if category['cat_desc']
  html_section.add_child '<ul />'
  html_section_list = html_section.at_css('ul')
  feeds.select{|feed|feed['cat_name'] == category['cat_name']}.each do |feed|
    feed_outline = Nokogiri::XML::Node.new('outline', opml)
    feed_outline['text'] = feed_outline['title'] = feed['name']
    feed_outline['type'] = 'rss'
    (feed_outline['xmlUrl'] = feed['feed_url']) if feed['feed_url']
    feed_outline['htmlUrl'] = feed['url']
    category_outline.add_child(feed_outline)
    feed_li = Nokogiri::XML::Node.new('li', html)
    feed_a = Nokogiri::XML::Node.new('a', html)
    feed_a['href'] = feed['url']
    feed_a.content = feed['name']
    feed_li.add_child feed_a
    if feed['feed_url']
      feed_a2 = Nokogiri::XML::Node.new('a', html)
      feed_a2['href'] = feed['feed_url']
      feed_a2.content = 'XML'
      feed_li.add_child ' ['
      feed_li.add_child feed_a2
      feed_li.add_child ']'
    end
    html_section_list.add_child feed_li
  end
  opml_body.add_child(category_outline)
  html.add_child(html_section)
end

# Write output
puts "Writing OPML/HTML temporary files..."
FileUtils.mkdir_p('out')
File.open('out/blogroll.xml', 'w'){|f|f.puts opml.to_xml}
File.open('out/blogroll.htmlfragment', 'w'){|f|f.puts html.to_xhtml}

# Upload to DanQ.me
puts "Uploading to DanQ.me..."
`scp -P #{ENV['DANQ_SSH_PORT']} out/blogroll.xml #{ENV['DANQ_HOST']}:#{ENV['DANQ_PATH']}`
`scp -P #{ENV['DANQ_SSH_PORT']} out/blogroll.htmlfragment #{ENV['DANQ_HOST']}:#{ENV['DANQ_PATH']}`
