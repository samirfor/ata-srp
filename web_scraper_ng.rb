require 'httparty'
require 'nokogiri'
require 'json'
require 'pry'
require 'csv'
require 'pp'

$debug=1 # verbosity
$modalidade_compra=5 # 5=pregao
$numero_compra=3
$ano_compra=2020
$uasg=154618
$pag=1
url_itens_list_screen="https://www2.comprasnet.gov.br/siasgnet-atasrp/public/pesquisarItemSRP.do?method=iniciar&parametro.identificacaoCompra.numeroUasg=#{$uasg}&parametro.identificacaoCompra.modalidadeCompra=#{$modalidade_compra}&parametro.identificacaoCompra.numeroCompra=#{$numero_compra}&parametro.identificacaoCompra.anoCompra=#{$ano_compra}&numeroPagina=#{$pag}&"


def get_actual_page parse_page
  Integer(parse_page.xpath('//*[@id="corpo"]/form/div/span[2]/strong').text.strip)
end

def get_last_page parse_page
  Integer(parse_page.xpath('//*[@id="corpo"]/form/div/span[2]/a[last()]/@href').text.split('numeroPagina=')[1].split('&')[0])
end

def is_last_page parse_page
  actual_page = get_actual_page(parse_page)
  last_page = get_last_page(parse_page)
  if $debug then
    puts "pagina atual: #{actual_page}"
    puts "prox pagina: #{Integer(actual_page)+1}"
    puts "last page #{last_page}"
  end
  return true if actual_page == last_page
  return false
end

def items_extract parse_page
  table = parse_page.xpath('//*[@id="item"]/tbody/tr')

  table.each do |row|
    item_num = row.at_xpath('td[1]').text.strip
    material_type = row.at_xpath('td[2]').text.strip
    description = row.at_xpath('td[3]').text.strip
    supply_unit = row.at_xpath('td[5]').text.strip
    item_id = row.at_xpath('td[6]/a').attributes["href"].value.split('(')[1].split(')')[0]

    $items << [item_num, material_type, description, supply_unit, item_id]
  end
  print "."
  items
end

def details_item_extract codigoItemAtaSRP
  page = HTTParty.get("https://www2.comprasnet.gov.br/siasgnet-atasrp/public/visualizarItemSRP.do?method=iniciar&itemAtaSRP.codigoItemAtaSRP=#{codigoItemAtaSRP}")
  parse_page = Nokogiri::HTML(page)

  qtd_emp = parse_page.xpath('//*[@id="uasgItemSRP"]/tbody/tr[1]/td[4]').text.strip
  vigencia_fim = parse_page.xpath('').text.strip # TODO
  {
    "qtd_emp" => qtd_emp,
    "vigencia_fim" => vigencia_fim
  }
end

HTTParty::Basement.default_options.update(verify: false)
items = []
page = HTTParty.get(url_itens_list_screen) # pag 1
parse_page = Nokogiri::HTML(page)
puts url_itens_list_screen

puts
puts "extraindo items: "

unless not is_last_page(parse_page) do
  items_extract(parse_page)
end


puts
puts "extraindo quantidades empenhadas: "

items.each do |item|
  page = HTTParty.get("https://www2.comprasnet.gov.br/siasgnet-atasrp/public/visualizarItemSRP.do?method=iniciar&itemAtaSRP.codigoItemAtaSRP=#{item.last}")
  parse_page = Nokogiri::HTML(page)

  qtd_emp = parse_page.xpath('//*[@id="uasgItemSRP"]/tbody/tr[1]/td[4]').text.strip

  item << qtd_emp
  print "."
end

# pp item

puts
puts "gerando planilha..."

CSV.open("planilha.csv", "w") do |csv|
  csv << ["item", "tipo do material", "descrição", "unidade de fornecimento", "id", "quantidade empenhada"]
  items.each do |item|
    csv << item
  end
end

puts "concluído!"
