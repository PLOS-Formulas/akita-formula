{% if salt['grains.get']('location') == 'soma' -%}
include:
  - common.hosts

extend:
  global-etc-hosts:
    file.managed:
      - context:
          hosts_present:
            - ip_address: 10.136.128.156
              hostnames: ['aa.plos.org']
            # this entry was commented out in /etc/hosts
            # - ip_address: 10.5.3.158
            #   hostnames: ['register.plos.org']
            #
            # this is a workaround until ops sets up DNS in Soma to 
            # resolve ".plos.org" (ITI-?)
            {% if salt['grains.get']('environment') == 'stage' %}
            - ip_address: 10.5.3.178
              hostnames: ['nedcas-stage.plos.org']
            {% endif %}

{% endif -%}
