# Params
to = 10m
contract = ""
PROPERTY = ""
VERSION = ""

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

#---------------------------- RUN --------------------------------#
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
	@for test_file in $(CONTRACTS_DIR)/*.t.sol; do \
		$(PYTHON) ../../../scripts/run_halmos.py \
		    --contracts $$test_file \
		    --output $(OUTPUT_DIR) \
		    --timeout $(to) \
		    --halmos-dir $(CONTRACTS_DIR); \
	done

#---------------------------- ONE --------------------------------#
one: setup
	@echo "Running single test: $(PROPERTY) ($(VERSION))"
	$(PYTHON) ../../../scripts/run_halmos.py \
	    --contracts $(CONTRACTS_DIR) \
	    --output $(OUTPUT_DIR) \
	    --timeout $(to) \
	    --halmos-dir $(CONTRACTS_DIR) \
	    --property $(PROPERTY) \
	    --version $(VERSION)

#---------------------------- ONE-PROPERTY-ALL-VERSIONS -----------------------------#
one-property-all-versions:
	@echo "Running $(PROPERTY) on all versions..."
	@for version in $(notdir $(VERSIONS_FILES:.sol=)); do \
		$(MAKE) one PROPERTY=$(PROPERTY) VERSION=$$version; \
	done
	
#---------------------------- SETUP ------------------------------#
setup: contracts directories

contracts: $(PROPERTIES_FILES) $(CONTRACTS_DIR)
	@echo "Generating version-specific test files for Halmos..."
	@cp ./foundry.toml $(CONTRACTS_DIR)/
	@for ver_file in $(notdir $(VERSIONS_FILES)); do \
		ver_name=$${ver_file%.sol}; \
		for prop_file in $(PROPERTIES_FILES); do \
			prop_name=$$(basename $$prop_file .t.sol); \
			target_file=$(CONTRACTS_DIR)/$${ver_name}_$${prop_name}.t.sol; \
			sed "s/{{VERSION}}/$$ver_name/g" $$prop_file > $$target_file; \
		done; \
	done

directories: $(CONTRACTS_DIR) $(LOGS_DIR) $(LIB_DIR)

$(CONTRACTS_DIR):
	@mkdir -p $@

$(LOGS_DIR):
	@mkdir -p $@

$(LIB_DIR):
	@cp -r ../../../lib/ $@

#---------------------------- CLEAN ------------------------------#
clean:
	rm -rf $(BUILD_DIR)