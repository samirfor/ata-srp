FROM ruby:2.7

WORKDIR /usr/src/app

COPY Gemfile* *.rb ./

RUN bundle install

CMD [ "ruby", "web_scraper_ng.rb" ]