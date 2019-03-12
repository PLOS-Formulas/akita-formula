{% from "lib/ruby.sls" import use_ruby -%}

{% set ruby_ver = salt.pillar.get('akita:versions:ruby') %}

{{ use_ruby(version=ruby_ver, user='akita', bundler_version='1.17.3') }}
