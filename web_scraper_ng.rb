#!/usr/bin/env ruby
# frozen_string_literal: true

require 'httparty'
require 'nokogiri'
require 'csv'
require 'optparse'
require 'wicked_pdf' # dep: wkhtmltopdf

Options = Struct.new(:compra, :ano, :uasg, :debug, :termo_homologacao, :anexos, :parallel)

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

      opts.on('-t', '--termohomologacao', 'Baixa o PDF do Termo de Homologacao do pregão') do |u|
        args.termo_homologacao = u
      end

      opts.on('-p', '--anexos', 'Baixa os anexos dos itens do pregão') do |u|
        args.anexos = u
      end

      opts.on('-x', '--parallel', 'Extração de itens em paralelo. Agiliza o processo.') do |u|
        args.parallel = u
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
      if name != :debug && \
          name != :termo_homologacao && \
          name != :anexos && \
          name != :parallel && \
          value.nil?
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
$anexos = options[:anexos]
$termo_homologacao = options[:termo_homologacao]
$parallel = options[:parallel]
$prgcod = nil
$numprp = "#{$numero_compra}#{$ano_compra}"
$basefilenameoutput = "PE#{$numero_compra}#{$ano_compra}.UASG.#{$uasg}"
HTTParty::Basement.default_options.update(verify: false)
$stdout.sync = true
MAX_ATTEMPTS = 20

def paginated?(parse_page)
  breturn=true
  begin
    get_actual_page(parse_page)
  rescue => exception
    if parse_page.xpath('//*[@id="mensagensSistema"]/div').text.include?('licitação informada não existe')
      puts
      puts "AVISO: Licitação #{$basefilenameoutput} inexistente."
      exit
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

def html_get(url)
  page = nil
  attempts = 0

  puts url if $debug

  begin
    page = HTTParty.get(url)
  rescue Exception => ex
    puts if $debug
    puts "Error: #{ex}" if $debug
    attempts = attempts + 1
    print 'F'
    sleep 5
    retry if(attempts < MAX_ATTEMPTS)
  end

  if(page.nil?)
    puts
    puts "Error: #{url} falhou #{MAX_ATTEMPTS} vezes. Parando #{$numero_compra}/#{$ano_compra} UASG #{$uasg}."
    exit
  end
  page
end

def details_item_extract(codigo_item_ata_srp)
  url = 'https://www2.comprasnet.gov.br/siasgnet-atasrp/public/visualizarItemSRP.do?method=iniciar' \
    '&itemAtaSRP.codigoItemAtaSRP=' + codigo_item_ata_srp

  page = html_get(url)
  parse_page = Nokogiri::HTML(page)

  details = {
    'qtd_homologada' => parse_page.xpath('//*[@name="itemAtaSRP.informacoesSIASG.quantidadeHomolgadaItem"]/@value').text.strip.to_i,
    'data_assinatura_ata' => parse_page.xpath('//*[@name="itemAtaSRP.resultado.dataAssinaturaAta"]/@value').text.strip,
    'fim_vigencia_ata' => parse_page.xpath('//*[@name="itemAtaSRP.resultado.dataFimVigenciaAta"]/@value').text.strip,

    'qtd_contratada_participantes' => parse_page.xpath('//*[@name="itemAtaSRP.informacoesSIASG.quantidadeContratadaItemParticipantes"]/@value').text.strip.to_i,
    'qtd_empenhada_participantes' => parse_page.xpath('//*[@name="itemAtaSRP.informacoesSIASG.quantidadeEmpenhaItemParticipantes"]/@value').text.strip.to_i,
    'saldo_contratacao_participantes' => parse_page.xpath('//*[@name="itemAtaSRP.informacoesSIASG.quantidadeSaldoDisponivelContratacaoParticipantes"]/@value').text.strip.to_i,
    'saldo_empenho_participantes' => parse_page.xpath('//*[@name="itemAtaSRP.informacoesSIASG.quantidadeSaldoDisponivelEmpenhoParticipantes"]/@value').text.strip.to_i,

    'qtd_maxima_adesoes' => parse_page.xpath('//*[@name="itemAtaSRP.quantidadeMaximaParaAdesoes"]/@value').text.strip.to_i,
    'qtd_aguardando_autorizacao_caronas' => parse_page.xpath('//*[@name="itemAtaSRP.quantitativoAdesao.quantidadeAguardandoAutorizacao"]/@value').text.strip.to_i,
    'qtd_autorizada_caronas' => parse_page.xpath('//*[@name="itemAtaSRP.quantitativoAdesao.quantidadeAutorizada"]/@value').text.strip.to_i,
    'qtd_contratada_caronas' => parse_page.xpath('//*[@name="itemAtaSRP.informacoesSIASG.quantidadeContratadaItemCaronas"]/@value').text.strip.to_i,
    'qtd_empenhada_caronas' => parse_page.xpath('//*[@name="itemAtaSRP.informacoesSIASG.quantidadeEmpenhadaItemCaronas"]/@value').text.strip.to_i,
    'saldo_para_adesao' => parse_page.xpath('//*[@name="itemAtaSRP.saldoDisponivelAdesao"]/@value').text.strip.to_i,

    'valor_unit_homologado' => parse_page.xpath('//*[@id="fornecedorSRP"]/tbody/tr[1]/td[6]').text.strip[/([0-9]{1,3}(\.[0-9]{3})*,[0-9]+)/],
    'valor_unit_negociado' => parse_page.xpath('//*[@id="fornecedorSRP"]/tbody/tr[1]/td[7]').text.strip[/([0-9]{1,3}(\.[0-9]{3})*,[0-9]+)/],
    'cnpj' => parse_page.xpath('//*[@id="fornecedorSRP"]/tbody/tr[1]/td[2]').text.strip[0..17], # regex \d{2}\.\d{3}\.\d{3}\/\d{4}\-\d{2}
    'fornecedor' => parse_page.xpath('//*[@id="fornecedorSRP"]/tbody/tr[1]/td[2]').text.strip[21..-1],
    'marca' => parse_page.xpath('//*[@id="fornecedorSRP"]/tbody/tr[1]/td[3]').text.strip,
    'descricao_detalhada' => parse_page.xpath('//*[@name="cabecalhoItemSRP.descricaoDetalhadaItem"]').text.strip.gsub("\n", ' ').gsub("\r", ' ').squeeze(' '),
  }
  details
end

def get_prgcod
  if $prgcod.nil?
    url = "http://comprasnet.gov.br/livre/pregao/ata2.asp?co_no_uasg=#{$uasg}&numprp=#{$numprp}"

    page = html_get(url)
    parse_page = Nokogiri::HTML(page)
  
    begin
      prgcod = parse_page.xpath('//*[@name="termodehomologacao"]/@onclick').text.strip.split(',')[0].split('(')[1]
    rescue => exception
      puts 'Error: ' + parse_page.xpath('//span[@class="mensagem"]').text.strip
      exit
    end
  else
    prgcod = $prgcod
  end
  prgcod
end

def items_extract(parse_page)
  items = []
  threads = []
  table = parse_page.xpath('//*[@id="item"]/tbody/tr')

  table.each do |row|
    item_num = row.at_xpath('td[1]').text.strip
    material_type = row.at_xpath('td[2]').text.strip
    description = row.at_xpath('td[3]').text.strip
    supply_unit = row.at_xpath('td[5]').text.strip
    item_id = row.at_xpath('td[6]/a').attributes['href'].value.split('(')[1].split(')')[0]
    if $parallel
      threads << Thread.new {
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
      }
    else
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
  end
  threads.each{|t| t.join} if $parallel
  items
end

def download_termo_homologacao
  pdf_file = "#{$basefilenameoutput}.Termo.Homologacao.pdf"
  pdf = WickedPdf.new.pdf_from_url("http://comprasnet.gov.br/livre/pregao/termohom.asp?prgcod=#{get_prgcod()}&tipo=t")
  File.open(pdf_file, 'wb') do |file|
    file << pdf
  end
  pdf_file
end

def get_items_attachments
  # pág. anexos dos itens
  url = "http://comprasnet.gov.br/livre/pregao/anexosDosItens.asp?uasg=#{$uasg}&numprp=#{$numprp}&prgcod=#{get_prgcod()}"

  page = html_get(url)
  parse_page = Nokogiri::HTML(page)
  
  tr = parse_page.xpath('//tr')
  items = []
  tr.each do |row|
    begin
      cnpj = row.at_xpath('./td[1]').text.strip
      razao_social = row.at_xpath('./td[2]').text.strip
      url = row.at_xpath('.//a/@href').value
      filename = row.at_xpath('.//a').text.strip
      ipa_cod = url.split('ipaCod=')[1].split('&')[0]
   
      items << {
        'cnpj': cnpj,
        'razao_social': razao_social,
        'url': url,
        'filename': filename,
        'tipo': row.at_xpath('./td[3]').text.strip,
        'enviado_em': row.at_xpath('./td[4]').text.strip,
        'ipa_cod': ipa_cod
      }
    rescue
      # ignore trash
    end
  end
  items
end

def get_items_proposals
  # pág. anexos de proposta/habilitação
  url = "http://comprasnet.gov.br/livre/pregao/anexosPropostaHabilitacao.asp?prgCod=#{get_prgcod()}"

  page = html_get(url)
  parse_page = Nokogiri::HTML(page)

  tr = parse_page.xpath('//tr')
  items = []
  tr.each do |row|
    begin
      fornecedor = row.at_xpath('./td[1]').text.strip
      cnpj = fornecedor.split(' - ')[0]
      razao_social = fornecedor.split(' - ')[1]
      url = row.at_xpath('.//a/@href').value
      filename = row.at_xpath('.//a').text.strip
      pa_cod = url.split('paCod=')[1].split('&')[0]
   
      items << {
        'cnpj': cnpj,
        'razao_social': razao_social,
        'url': url,
        'filename': filename,
        'tipo': row.at_xpath('./td[3]').text.strip,
        'enviado_em': row.at_xpath('./td[4]').text.strip,
        'pa_cod': pa_cod
      }
    rescue
      # ignore trash
    end
  end
  items
end

def download_file(url, filename)
  puts "Download #{filename} ..."
  puts "Download #{url} ..." if $debug
  File.open(filename, "wb") do |file|
    HTTParty.get(url, {stream_body: true, follow_redirects: true}) do |fragment|
      if [301, 302].include?(fragment.code)
        print "skip writing for redirect" if $debug
      elsif fragment.code == 200
        print "." if $debug
        file.write(fragment)
      else
        raise StandardError, "Non-success status code while streaming #{fragment.code}"
      end
    end
  end
  puts
  puts "Download #{filename} concluído!"
end

def download_curl(url, filename)
  puts "Download #{filename} ..."
  puts "Download #{url} ..." if $debug
  system("curl -LC- -o \"#{filename}\" -- \"#{url}\"")
  puts
  puts "Download #{filename} concluído!"
end

###########

items = []
pagenumber = 1

if $termo_homologacao
  puts
  puts "Baixando Termo de Homologacao do PE #{$numero_compra}/#{$ano_compra} UASG #{$uasg} ... "
  termo_homologacao_pdf_file = download_termo_homologacao()
  puts "Termo de Homologacao concluído: #{termo_homologacao_pdf_file}"
  exit
end

if $anexos
  puts
  puts "Baixando propostas/habilitação do PE #{$numero_compra}/#{$ano_compra} UASG #{$uasg} ... "
  threads = []
  get_items_proposals.each do |item|
    threads << Thread.new{
      p item if $debug
      download_curl("http://comprasnet.gov.br/livre/pregao/#{item[:url]}", "#{$basefilenameoutput}.#{item[:cnpj].delete("^0-9")}.#{item[:filename]}")
    }
  end
  threads.each{|t| t.join}
  puts
  puts "Baixando anexos dos itens do PE #{$numero_compra}/#{$ano_compra} UASG #{$uasg} ... "
  threads = []
  get_items_attachments.each do |item|
    threads << Thread.new{
      p item if $debug
      download_curl("http://comprasnet.gov.br/livre/pregao/#{item[:url]}", "#{$basefilenameoutput}.#{item[:cnpj].delete("^0-9")}.#{item[:filename]}")
    }
  end
  threads.each{|t| t.join}
  puts "Download dos anexos concluído!"
  exit
end

puts
puts "Extraindo itens do PE #{$numero_compra}/#{$ano_compra} UASG #{$uasg} ... "
puts
loop do
  url = "https://www2.comprasnet.gov.br/siasgnet-atasrp/public/pesquisarItemSRP.do?method=consultarPorFiltro&parametro.identificacaoCompra.numeroUasg=#{$uasg}&parametro.identificacaoCompra.modalidadeCompra=#{$modalidade_compra}&parametro.identificacaoCompra.numeroCompra=#{$numero_compra}&parametro.identificacaoCompra.anoCompra=#{$ano_compra}&numeroPagina=#{pagenumber}"

  page = html_get(url)
  parse_page = Nokogiri::HTML(page)

  items += items_extract(parse_page)
  pagenumber += 1
  print '.'
  break if last_page?(parse_page) # or pagenumber > 1
end

CSV.open(
  "#{$basefilenameoutput}.csv", 'wb',
  **{
    :col_sep => ',',
    # :force_quotes => true,
    :strip => true,
    :encoding => 'UTF-8'
  }
) do |csv|
  csv << items[0].keys # csv header

  items.each do |item|
    csv << item.values
  end
end

puts
puts "PE #{$numero_compra}/#{$ano_compra} UASG #{$uasg} concluído! Gerado arquivo #{$basefilenameoutput}.csv"
