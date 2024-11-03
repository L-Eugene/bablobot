FROM ruby:3.2

WORKDIR /usr/src/app
CMD ["ruby", "app.rb"]

COPY Gemfile ./
RUN bundle install

COPY app.rb ./