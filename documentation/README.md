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
