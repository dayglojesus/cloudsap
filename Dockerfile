FROM ruby:2.7 as build

RUN mkdir /app

WORKDIR /app

COPY lib/ ./lib
COPY bin/ ./bin
COPY exe/ ./exe
COPY *.md *.rdoc *.gemspec Gemfile* LICENSE.txt ./

RUN echo 'gem: --no-document' > /etc/gemrc \
  && bundle config jobs 5 \
  && bundle config set no-cache 'true' \
  && bundle config set deployment 'true' \
  && bundle config set without 'development test' \
  && bundle config set path 'vendor' \
  && bundle install -j4 --retry 3 \
  && gem source --clear-all

#####################################################################
# Ready to Publish
#####################################################################

FROM ruby:2.7-slim
MAINTAINER Brian Warsing <dayglojesus@gmail.com>

COPY --from=build /app /app
COPY --from=build /root/.bundle/config /root/.bundle/config

WORKDIR /app

CMD bundle exec cloudsap
