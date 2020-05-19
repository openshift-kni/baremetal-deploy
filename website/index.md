---
title: Deploying Installer Provisioned Infrastructure (IPI) of OpenShift on Bare Metal
layout: default
tags: [baremetal, openshift, ipi, ansible, documentation, manual]
---

## Installer Provisioned Infrastructure (IPI) of OpenShift on Baremetal Install Guides

### Documentation

Below is the list of generated documentation versions

<table style="width:100%">
  <tr>
    <th>Document</th>
    <th>Release</th>
    <th>Format</th>
  </tr>

{% for release in site.data.releases %}
{% assign version = release[1] %}

  <tr>
  <td>{{version.name}}</td>
  <td>{{version.release}}</td>
  <td>
    <a href="{{ version.folder }}.html">
       <i class="fab fa-html5"></i> HTML
    </a>
    |
    <a href="{{ version.folder }}.pdf">
      <i class="fas fa-file-pdf"></i> PDF
    </a>
    </td>
  </tr>
{% endfor %}

{% for release in site.data.static %}
{% assign version = release[1] %}

  <tr>
  <td>{{version.name}}</td>
  <td>-</td>
  <td>
    <a href="{{ version.folder }}">
       <i class="fab fa-html5"></i> HTML
    </a>
    |
    <a href="{{ version.folder }}.pdf">
      <i class="fas fa-file-pdf"></i> PDF
    </a>
    </td>
  </tr>
{% endfor %}

</table>

> info ""
> Documents in this section are additional information.

### Development Draft

<table style="width:100%">
  <tr>
    <th>Document</th>
    <th>Format</th>
  </tr>

{% for release in site.data.devprev %}
{% assign version = release[1] %}

  <tr>
  <td>{{version.name}}</td>
  <td>
    <a href="{{ version.folder }}">
       <i class="fab fa-html5"></i> HTML
    </a>
    |
    <a href="{{ version.folder }}.pdf">
      <i class="fas fa-file-pdf"></i> PDF
    </a>
    </td>
  </tr>
{% endfor %}

</table>

> error ""
> Documents in this section are still not released drafts and might be not accurate or complete
