Atas SRP Web Scraper
==========================

Web scraper em Ruby para extrair quantidades empenhadas do sistema Gestão de Ata de Registro de Preço/SRP.

## TL;DR
```shell
docker run samirfor/ata-srp [params]
```

## Docker
```shell
# Git clone this repo
git clone https://github.com/samirfor/ata-srp.git

# Build docker image
docker build -t ata-srp .

# Run script
docker run -v "$PWD:/usr/src/app" ata-srp:latest ruby web_scraper_ng.rb [params]
```

## Traditional way
```shell
# Install ruby: https://www.ruby-lang.org/en/documentation/installation/

# Git clone this repo
git clone https://github.com/samirfor/ata-srp.git

# Install depedencies
bundle install

# Run script
ruby web_scraper_ng.rb [params]
```

