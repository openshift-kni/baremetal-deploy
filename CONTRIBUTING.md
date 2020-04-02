# How to Contribute

This project is [Apache 2.0 licensed](LICENSE) and accepts contributions via
GitHub pull requests.

## Guidelines

- A change should not being merged unless it passes CI or there is a comment/update saying what testing was passed.
- PRs should not be merged unless positively reviewed.
- If a change is adding a feature, it should require a change to the `README.md` and the review should catch this.
- If a change is a fix, it should have an issue. The review should make sure the comments state the issue (not just the number) and it should use the keywords that will close the issue on merge.
- Install package `pre-commit` for your distribution or check <https://pre-commit.com/#install> and once installed, run `pre-commit install` inside the repository to get the hook installed.
  - `pre-commit` will check for several tests to pass as defined in its configuration file like:
    - proper python formatting (via black and flake)
    - YAML formatting
    - Markdown issues/formatting
    - JSON formatting
    - spell checking via `yaspeller` (and duplicate words)
    - proper `shebang` or executable permissions
    - end-of-file fixer
    - proper language encoding in Python files
    - shell formatting via `shfmt`
    - etc
  - If one of the plugins fails or makes changes, you'll need to review them via `git diff` and then add the modified files if everything is ok.
  - For spell checking, update `.yaspeller.json` as needed to add the new words. Sorting the file is not mandatory, but makes it easier to check for existing words (but the spell checker will complain if duplicates are found). Words within code blocks are ignored, so not blindly add new words and check if it's a name for a variable or property and it should be `quoted as code` or not instead.

## Certificate of Origin

By contributing to this project you agree to the Developer Certificate of
Origin (DCO). This document was created by the Linux Kernel community and is a
simple statement that you, as a contributor, have the legal right to make the
contribution. See the [DCO](DCO) file for details.
