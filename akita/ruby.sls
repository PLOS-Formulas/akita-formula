{% set ruby_ver = salt.pillar.get('akita:versions:ruby') %}

include:
  - common.packages
  - common.repos

plos-ruby:
  pkg.installed:
    - pkgs:
      - plos-ruby-{{ ruby_ver }}
      - chruby
