require 'open-uri'

class HomeController < ApplicationController
  BOLHA_URL = 'http://www.bolha.com/nepremicnine/stanovanja?adTypeH=02_Oddam/&location=Osrednjeslovenska/Ljubljana/&viewType=30&priceSortField=399%7C700&hasImages=Oglasi%20s%20fotografijami'
  NEPREMICNINE_URL = 'http://www.nepremicnine.net/nepremicnine.html?n=1&d=197&p=3&r=14&c1=399&c2=700&s=16'
  SALOMON_URL ='http://www.salomon.si/oglasi/nepremicnine/stanovanje?q=&mmType=1&filters=1471s-83851x1472s-90256x447m-27555&onPage=100&priceFrom=399&priceTo=700'

  def index
    @bolha = bolha
    @nepremicnine = nepremicnine
    @salomon = salomon
  end

  private

  def bolha
    nokogirify(BOLHA_URL).css('#list .adGridContent').map{ |estate|
      estate_url = "http://www.bolha.com#{estate.at_css('a')['href']}"
      Rails.cache.fetch estate_url, expires_in: 1.hour, compress: true do
        estate_html = Nokogiri::HTML(open(estate_url))
        {
          basic: estate_html.at_css('.oglas-podatki').to_s,
          extra: estate_html.at_css('.oglas-podatki-ostalo').to_s,
          price: estate.at_css('.price').text,
          all_images: estate_html.css('a.gal').map{ |img| img['href'] },
          size: get_bolha_size(estate_html),
          url: estate_url,
          md5: Digest::MD5.hexdigest(estate_url)
        }
      end
    }
  end

  def nepremicnine
    nokogirify(NEPREMICNINE_URL).css('.oglas_container').map{ |estate|
      estate_url = "http://www.nepremicnine.net#{estate.at_css('a')['href']}"
      next if estate.at_css('img')['src'] == '/images/n-1.jpg'
      Rails.cache.fetch estate_url, expires_in: 1.hour, compress: true do
        estate_html = Nokogiri::HTML(open(estate_url))
        {
          basic: estate_html.at_css('.main-data table').to_s,
          extra: estate_html.at_css('.web-opis').to_s,
          price: estate.at_css('.cena').text,
          all_images: estate_html.css('a.rsImg').map{ |a| a.attr('data-rsbigimg') },
          size: estate.at_css('.velikost').text.gsub(',', '.').to_f,
          url: estate_url,
          md5: Digest::MD5.hexdigest(estate_url)
        }
      end
    }.compact
  end

  def salomon
    nokogirify(SALOMON_URL).css('#advertList article:not(.banner20)').map{ |estate|
      estate_url = "http://www.salomon.si#{estate.at_css('a')['href']}"
      Rails.cache.fetch estate_url, expires_in: 1.hour, compress: true do
        estate_html = Nokogiri::HTML(open(estate_url))
        {
          basic: estate_html.at_css('#advAttr table').to_s,
          extra: estate_html.css('#moreAttr article').to_s,
          price: estate.at_css('.price').text,
          all_images: estate_html.css('.thumbsList a').map{ |a| a['href'] },
          size: get_salomon_size(estate_html),
          url: estate_url,
          md5: Digest::MD5.hexdigest(estate_url)
        }
      end
    }
  end

  def nokogirify url
    html = Rails.cache.fetch url, expires_in: 1.hour, compress: true do
      open(url).read
    end
    Nokogiri::HTML(html)
  end

  def get_bolha_size html
    html.css('.oglas-podatki tr').each do |row|
      if row.text =~ /Velikost/
        return row.at_css('b').text.gsub(',', '.').to_f
      end
    end
    0
  end

  def get_salomon_size html
    rows = html.css('#advAttr tr')
    rows.each_with_index do |row, i|
      if row.text =~ /Površina/
        index = row.css('th').map(&:text).index('Površina')
        return rows[i+1].children[index].text.gsub(',', '.').to_f
      end
    end
    0
  end
end
