_Table of contents_

<!-- TOC -->

- [Developing documentation](#developing-documentation)
- [Website generation](#website-generation)
  - [Test your changes in a local container](#test-your-changes-in-a-local-container)
    - [Run a Jekyll container](#run-a-jekyll-container)
    - [View the site](#view-the-site)
- [Adding new documentation](#adding-new-documentation)

<!-- /TOC -->

# Developing documentation

Documentation in this folder will be created by using asciidoc via the `utils/build.sh` script

For easing development and preview, a gulp configuration has been created in the root of the repository.

Remember that this still requires your environment to be able to execute `tools/build.sh` so dependencies like `asciidoctor` should be made available first.

For starting `gulp` environment:

- Install `NodeJS` and `Yarn` using your system package manager
- Install `gulp` via: `yarn global add gulp-cli`
- In the root of the repository, run `yarn install`
- Use Live Reload `gulp`

This will launch the browser and open the home page. Now when you edit the documentation files under `documentation/` and all opened tabs will automatically reload and reflect the change.

Documentation will be rendered and refreshed dynamically at `http://localhost:9001`.

# Website generation

Website is built from the `./website` folder templates, that uses `Jekyll` for generation.

When executing 'rake', dependencies will be installed and build will happen on `website/_site` which is the folder being rendered by `Netlify` or published via `Travis`.
The script at `utils/build-jekyll.sh` performs the steps required by Netlify and GitHub Pages.

With above approach, we can still use `utils/build.sh` as part of the workflow, keep the `website` independent of other pieces in the repository and still benefits from the features provided by `Jekyll` to generate richer webpages.

Regarding the documentation, the script `build.sh` generates a `yaml` containing each one of the generated releases, which then, Jekyll uses to render the items in the main page for each one of the releases.

## Test your changes in a local container

### Run a Jekyll container

- On a `SELinux` enabled OS:

  ```console
  cd website
  mkdir .jekyll-cache
  podman run -d --name bmdeploy -p 4000:4000 -v $(pwd):/srv/jekyll:Z jekyll/jekyll jekyll serve --watch --future
  ```

  **NOTE**: Be sure to `cd` into the _website_ directory before running the above command as the Z at the end of the volume (-v) will relabel its contents so it can be written from within the container, like running `chcon -Rt svirt_sandbox_file_t -l s0:c1,c2` yourself.

- On an OS without `SELinux`:

  ```console
  cd website
  mkdir .jekyll-cache
  podman run -d --name bmdeploy -p 4000:4000 -v $(pwd):/srv/jekyll jekyll/jekyll jekyll serve --watch --future
  ```

### View the site

Visit `http://0.0.0.0:4000` in your local browser.

# Adding new documentation

We can add versioned or unversioned (latest) documents.

To do so, edit the `utils/build.sh` and check the headers:

```sh
#Space separated version list to build
RELEASES="4.4 4.3"

#Versioned documents
DOCS="Deployment"

#Documents using latest
STATIC="Deployment"

#Devel releases for static documents and devel docs
DEVRELEASE="4.5"
```

With above example, we'll build the documents for release argument 4.4 and 4.3 for each one of the documents indicated in `DOCS`, and at the same time, create another copy of that document using release 4.5 that will be displayed in another section in the frontpage.

If now, for example we want to have an additional document (not versioned) for `Troubleshooting`, the steps to perform are:

- Create a symbolic link from the filename to `Troubleshooting` in the `documentation/` folder
- Add `Troubleshooting` with a space to `STATIC`, so that the script loop that generates it will take it from there.

The new doc, `Troubleshooting` will appear in the `Additional` section and will get a `-a release=4.5` when generated, this allows for example the example above, where the `Deployment` guide can be live previewed before moving it into the `Documentation` section.
