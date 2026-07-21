SOLCMC_DIR = ./solcmc
SOLCMC_BUILD_DIR = $(SOLCMC_DIR)/build
SOLCMC_Z3_TABLE = $(SOLCMC_BUILD_DIR)/z3/table.md
SOLCMC_ELD_TABLE = $(SOLCMC_BUILD_DIR)/eld/table.md

CERTORA_DIR = ./certora
CERTORA_BUILD_DIR = $(CERTORA_DIR)/build
CERTORA_TABLE = $(CERTORA_BUILD_DIR)/table.md

# Halmos
HALMOS_DIR = ./halmos
HALMOS_BUILD_DIR = $(HALMOS_DIR)/build
HALMOS_TABLE = $(HALMOS_BUILD_DIR)/halmos/table.md

VERSIONS_DIR = ./versions
SKELETON = ./skeleton.json
GROUND_TRUTH = ./ground-truth.csv
README = README.md

PYTHON = python

.PHONY: all certora solcmc halmos plain clean cleanr clean-solcmc clean-certora clean-halmos

all: plain solcmc certora halmos
	@echo "Adding Solcmc table to README..."
	@echo "### SolCMC" >> $(README)
	@cat $(SOLCMC_Z3_TABLE) >> $(README)
	@cat $(SOLCMC_ELD_TABLE) >> $(README)
	@echo "" >> $(README)
	@echo "Adding Certora table to README..."
	@cat $(CERTORA_TABLE) >> $(README)
	@echo "" >> $(README)
	@echo "Adding Halmos table to README..."
	@cat $(HALMOS_TABLE) >> $(README)

#---------------------------- CERTORA ----------------------------#
certora: $(CERTORA_TABLE)

$(CERTORA_TABLE):
	@cd $(realpath $(CERTORA_DIR)) && make

#---------------------------- SOLCMC -----------------------------#
solcmc: $(SOLCMC_Z3_TABLE) $(SOLCMC_ELD_TABLE)

$(SOLCMC_Z3_TABLE):
	@cd $(realpath $(SOLCMC_DIR)) && make solver=z3

$(SOLCMC_ELD_TABLE):
	@cd $(realpath $(SOLCMC_DIR)) && make solver=eld

#---------------------------- HALMOS -----------------------------#
halmos: $(HALMOS_TABLE)

$(HALMOS_TABLE):
	@cd $(realpath $(HALMOS_DIR)) && make

#---------------------------- README -----------------------------#
plain: cleanr $(README)
	
$(README): $(VERSIONS_DIR) $(SKELETON) $(GROUND_TRUTH)
	@echo "Generating plain README..."
	@$(PYTHON) ../../scripts/readme_gen.py -d . > $(README)
	# @echo "## Experiments" >> $(README)

#---------------------------- CLEAN ------------------------------#
clean: cleanr clean-solcmc clean-certora clean-halmos

cleanr:
	rm -f $(README)

clean-solcmc:
	cd $(realpath $(SOLCMC_DIR)) && make clean

clean-certora:
	cd $(realpath $(CERTORA_DIR)) && make clean

clean-halmos:
	cd $(realpath $(HALMOS_DIR)) && make clean