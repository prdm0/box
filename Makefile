rscript = Rscript --no-save --no-restore
unexport R_PROFILE_USER

# Deployment configuration
deploy_remote ?= origin
deploy_branch ?= master
deploy_source ?= develop

r_source_files = $(wildcard R/*.r)

rmd_files = $(wildcard vignettes/*.rmd)
knit_results = $(patsubst vignettes/%.rmd,doc/%.md,${rmd_files})

favicons_small = $(addprefix pkgdown/favicon/,$(addprefix favicon-,16x16.png 32x32.png))

favicons_large = $(addprefix pkgdown/favicon/,\
	$(addsuffix .png,$(addprefix apple-touch-icon-,60x60 76x76 120x120 152x152 180x180)))

favicons = ${favicons_small} ${favicons_large}

inkscape = $(shell command -v inkscape || echo /Applications/Inkscape.app/Contents/MacOS/inkscape)

.PHONY: all
all: documentation vignettes

.PHONY: deploy
## Deploy the code with documentation to Github
deploy: update-master
	git add --force NAMESPACE
	git add --force man
	git add --force doc
	git commit --message Deployment
	git push --force ${deploy_remote} ${deploy_branch}
	git checkout ${deploy_source}
	git checkout DESCRIPTION # To undo Roxygen meddling with file

.PHONY: update-master
update-master:
	git checkout ${deploy_source}
	-git branch --delete --force ${deploy_branch}
	git checkout -b ${deploy_branch}
	${MAKE} documentation vignettes

.PHONY: test
## Run unit tests
test: documentation
	${rscript} -e "devtools::test(export_all = FALSE)"

test-%: documentation
	${rscript} -e "devtools::test(filter = '$*', export_all = FALSE)"

.PHONY: check
## Run R CMD check
check: documentation
	mkdir -p check
	${rscript} -e "devtools::check(check_dir = 'check')"

.PHONY: site
## Create package website
site: README.md NAMESPACE ${favicons}
	${rscript} -e "pkgdown::build_site()"

.PHONY: dev-site
## Create package website [dev mode]
dev-site: README.md NAMESPACE
	${rscript} -e "pkgdown::build_site(devel = TRUE)"

## Create just the specified article for the website
article-%:
	${rscript} -e "pkgdown::build_article('$*')"

## Create just the references for the website
reference: documentation
	${rscript} -e "pkgdown::build_reference()"

# NOTE: In the following, the vignettes are built TWICE: once via the
# conventional route, to result in HTML output. And once to create MD output for
# hosting on GitHub, because the standard knitr RMarkdown vignette template
# refuses to save the intermediate MD files.

.PHONY: vignettes
## Compile all vignettes and other R Markdown articles
vignettes: knit_all
	${rscript} -e "devtools::build_vignettes(dependencies = TRUE)"

.PHONY: knit_all
## Compile R markdown articles and move files to the documentation directory
knit_all: ${knit_results} | doc
	cp -r vignettes/* doc

doc/%.md: vignettes/%.rmd | doc
	${rscript} -e "rmarkdown::render('$<', output_format = 'md_document', output_file = '${@F}', output_dir = '${@D}')"

.PHONY: documentation
## Compile the in-line package documentation
documentation: NAMESPACE

NAMESPACE: ${r_source_files}
	echo >NAMESPACE '# Generated by roxygen2: do not edit by hand' # Workaround for bug #1070 in roxygen2 7.1.0
	${rscript} -e "devtools::document()"

README.md: README.rmd DESCRIPTION
	Rscript -e "rmarkdown::render('$<', output_file = '${@F}', output_dir = '${@D}')"

.PHONY: favicons
## Generate the documentation site favicons
favicons: ${favicons}

export-favicon = \
	@sz=$$(sed 's/.*x\([[:digit:]]*\)\.png/\1/' <<<"$@"); \
	(set -x; ${inkscape} -w $$sz -h $$sz --export-area $1 --export-filename=$@ $<)

${favicons_small}: man/figures/xyz.svg | pkgdown/favicon
	$(call export-favicon,-11:1000:181:1192)

${favicons_large}: man/figures/xyz.svg | pkgdown/favicon
	$(call export-favicon,-51:0:711:760)

doc pkgdown/favicon:
	mkdir -p $@

## Clean up all build files
cleanall:
	${RM} -r doc docs Meta
	${RM} man/*.Rd
	${RM} NAMESPACE
	${RM} src/*.o src/*.so

.DEFAULT_GOAL := show-help
# See <https://github.com/klmr/maketools/tree/master/doc>.
.PHONY: show-help
show-help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)";echo;sed -ne"/^## /{h;s/.*//;:d" -e"H;n;s/^## //;td" -e"s/:.*//;G;s/\\n## /---/;s/\\n/ /g;p;}" ${MAKEFILE_LIST}|LC_ALL='C' sort -f|awk -F --- -v n=$$(tput cols) -v i=19 -v a="$$(tput setaf 6)" -v z="$$(tput sgr0)" '{printf"%s%*s%s ",a,-i,$$1,z;m=split($$2,w," ");l=n-i;for(j=1;j<=m;j++){l-=length(w[j])+1;if(l<= 0){l=n-i-length(w[j])-1;printf"\n%*s ",-i," ";}printf"%s ",w[j];}printf"\n";}'|more $$(test $$(uname) = Darwin && echo \-Xr)
