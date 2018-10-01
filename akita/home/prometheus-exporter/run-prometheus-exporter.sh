#!/bin/bash

cd prometheus_exporter
bin/prometheus_exporter -v -c akita_collector.rb --prefix akita_

# TODO: uncomment the lines below once this PR has been accepted
# https://github.com/discourse/prometheus_exporter/pull/36

#bundle install
#prometheus_exporter -v -c akita_collector.rb --prefix akita_
