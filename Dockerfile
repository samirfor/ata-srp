FROM ruby:2.7

WORKDIR /usr/src/app

COPY Gemfile* ./

RUN bundle install

COPY *.rb ./

CMD [ "ruby", "web_scraper_ng.rb" ]