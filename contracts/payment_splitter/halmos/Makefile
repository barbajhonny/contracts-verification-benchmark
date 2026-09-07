# Params
to = 10m
ver =                                   # Optional usage: make run ver=v1 
prop =                                  # Optional usage: make run prop=fair-split-eq

# Version normalization: guarantees the 'v' prefix if only the number is entered (e.g. 1 -> v1)
VER_NORMALIZED = $(if $(ver),$(if $(patsubst v%,%,$(ver)),v$(patsubst v%,%,$(ver)),$(ver)),)

# Input files
VERSIONS_DIR = ../versions
PROPERTIES_DIR = .
GROUND_TRUTH = ../ground-truth.csv

# Selection of versions and properties 
VERSIONS_FILES = $(if $(VER_NORMALIZED),\
    $(wildcard $(VERSIONS_DIR)/PaymentSplitter_$(VER_NORMALIZED).sol),\
    $(wildcard $(VERSIONS_DIR)/PaymentSplitter_*.sol))

PROPERTIES_FILES = $(if $(prop),\
    $(wildcard $(PROPERTIES_DIR)/$(prop).t.sol),\
    $(wildcard $(PROPERTIES_DIR)/*.t.sol))

# Output files
BUILD_DIR = build
OUTPUT_DIR = $(BUILD_DIR)/halmos
CONTRACTS_DIR = $(BUILD_DIR)/contracts
LOGS_DIR = $(OUTPUT_DIR)/logs
LIB_DIR = $(CONTRACTS_DIR)/lib
OUT = $(OUTPUT_DIR)/out.csv
CM = $(OUTPUT_DIR)/cm.csv
TABLE = $(OUTPUT_DIR)/table.md

# Path to payment-splitter/
ROOT_PAYMENTSPLITTER_HALMOS_CSV = ../halmos.csv

PYTHON = python

.PHONY: run setup contracts directories clean

#---------------------------- RUN --------------------------------#
run: $(TABLE)

$(TABLE): $(CM)
	@echo "Generating Halmos results table ($(TABLE))..."
	@echo "#### Halmos" > $(TABLE)
	@$(PYTHON) ../../../scripts/mdtable_gen.py --input $(CM) >> $(TABLE)

$(CM): $(GROUND_TRUTH) $(OUT)
	@echo "Generating Halmos confusion matrix ($(CM))..."
	@$(PYTHON) ../../../scripts/cm_gen.py --ground-truth $(GROUND_TRUTH) --results $(OUT) > $(CM)
	#@cp -f $(OUT) $(ROOT_PAYMENTSPLITTER_HALMOS_CSV)

$(OUT): setup
	@echo "Injecting loop bound into Halmos tool..."
	@sed -i 's/"--solver-timeout-assertion", solver_timeout_ms/"--solver-timeout-assertion", solver_timeout_ms,\n            "--loop", "3"/g' ../../../scripts/tools/halmos.py
	@echo "Running Halmos experiments..."
	@if $(PYTHON) ../../../scripts/run_halmos.py \
		--contracts $(CONTRACTS_DIR) \
		--output $(OUTPUT_DIR) \
		--timeout $(to) \
		--halmos-dir $(CONTRACTS_DIR) \
		$(if $(VER_NORMALIZED),--version $(VER_NORMALIZED),) \
		$(if $(prop),--property $(prop),); then \
		echo "Halmos finished successfully. Restoring halmos.py..."; \
		git checkout ../../../scripts/tools/halmos.py; \
	else \
		echo "Halmos finished with errors. Restoring halmos.py..."; \
		git checkout ../../../scripts/tools/halmos.py; \
		exit 1; \
	fi

#---------------------------- SETUP ------------------------------#
setup: contracts directories
     
contracts: $(CONTRACTS_DIR) $(LIB_DIR)
	@echo "Generating version-specific test files for Halmos..."
	@cp ./foundry.toml $(CONTRACTS_DIR)/
	@mkdir -p $(CONTRACTS_DIR)/versions
	@cp -r $(LIB_DIR) $(CONTRACTS_DIR)/versions/lib
	@for ver_file in $(notdir $(VERSIONS_FILES)); do \
        ver_name=$${ver_file%.sol}; \
        ver_short=$$(echo $$ver_name | sed 's/PaymentSplitter_//'); \
        cp $(VERSIONS_DIR)/$$ver_file $(CONTRACTS_DIR)/versions/$$ver_short.sol; \
        for prop_file in $(PROPERTIES_FILES); do \
            prop_name=$$(basename $$prop_file .t.sol); \
            prop_name_safe=$$(echo $$prop_name | sed 's/-/_/g'); \
            target_file=$(CONTRACTS_DIR)/$${ver_short}_$${prop_name_safe}.t.sol; \
           if [ "$$ver_short" = "v2" ]; then \
                sed -e "s/{{VERSION}}/$$ver_short/g" \
                    -e "s/{{CONTRACT_NAME}}/PaymentSplitterTest_$${ver_short}_$${prop_name_safe}/g" \
                    -e "s/contract PaymentSplitterTest/contract PaymentSplitterTest_$${ver_short}_$${prop_name_safe}/g" \
                    -e "s|{{CONSTRUCTOR_SETUP}}|PaymentSplitter splitter = new PaymentSplitter{value: initialFunding}(payee1, shares1, payee2, shares2, payee3, shares3)|g" $$prop_file > $$target_file; \
            elif [ "$$ver_short" = "v3" ]; then \
                sed -e "s/{{VERSION}}/$$ver_short/g" \
                    -e "s/{{CONTRACT_NAME}}/PaymentSplitterTest_$${ver_short}_$${prop_name_safe}/g" \
                    -e "s/contract PaymentSplitterTest/contract PaymentSplitterTest_$${ver_short}_$${prop_name_safe}/g" \
                    -e "s|{{CONSTRUCTOR_SETUP}}|PaymentSplitter splitter = new PaymentSplitter{value: initialFunding}(payee1, payee2, payee3)|g" $$prop_file > $$target_file; \
            else \
                sed -e "s/{{VERSION}}/$$ver_short/g" \
                    -e "s/{{CONTRACT_NAME}}/PaymentSplitterTest_$${ver_short}_$${prop_name_safe}/g" \
                    -e "s/contract PaymentSplitterTest/contract PaymentSplitterTest_$${ver_short}_$${prop_name_safe}/g" \
                    -e "s|{{CONSTRUCTOR_SETUP}}|address[] memory payees_arr = new address[](3); payees_arr[0] = payee1; payees_arr[1] = payee2; payees_arr[2] = payee3; uint256[] memory shares_arr = new uint256[](3); shares_arr[0] = shares1; shares_arr[1] = shares2; shares_arr[2] = shares3; PaymentSplitter splitter = new PaymentSplitter{value: initialFunding}(payees_arr, shares_arr)|g" $$prop_file > $$target_file; \
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