
NODES=nodes.json
INFO=control.txt audio.txt
GENERATOR=./generate_docs.py

docs: index.html audio.html control.html

index.html: audio.html
	cp audio.html index.html

audio.html: $(NODES) $(GENERATOR) audio.txt
	$(GENERATOR) audio < $(NODES) > audio.html

control.html: $(NODES) $(GENERATOR) control.txt
	$(GENERATOR) control < $(NODES) > control.html

DEPLOY_FILES=index.html audio.html control.html \
    auraglyph-doc.css auraglyph-dark.css auraglyph-fonts.css
DEPLOY_SERVER0=auraglyph.io
DEPLOY_SERVER1=auraglyph.io
DEPLOY_PATH0=auragly.ph/docs/
DEPLOY_PATH1=auraglyph.io/docs/

.PHONY=deploy
deploy: $(DEPLOY_FILES)
	ssh $(DEPLOY_SERVER0) 'mkdir -p "$(DEPLOY_PATH0)"'
	scp $(DEPLOY_FILES) $(DEPLOY_SERVER0):$(DEPLOY_PATH0)
	ssh $(DEPLOY_SERVER1) 'mkdir -p "$(DEPLOY_PATH1)"'
	scp $(DEPLOY_FILES) $(DEPLOY_SERVER1):$(DEPLOY_PATH1)

install: docs
