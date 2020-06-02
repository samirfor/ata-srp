#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'optparse'

Options = Struct.new(:file, :debug)

class Parser
  def self.parse(options)
    args = Options.new

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: ruby #{opts.program_name}.rb [options]"

      opts.on('-f FILE', '--file=FILE', 'Arquivo CSV com os pregões: compra,ano,uasg') do |u|
        if (not File.exist?(u)) || (not File.readable?(u))
          puts "ERRO: Arquivo inexistente ou não legível."
          exit
        end
        args.file = u
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
$file = options[:file]
$stdout.sync = true
$output_filename = "#{$file}.dados.#{Time.now.strftime('%F-%H%M')}.csv"
debugmode = "-d" if $debug

def process(input)
  puts "Start process: #{input}"



  puts "Done with: #{input}"
end

threads = []

puts
puts "Lendo #{$file} iniciando em #{Time.now}"

CSV.foreach($file, **{headers: :first_row, converters: :numeric, :encoding => 'UTF-8'}) do |row|
  threads << Thread.new{
    system("ruby web_scraper_ng.rb --ano=#{row[1]} --compra=#{row[0]} --uasg=#{row[2]} #{debugmode}")
  }
end
puts "#{$file} lido com sucesso! Processando..."

threads.each{|t| t.join}

puts
puts "Pregões processados. Gerando compilado #{$output_filename}"

CSV.open(
  $output_filename, 'wb',
  **{
    :col_sep => ',',
    # :force_quotes => true,
    :strip => true,
    :encoding => 'UTF-8'
  }
) do |csv|
  CSV.foreach($file, **{headers: :first_row, converters: :numeric, :encoding => 'UTF-8'}) do |row|
    CSV.foreach("PE#{row[0]}#{row[1]}.UASG.#{row[2]}.csv", **{headers: :first_row, converters: :numeric, :encoding => 'UTF-8'}) do |row|
      csv << row
    end
  end
end
puts
puts "#{$output_filename} gerado com sucesso!"
puts "Finalizado em #{Time.now}"
