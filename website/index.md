---
title: Deploying Installer Provisioned Infrastructure (IPI) of OpenShift on Bare Metal
---

Installer Provisioned Infrastructure (IPI) of OpenShift on Baremetal Install Guides

<ul>
{% for release in site.data.releases %}
{% assign version = release[1] %}
  <li>Release
    <a href="{{ version.folder }}/">
      {{ version.name }}
    </a>
    <a href="{{ version.folder }}/index.pdf">
      <i class="fas fa-file-pdf"></i>
    </a>
  </li>
{% endfor %}
</ul>
