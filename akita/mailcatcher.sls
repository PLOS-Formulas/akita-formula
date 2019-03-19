{% set ruby_ver = salt.pillar.get('akita:versions:ruby') %}
{% set oscodename = salt.grains.get('oscodename') %}

include:
  - akita.ruby

install-mailcatcher:
  cmd.run:
   - name: chruby-exec {{ ruby_ver }} -- gem install mailcatcher
   - unless: chruby-exec {{ ruby_ver }} -- mailcatcher --help
   - runas: root
   - require:
     - pkg: plos-ruby-{{ ruby_ver }}

{% if oscodename == 'trusty' %}
/etc/init/mailcatcher.conf:
  file.managed:
    - template: jinja
    - source: salt://akita/etc/init/mailcatcher.conf.sls
    - user: root
    - group: root

mailcatcher:
  service.running:
    - enable: True
    - require:
      - file: /etc/init/mailcatcher.conf
{% else %}
mailcatcher-unit-file:
  file.managed:
    - name: /etc/systemd/system/mailcatcher.service
    - source: salt://akita/etc/systemd/system/mailcatcher.service

mailcatcher-service:
  service.running:
    - name: mailcatcher
    - enable: True
    - require:
      - file: /etc/systemd/system/mailcatcher.service
{%endif%}
