
NODES=nodes.json
GENERATOR=./generate_docs.py

docs: index.html audio.html control.html

index.html: audio.html
	cp audio.html index.html

audio.html: $(NODES) $(GENERATOR)
	$(GENERATOR) audio < $(NODES) > audio.html

control.html: $(NODES) $(GENERATOR)
	$(GENERATOR) control < $(NODES) > control.html

DEPLOY_FILES=index.html audio.html control.html auraglyph-doc.css auraglyph-dark.css
DEPLOY_SERVER=auraglyph.io
DEPLOY_PATH=auragly.ph/docs/

.PHONY=deploy
deploy: $(DEPLOY_FILES)
	scp $(DEPLOY_FILES) $(DEPLOY_SERVER):$(DEPLOY_PATH)
