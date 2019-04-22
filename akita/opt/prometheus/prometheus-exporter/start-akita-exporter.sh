#!/bin/bash

export HOME=/opt/prometheus
source /opt/prometheus/prometheus-exporter/.prometheus-exporter-rc

if ! gem list prometheus_exporter -i; then
    cd $HOME && bundle install
fi

cd $HOME && prometheus_exporter -v -c prometheus-exporter/akita_collector.rb --prefix akita_