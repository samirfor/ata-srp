#!/usr/bin/env ruby
# frozen_string_literal: true

require 'httparty'
require 'nokogiri'
require 'csv'
require 'optparse'

Options = Struct.new(:compra, :ano, :uasg, :debug)

class Parser
  def self.parse(options)
    args = Options.new

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: ruby #{opts.program_name}.rb [options]"

      opts.on('-c COMPRA', '--compra=COMPRA', Integer, 'Número da COMPRA') do |u|
        args.compra = u
      end

      opts.on('-a ANO', '--ano=ANO', Integer, 'ANO do pregão') do |u|
        args.ano = u
      end

      opts.on('-u UASG', '--uasg=UASG', Integer, 'Número da UASG gerenciadora do pregão') do |u|
        args.uasg = u
      end

      opts.on('-d', '--debug', 'Mostra mais mensagens') do |u|
        args.debug = u
      end

      opts.on('-h', '--help', 'Mostra esta mensagem de ajuda') do
        puts opts
        exit
      end
    end

    opt_parser.parse!(options)

    args.each_pair do |name, value|
      if name != :debug && value.nil?
        puts opt_parser
        exit
      end
    end

    args
  end
end
options = Parser.parse(ARGV)

$debug = options[:debug] # verbosity
$modalidade_compra = 5 # 5=pregao
$numero_compra = options[:compra]
$ano_compra = options[:ano]
$uasg = options[:uasg]
HTTParty::Basement.default_options.update(verify: false)
$stdout.sync = true

def paginated?(parse_page)
  breturn=true
  begin
    get_actual_page(parse_page)
  rescue => exception
    if $debug
      puts
      puts 'Apenas uma página de itens ou erro de licitação inexistente.' 
    end
    breturn=false
  end
  breturn
end

def get_actual_page(parse_page)
  Integer(parse_page.xpath('//*[@id="corpo"]/form/div/span[2]/strong').text.strip)
end

def get_last_page(parse_page)
  Integer(parse_page.xpath('//*[@id="corpo"]/form/div/span[2]/a[last()]/@href').text.split('numeroPagina=')[1].split('&')[0])
end

def last_page?(parse_page)
  return true if not paginated?(parse_page)

  actual_page = get_actual_page(parse_page)
  last_page = get_last_page(parse_page)
  if $debug
    puts
    puts "pagina atual: #{actual_page}"
    puts "prox pagina : #{Integer(actual_page) + 1}"
    puts "last page   : #{last_page}"
  end
  return true if actual_page >= last_page

  false
end

def details_item_extract(codigo_item_ata_srp)
  page = HTTParty.get('https://www2.comprasnet.gov.br/siasgnet-atasrp/public/visualizarItemSRP.do?method=iniciar' \
    '&itemAtaSRP.codigoItemAtaSRP=' + codigo_item_ata_srp)
  parse_page = Nokogiri::HTML(page)

  details = {
    'qtd_homologada' => Integer(parse_page.xpath('//*[@id="uasgItemSRP"]/tbody/tr[1]/td[4]').text.strip.to_i),
    'qtd_empenhada' => Integer(parse_page.xpath('//*[@id="uasgItemSRP"]/tbody/tr[1]/td[4]').text.strip.to_i),
    'saldo_para_empenho' => parse_page.xpath('//*[@name="itemAtaSRP.informacoesSIASG.quantidadeSaldoDisponivelEmpenhoParticipantes"]/@value').text.strip.to_i,
    'saldo_para_adesao' => parse_page.xpath('//*[@name="itemAtaSRP.saldoDisponivelAdesao"]/@value').text.strip.to_i,
    'fim_vigencia' => parse_page.xpath('//*[@name="itemAtaSRP.resultado.dataFimVigenciaAta"]/@value').text.strip
  }
  details
end

def items_extract(parse_page)
  items = []
  table = parse_page.xpath('//*[@id="item"]/tbody/tr')

  table.each do |row|
    item_num = row.at_xpath('td[1]').text.strip
    material_type = row.at_xpath('td[2]').text.strip
    description = row.at_xpath('td[3]').text.strip
    supply_unit = row.at_xpath('td[5]').text.strip
    item_id = row.at_xpath('td[6]/a').attributes['href'].value.split('(')[1].split(')')[0]

    details = details_item_extract(item_id)
    print '.'
    print item_num + '.' + details.to_s if $debug
    puts if $debug

    items << {
      'pregao' => "#{$numero_compra}/#{$ano_compra}",
      'uasg gerenciadora' => $uasg,
      'item' => item_num,
      'tipo material' => material_type,
      'descricao' => description,
      'unidade fornecimento' => supply_unit,
      'codigoItemAtaSRP' => item_id
    }.merge!(details)
  end
  items
end

def url_items(pagenumber)
  "https://www2.comprasnet.gov.br/siasgnet-atasrp/public/pesquisarItemSRP.do?method=consultarPorFiltro&parametro.identificacaoCompra.numeroUasg=#{$uasg}&parametro.identificacaoCompra.modalidadeCompra=#{$modalidade_compra}&parametro.identificacaoCompra.numeroCompra=#{$numero_compra}&parametro.identificacaoCompra.anoCompra=#{$ano_compra}&numeroPagina=#{pagenumber}"
end

items = []
pagenumber = 1
puts
puts 'extraindo itens: '
puts
loop do
  puts url_items(pagenumber) if $debug
  page = HTTParty.get(url_items(pagenumber))
  parse_page = Nokogiri::HTML(page)
  items += items_extract(parse_page)
  pagenumber += 1
  print '.'
  break if last_page?(parse_page) # or pagenumber > 1
end

# p items if $debug

puts
puts 'gerando planilha...'

CSV.open(
  "PE#{$numero_compra}#{$ano_compra}.UASG.#{$uasg}.csv", 'wb',
  **{
    :col_sep => ',',
    :force_quotes => true,
    :strip => true
  }
) do |csv|
  csv << items[0].keys # csv header

  items.each do |item|
    csv << item.values
  end
end

puts
puts 'concluído!'
