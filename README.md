Atas SRP Web Scraper
==========================

Web scraper em Ruby para extrair quantidades empenhadas do sistema Gestão de Ata de Registro de Preço/SRP.

TL;DR
---------

```shell
docker run -v "$PWD:/usr/src/app" samirfor/ata-srp web_scraper_ng.rb -h # show usage
docker run -v "$PWD:/usr/src/app" samirfor/ata-srp web_scraper_ng.rb --compra 02 --ano 2019 --uasg 154618 -d # PE n. 02/2019 UASG 154618
# batch mode
docker run -v "$PWD:/usr/src/app" samirfor/ata-srp batch.rb --file pregoes_test.csv
```

Docker
---------

```shell
# Git clone this repo
git clone https://github.com/samirfor/ata-srp.git

# Build docker image
docker build -t ata-srp .

# Run script - single mode
docker run -v "$PWD:/usr/src/app" ata-srp:latest ruby web_scraper_ng.rb --compra 02 --ano 2019 --uasg 154618 -d

# Run script - batch mode
docker run -v "$PWD:/usr/src/app" ata-srp:latest ruby batch.rb --file pregoes_test.csv

# Help
docker run -v "$PWD:/usr/src/app" ata-srp:latest ruby web_scraper_ng.rb -h
```

Traditional way
---------

```shell
# Install ruby: https://www.ruby-lang.org/en/documentation/installation/

# Git clone this repo
git clone https://github.com/samirfor/ata-srp.git

# Install depedencies
bundle install

# Run script - single mode
ruby web_scraper_ng.rb --compra 02 --ano 2019 --uasg 154618 -d

# Run script - batch mode
ruby batch.rb --file pregoes_test.csv

# Help
ruby web_scraper_ng.rb -h
```
