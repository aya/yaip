##
# ENV

# target .env: Update .env
## it updates .env file when .env.dist file is newer
.env: .env.dist
	$(call .env,,,$(wildcard $(CONFIG)/$(ENV)/$(APP)/.env .env.$(ENV)))

# target .env-clean: Remove .env
.PHONY: .env-clean
.env-clean:
	rm -f .env || true

# include .env file
-include .env

ifneq (,$(filter true,$(ENV_RESET)))
env_reset := -i
endif

env = $(env.args) $(env.dist) $(env.file)
env.docker = $(env.docker.args) $(env.docker.dist) $(env.docker.file)

env.args = $(foreach var,$(ENV_VARS),$(if $($(var)),$(var)='$($(var))'))
env.dist ?= $(shell printenv |awk -F '=' 'NR == FNR { if($$1 !~ /^(\#|$$)/) { A[$$1]; next } } ($$1 in A)' .env.dist - 2>/dev/null)
env.file ?= $(shell cat $(or $(ENV_FILE),/dev/null) 2>/dev/null |sed '/^[ \t]*$$/d;/^[ \t]*\#/d;s/='\''/=/;s/'\''$$//;s/='\"'/=/;s/'\"'$$//;' |awk -F '=' '{print $$1"='\''"$$2"'\''"}')
env.docker.args = $(foreach var,$(ENV_VARS),$(if $($(var)),-e $(var)='$($(var))'))
env.docker.dist ?= $(shell printenv |awk -F '=' 'NR == FNR { if($$1 !~ /^(\#|$$)/) { A[$$1]; next } } ($$1 in A) {print "-e "$$0}' .env.dist - 2>/dev/null)
env.docker.file ?= $(patsubst %,--env-file %,$(wildcard $(ENV_FILE)))

SHELL:=/bin/bash

# function .env: Call .env_update function
## it sets .env, .env.dist and .env.ENV files paths
## it calls .env_update function if .env.dist file exists
	# 1st arg: path to .env file to update, default to .env
	# 2nd arg: path to .env.dist file, default to .env.dist
	# 3rd arg: path to .env override files, default to .env.$(ENV)
define .env
	$(call INFO,.env,$(1)$(comma) $(2)$(comma) $(3))
	$(eval env_file:=$(or $(1),.env))
	$(eval env_dist:=$(or $(2),$(env_file).dist))
	$(eval env_over:=$(or $(wildcard $(3)),$(wildcard $(env_file).$(ENV))))
	$(if $(wildcard $(env_dist)), $(call .env_update))
endef

# function .env_update: Update .env file with values from .env.dist
## this function adds variables from the .env.dist to the .env file
## and does substitution to replace variables with their value when
## adding it to the .env. It reads variables first from environment,
## make command line, .env override files and finish with .env.dist
## to do the substitution. It does not write to .env file variables
## that already exist in .env file or comes from system environment.
	# create the .env file
	# read environment variables
	  # keep variables from .env.dist that does not exist in environment
	  # add variables definition from .env override files at the beginning
	  # add variables definition from make command line at the beginning
	  # remove duplicate variables
	  # keep variables that exists in .env.dist
	  # keep variables that does not exist in .env
	  # read variables definition in a subshell with multiline support
	    # create a new (empty if ENV_RESET is true) environment with env.args
	      # read environment variables and keep only those existing in .env.dist
	      # add .env overrides variables definition
	      # add .env.dist variables definition
	      # remove empty lines or comments
	      # remove duplicate variables
	    # replace variables in stdin with their value from the new environment
	  # remove residual empty lines or comments
	  # sort alphabetically
	  # add variables definition to the .env file
define .env_update
	$(call INFO,.env_update,$(env_file) $(env_dist) $(env_over))
	touch $(env_file)
	printenv \
	  |awk -F '=' 'NR == FNR { if($$1 !~ /^(#|$$)/) { A[$$1]; next } } !($$1 in A)' - $(env_dist) \
	  |cat $(env_over) - \
	  |awk 'BEGIN {split("$(MAKECMDVARS)",vars," "); for (var in vars) {print vars[var]"="ENVIRON[vars[var]]};} {print}' \
	  |awk -F '=' '!seen[$$1]++' \
	  |awk -F '=' 'ARGV[1] == FILENAME { A[$$1]; next } ($$1 in A)' $(env_dist) - 2>/dev/null \
	  |awk -F '=' 'ARGV[1] == FILENAME { A[$$1]; next } !($$1 in A)' $(env_file) - 2>/dev/null \
	  |(IFS=$$'\n'; \
	    env $(env_reset) $(env.args) \
	      $$(env |awk -F '=' 'NR == FNR { if($$1 !~ /^(#|$$)/) { A[$$1]; next } } ($$1 in A)' $(env_dist) - \
	        |cat - $(env_over) \
	        |cat - $(env_dist) \
	        |sed -e /^$$/d -e /^#/d \
	        |awk -F '=' '!seen[$$1]++') \
	      awk '{while(match($$0,"[$$]{[^}]*}")) {var=substr($$0,RSTART+2,RLENGTH-3);gsub("[$$]{"var"}",ENVIRON[var])} print}') \
	  |sed -e /^$$/d -e /^#/d \
	  |sort \
	  >> $(env_file);
endef
