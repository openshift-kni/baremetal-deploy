_Table of contents_

<!-- TOC -->

- [Developing documentation](#developing-documentation)
- [Website generation](#website-generation)
  - [Test your changes in a local container](#test-your-changes-in-a-local-container)
    - [Run a Jekyll container](#run-a-jekyll-container)
    - [View the site](#view-the-site)

<!-- /TOC -->

# Developing documentation

Documentation in this folder will be created by using asciidoc via the `utils/build.sh` script

For easing development and preview, a gulp configuration has been created in the root of the repository.

Remember that this still requires your environment to be able to execute `tools/build.sh` so dependencies like `asciidoctor` should be made available first.

For starting `gulp` environment:

- Install `NodeJS` and `Yarn` using your system package manager
- Install `gulp`
  `yarn global add gulp-cli`
- In the root of the repository, run
  `yarn install`
- Use Live Reload
  `gulp`

This will launch the browser and open the home page. Now when you edit the documentation files under `documentation/` and all opened tabs will automatically reload and reflect the change.

Documentation will be rendered and refreshed dynamically at http://localhost:9001.

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
