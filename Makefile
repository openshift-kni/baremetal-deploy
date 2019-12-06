init:
	{ pipenv --version; } || pip install pipenv
	pipenv install --dev

test:
	pipenv run pytest
