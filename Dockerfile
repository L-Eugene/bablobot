FROM ruby:3.2

WORKDIR /usr/src/app
ENTRYPOINT ["ruby", "app.rb"]

COPY Gemfile ./
RUN bundle install

COPY app.rb ./
COPY actions/ ./actions/