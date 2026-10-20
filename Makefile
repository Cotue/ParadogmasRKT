.PHONY: test models

test:
	raco test tests

models:
	raco make src/models/contracts.rkt
	raco make src/models/catalog.rkt
	raco make src/models/preferences.rkt
	raco make src/models/combination.rkt
