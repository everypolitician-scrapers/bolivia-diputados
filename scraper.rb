#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'set'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)
  deps = noko.css('.box-dip').map do |box|
    name = box.css('p#nombre').text
    data = { 
      name: name,
      image: box.css('img/@src').text,
      party: box.xpath('.//p[contains(.,"Bancada:")]').text.to_s.sub('Bancada: ',''),
      area: box.xpath('.//p[contains(.,"nominal")]').text.to_s.sub('Dip. ','').sub('Uninominal ',''),
      type: box.xpath('.//p//strong').text.to_s,
    }.reject { |_, v| v.nil? || v.to_s.empty? }
    data[:image] = URI.join(url, URI.encode(data[:image])).to_s unless data[:image].to_s.empty?
    data[:id] = File.basename(data[:image], '.*')
    data
  end

  deps.group_by { |d| d[:id] }.each do |d, ds| 
    data = ds.reduce(&:merge).merge({ term: 2015, source: url })
    ScraperWiki.save_sqlite([:id, :term], data)
  end
 
end

scrape_list('http://www.diputados.bo/script/dip-index.php')
