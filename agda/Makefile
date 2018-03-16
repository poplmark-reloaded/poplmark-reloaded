ENTRYPOINT=index.agda
AGDA=agda
LIB=generic-syntax

all:
	${AGDA} -i ${LIB} ${ENTRYPOINT}

html:
	${AGDA} -i ${LIB} --html --html-dir=agda/ ${ENTRYPOINT}

clean:
	find -name "*.html" | xargs rm -f
	find -name "*.agdai" | xargs rm -f
