#!/bin/env ruby
# encoding: utf-8

require 'nokogiri'
require 'pry'
require 'scraperwiki'

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
      dpto:  box.xpath('.//p[contains(.,"Dpto:")]').text.to_s.sub('Dpto: ',''),
      dip:   box.xpath('.//p[contains(.,"Dip. ")]').text.to_s.sub('Dip. ',''),
      party: box.xpath('.//p[contains(.,"Bancada:")]').text.to_s.sub('Bancada: ',''),
      type:  box.xpath('.//p//strong').text.to_s,
    }.reject { |_, v| v.nil? || v.to_s.empty? }
    data[:image] = URI.join(url, URI.encode(data[:image])).to_s unless data[:image].to_s.empty?
    data[:id] = File.basename(data[:image], '.*')
    data
  end

  deps.group_by { |d| d[:id] }.each do |d, ds| 
    data = ds.reduce(&:merge).merge({ term: 2015, source: url })
    if data[:dip].include? ('Uninominal')
      data[:area_id] = data[:dip].sub('Uninominal ','')
      data[:area] = data[:dpto]
    elsif %w(Plurinominal Especial).include? data[:dip] 
      data[:area] = data[:dpto]
    else
      raise "Unknown area"
    end
    ScraperWiki.save_sqlite([:id, :term], data)
  end
 
end

scrape_list('http://www.diputados.bo/script/dip-index.php')
