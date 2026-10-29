.PHONY: app-cli-fixtures app-cli-contract-check

app-cli-fixtures:
	cd cli && go run ./internal/appcontract/cmd --write

app-cli-contract-check:
	cd cli && go run ./internal/appcontract/cmd --check
