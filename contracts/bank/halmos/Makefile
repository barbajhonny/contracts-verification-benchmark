# Params
to = 10m

# Input files
VERSIONS_DIR = ../versions/
PROPERTIES_DIR = .
GROUND_TRUTH = ../ground-truth.csv
PROPERTIES_FILES = $(wildcard $(PROPERTIES_DIR)/*.t.sol)
VERSIONS_FILES = $(wildcard $(VERSIONS_DIR)/*.sol)

# Output files
BUILD_DIR = build
OUTPUT_DIR = $(BUILD_DIR)/halmos
CONTRACTS_DIR = $(BUILD_DIR)/contracts
LOGS_DIR = $(OUTPUT_DIR)/logs
LIB_DIR = $(CONTRACTS_DIR)/lib
OUT = $(OUTPUT_DIR)/out.csv
CM = $(OUTPUT_DIR)/cm.csv
TABLE = $(OUTPUT_DIR)/table.md

PYTHON = python

.PHONY: run one setup contracts directories clean

#---------------------------- RUN (batch) --------------------------------#
run: $(TABLE)

$(TABLE): $(CM)
	@echo "Generating Halmos results table ($(TABLE))..."
	@echo "#### Halmos" > $(TABLE)
	@$(PYTHON) ../../../scripts/mdtable_gen.py --input $(CM) >> $(TABLE)

$(CM): $(GROUND_TRUTH) $(OUT)
	@echo "Generating Halmos confusion matrix ($(CM))..."
	@$(PYTHON) ../../../scripts/cm_gen.py --ground-truth $(GROUND_TRUTH) --results $(OUT) > $(CM)

$(OUT): setup $(PROPERTIES_FILES) $(VERSIONS_FILES)
	@echo "Running Halmos experiments..."
	@$(PYTHON) ../../../scripts/run_halmos.py \
	    --contracts $(CONTRACTS_DIR) \
	    --output $(OUTPUT_DIR) \
	    --timeout $(to) \
	    --halmos-dir $(CONTRACTS_DIR)

#---------------------------- ONE (singolo test) --------------------------------#
# Uso: make one contract=build/contracts/v1_assets-dec-onlyif-deposit.t.sol
one: setup
	@if [ -z "$(contract)" ]; then \
		echo "Error: 'contract' variable is not set."; \
		echo "Usage: make one contract=build/contracts/v1_assets-dec-onlyif-deposit.t.sol"; \
		exit 1; \
	fi
	@echo "Running single test: $(contract)"
	@$(PYTHON) ../../../scripts/run_halmos.py \
	    --contracts $(contract) \
	    --output $(OUTPUT_DIR) \
	    --timeout $(to) \
	    --halmos-dir $(CONTRACTS_DIR)

#---------------------------- SETUP ------------------------------#
setup: contracts directories

contracts: $(PROPERTIES_FILES) $(CONTRACTS_DIR) $(LIB_DIR)
	@echo "Generating version-specific test files for Halmos..."
	@cp ./foundry.toml $(CONTRACTS_DIR)/
	@mkdir -p $(CONTRACTS_DIR)/versions
	@cp -r $(LIB_DIR) $(CONTRACTS_DIR)/versions/lib
	@for ver_file in $(notdir $(VERSIONS_FILES)); do \
		ver_name=$${ver_file%.sol}; \
		ver_short=$$(echo $$ver_name | sed 's/Bank_//'); \
		cp $(VERSIONS_DIR)/$$ver_file $(CONTRACTS_DIR)/versions/$$ver_short.sol; \
		for prop_file in $(PROPERTIES_FILES); do \
			prop_name=$$(basename $$prop_file .t.sol); \
			target_file=$(CONTRACTS_DIR)/$${ver_short}_$${prop_name}.t.sol; \
			if [ "$$ver_short" = "v3" ]; then \
				sed -e "s/{{VERSION}}/$$ver_short/g" -e "s/{{CONSTRUCTOR_SETUP}}/bank = new Bank(100 ether)/g" $$prop_file > $$target_file; \
			else \
				sed -e "s/{{VERSION}}/$$ver_short/g" -e "s/{{CONSTRUCTOR_SETUP}}/bank = new Bank()/g" $$prop_file > $$target_file; \
			fi; \
		done; \
	done

directories: $(CONTRACTS_DIR) $(LOGS_DIR) $(LIB_DIR)

$(CONTRACTS_DIR):
	@mkdir -p $@

$(LOGS_DIR):
	@mkdir -p $@

$(LIB_DIR):
	@cp -r ../../../lib/ $@
	@rm -f $@/ERC20v2.sol
	@rm -f $@/ERC20v3.sol

#---------------------------- CLEAN ------------------------------#
clean:
	rm -rf $(BUILD_DIR)