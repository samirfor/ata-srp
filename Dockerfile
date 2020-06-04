FROM ruby:2.7

WORKDIR /usr/src/app

RUN apt update && apt install -y wkhtmltopdf

COPY Gemfile* ./

RUN bundle install

COPY *.rb ./

CMD [ "ruby", "web_scraper_ng.rb" ]