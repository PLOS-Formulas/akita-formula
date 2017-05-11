{% set ruby_ver = salt.pillar.get('akita:versions:ruby') %}

include:
  - akita.ruby

install-mailcatcher:
  cmd.run:
   - name: chruby-exec {{ ruby_ver }} -- gem install mailcatcher
   - unless: chruby-exec {{ ruby_ver }} -- mailcatcher --help
   - user: root
   - require:
     - pkg: plos-ruby

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
