require 'open-uri'

class HomeController < ApplicationController
  def index
    @bolha = bolha
    @nepremicnine = nepremicnine
    @salomon = salomon
  end

  private

  def bolha
    url = 'http://www.bolha.com/nepremicnine/stanovanja?adTypeH=02_Oddam/&location=Osrednjeslovenska/Ljubljana/&hasImages=Oglasi%20s%20fotografijami&viewType=30&priceSortField=400%7C700&renovatedYear=2012%20in%20ve%C4%8D%7C%7C2010%20do%202011'
    html = Nokogiri::HTML(open(url))
    html.css('#list .adGridContent').map{ |estate|
      estate_url = "http://www.bolha.com#{estate.at_css('a')['href']}"
      md5 = Digest::MD5.hexdigest(estate_url)
      Rails.cache.fetch md5 do
        estate_html = Nokogiri::HTML(open(estate_url))
        {
          basic: estate_html.at_css('.oglas-podatki').to_s,
          extra: estate_html.at_css('.oglas-podatki-ostalo').to_s,
          price: estate.at_css('.price').text,
          all_images: estate_html.css('a.gal').map{ |img| img['href'] },
          size: get_bolha_size(estate_html),
          date: get_bolha_date(estate_html),
          url: estate_url,
          md5: md5
        }
      end
    }.sort_by{ |e| e[:date] }.reverse
  end

  def nepremicnine
    url = 'http://www.nepremicnine.net/nepremicnine.html?n=1&d=197&p=3&r=14&c1=400&c2=700&s=16'
    html = Nokogiri::HTML(open(url))
    html.css('.oglas_container').map{ |estate|
      estate_url = "http://www.nepremicnine.net#{estate.at_css('a')['href']}"
      md5 = Digest::MD5.hexdigest(estate_url)
      next if estate.at_css('img')['src'] == '/images/n-1.jpg'
      Rails.cache.fetch md5 do
        estate_html = Nokogiri::HTML(open(estate_url))
        {
          basic: estate_html.at_css('.main-data table').to_s,
          extra: estate_html.at_css('.opis').to_s,
          price: estate.at_css('.cena').text,
          all_images: estate_html.css('a.rsImg').map{ |a| a.attr('data-rsbigimg') },
          size: estate.at_css('.velikost').text.gsub(',', '.').to_f,
          url: estate_url,
          md5: md5
        }
      end
    }.compact
  end

  def salomon
    url = 'http://www.salomon.si/oglasi/nepremicnine/stanovanje?q=&mmType=1&filters=1471s-83851x1472s-90256x447m-27555&onPage=100&priceFrom=400&priceTo=700'
    html = Nokogiri::HTML(open(url))
    html.css('#advertList article:not(.banner20)').map{ |estate|
      estate_url = "http://www.salomon.si#{estate.at_css('a')['href']}"
      md5 = Digest::MD5.hexdigest(estate_url)
      Rails.cache.fetch md5 do
        estate_html = Nokogiri::HTML(open(estate_url))
        {
          basic: estate_html.at_css('#advAttr table').to_s,
          extra: estate_html.at_css('#moreAttr article').to_s,
          price: estate.at_css('.price').text,
          all_images: estate_html.css('.thumbsList a').map{ |a| a['href'] },
          size: get_salomon_size(estate_html),
          url: estate_url,
          md5: md5
        }
      end
    }
  end

  def get_bolha_date html
    html.css('.adInfo p').each do |row|
      if row.text =~ /Vpisano/
        return Time.parse(row.children.last)
      end
    end
  end

  def get_bolha_size html
    html.css('.oglas-podatki tr').each do |row|
      if row.text =~ /Velikost/
        return row.at_css('b').text.gsub(',', '.').to_f
      end
    end
  end

  def get_salomon_size html
    rows = html.css('#advAttr tr')
    rows.each_with_index do |row, i|
      if row.text =~ /Površina/
        return rows[i+1].children.last.text.gsub(',', '.').to_f
      end
    end
  end
end
