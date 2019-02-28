require 'httparty'
require 'nokogiri'
require 'json'
require 'pry'
require 'csv'
require 'pp'

urls = []

17.times do |i|
  urls << "https://www2.comprasnet.gov.br/siasgnet-atasrp/public/pesquisarItemSRP.do?funcaoRetorno=&parametro.identificacaoCompra.numeroUasg=158361&parametro.uasg.numeroUasg=158361&casoDeUsoOrigem=&parametro.identificacaoCompra.numeroCompra=00001&parametro.identificacaoCompra.anoCompra=2018&parametro.codigosModalidadeCompra=1&numeroPagina=#{i + 1}&parametro.uasg.nome=&parametro.identificacaoCompra.modalidadeCompra=5&method=consultarPorFiltro&parametro.anoLicitacao=2018&parametro.numeroLicitacao=00001"
end

HTTParty::Basement.default_options.update(verify: false)
items = []

puts "extraindo items:"

urls.each do |url|
  page = HTTParty.get(url)
  parse_page = Nokogiri::HTML(page)

  table = parse_page.xpath('//*[@id="item"]/tbody/tr')


  table.each do |row|
    item_num = row.at_xpath('td[1]').text.strip
    descripion = row.at_xpath('td[3]').text.strip
    item_id = row.at_xpath('td[6]/a').attributes["href"].value.split('(')[1].split(')')[0]

    items << [item_num, descripion, item_id]
  end
  print "."
end


# pp items
puts ""
puts "extraindo quantidades empenhadas:"

items.each do |item|
  page = HTTParty.get("https://www2.comprasnet.gov.br/siasgnet-atasrp/public/visualizarItemSRP.do?method=iniciar&itemAtaSRP.codigoItemAtaSRP=#{item.last}")
  parse_page = Nokogiri::HTML(page)

  qtd_emp = parse_page.xpath('//*[@id="uasgItemSRP"]/tbody/tr[1]/td[4]').text.strip

  item << qtd_emp
  print "."
end

# pp item

puts "gerando planilha..."

CSV.open("planilha.csv", "w") do |csv|
  csv << ["item", "descrição", "id", "quantidade empenhada"]
  items.each do |item|
    csv << item
  end
end

puts "concluído!"
