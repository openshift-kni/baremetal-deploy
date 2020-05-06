---
title: Deploying Installer Provisioned Infrastructure (IPI) of OpenShift on Bare Metal
layout: default
tags: [baremetal, openshift, ipi, ansible, documentation, manual]
---

## Installer Provisioned Infrastructure (IPI) of OpenShift on Baremetal Install Guides

Below is the list of generated documentation versions

<table style="width:100%">
  <tr>
    <th>Release</th>
    <th>Format</th>
  </tr>

{% for release in site.data.releases %}
{% assign version = release[1] %}

  <tr>
  <td>{{version.name}}</td>
  <td>
    <a href="{{ version.folder }}">
       <i class="fab fa-html5"></i> HTML
    </a>
    |
    <a href="{{ version.folder }}index.pdf">
      <i class="fas fa-file-pdf"></i> PDF
    </a>
    </td>
  </tr>
{% endfor %}

</table>

> info ""
> These guides are created from the contents of the repository under [`documentation/`](https://github.com/openshift-kni/baremetal-deploy/tree/master/documentation) folder.
